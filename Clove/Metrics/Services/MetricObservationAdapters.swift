import Foundation

private enum ObservationAdapterSupport {
    static func recordID(_ id: Int64?, fallback: String) -> (String, Set<MetricQualityFlag>) {
        if let id { return (String(id), []) }
        return ("unsaved:\(fallback)", [.unstableSourceIdentity])
    }

    static func fallback(date: Date, discriminator: String) -> String {
        "\(date.timeIntervalSinceReferenceDate):\(discriminator)"
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    static func missing(
        metricID: MetricID,
        timestamp: Date,
        day: Date,
        source: MetricSourceReference,
        flags: Set<MetricQualityFlag> = []
    ) -> MetricObservation {
        MetricObservation(
            metricID: metricID,
            timestamp: timestamp,
            day: day,
            state: .missing,
            source: source,
            qualityFlags: flags
        )
    }
}

// MARK: - Daily logs and symptoms

struct DailyLogObservationAdapter {
    let normalizer: MetricDayNormalizer

    func adapt(logs: [DailyLog], definitions: [MetricDefinition]) -> MetricObservationBatch {
        let coreDefinitions = definitions.filter {
            guard case .dailyLog(let field) = $0.source else { return false }
            return field != "medicationAdherenceJSON" && field != "medicationsTaken"
        }
        let symptomDefinitions = definitions.filter { $0.source == .symptomRatings }

        var observations: [MetricObservation] = []
        for log in logs {
            let day = normalizer.day(containing: log.date)
            let identity = ObservationAdapterSupport.recordID(
                log.id,
                fallback: ObservationAdapterSupport.fallback(date: log.date, discriminator: "daily-log")
            )

            observations.append(contentsOf: coreDefinitions.map {
                coreObservation(for: $0, log: log, day: day, recordID: identity.0, identityFlags: identity.1)
            })
            observations.append(contentsOf: symptomDefinitions.map {
                symptomObservation(for: $0, log: log, day: day, recordID: identity.0, identityFlags: identity.1)
            })
        }

        return MetricObservationBatch(observations: observations, rawEvents: [])
    }

    private func coreObservation(
        for definition: MetricDefinition,
        log: DailyLog,
        day: Date,
        recordID: String,
        identityFlags: Set<MetricQualityFlag>
    ) -> MetricObservation {
        guard case .dailyLog(let field) = definition.source else {
            preconditionFailure("DailyLog adapter received an incompatible definition")
        }
        let source = MetricSourceReference(kind: .dailyLog, recordID: recordID, field: field)
        let state: MetricObservationState
        var flags = identityFlags

        switch field {
        case "mood": state = log.mood.map { .observed(.number(Double($0))) } ?? .missing
        case "painLevel": state = log.painLevel.map { .observed(.number(Double($0))) } ?? .missing
        case "energyLevel": state = log.energyLevel.map { .observed(.number(Double($0))) } ?? .missing
        case "waterIntake": state = log.waterIntake.map { .observed(.number(Double($0))) } ?? .missing
        case "isFlareDay": state = .observed(.boolean(log.isFlareDay))
        case "weather":
            if let weather = log.weather?.trimmingCharacters(in: .whitespacesAndNewlines), !weather.isEmpty {
                let categories: [String]
                if case .categories(let values) = definition.domain { categories = values } else { categories = [] }
                if let canonical = categories.first(where: { ObservationAdapterSupport.matches($0, weather) }) {
                    state = .observed(.category(canonical))
                    if canonical != weather { flags.insert(.normalizedCategory) }
                } else {
                    state = .observed(.category(weather))
                    flags.insert(.unknownCategory)
                }
            } else {
                state = .missing
            }
        default:
            state = .missing
            flags.insert(.invalidSourceValue)
        }

        return MetricObservation(
            metricID: definition.id,
            timestamp: log.date,
            day: day,
            state: state,
            source: source,
            qualityFlags: flags
        )
    }

    private func symptomObservation(
        for definition: MetricDefinition,
        log: DailyLog,
        day: Date,
        recordID: String,
        identityFlags: Set<MetricQualityFlag>
    ) -> MetricObservation {
        let sourceID = Int64(definition.id.rawValue.split(separator: ":").last ?? "")
        let rating = log.symptomRatings.first {
            if let sourceID { return $0.symptomId == sourceID }
            return ObservationAdapterSupport.matches($0.symptomName, definition.displayName)
        }
        let source = MetricSourceReference(
            kind: .symptomRating,
            recordID: recordID,
            field: rating.map { String($0.symptomId) } ?? definition.id.rawValue
        )

        guard let rating else {
            return ObservationAdapterSupport.missing(
                metricID: definition.id,
                timestamp: log.date,
                day: day,
                source: source,
                flags: identityFlags
            )
        }

        let value: MetricObservedValue
        var flags = identityFlags
        if definition.measurementLevel == .binary {
            value = .boolean(rating.rating >= 5)
            flags.insert(.normalizedBinary)
        } else {
            value = .number(Double(rating.rating))
        }
        return MetricObservation(
            metricID: definition.id,
            timestamp: log.date,
            day: day,
            state: .observed(value),
            source: source,
            qualityFlags: flags
        )
    }
}

// MARK: - Medication data stored on daily logs

struct MedicationObservationAdapter {
    let normalizer: MetricDayNormalizer

    func adapt(
        logs: [DailyLog],
        definitions: [MetricDefinition],
        occurrenceNames: [MetricID: Set<String>] = [:]
    ) -> MetricObservationBatch {
        let adherence = definitions.first { $0.id == MetricCatalog.medicationAdherence.id }
        let occurrences = definitions.filter {
            guard case .dailyLog(let field) = $0.source else { return false }
            return field == "medicationsTaken"
        }
        var observations: [MetricObservation] = []
        var events: [MetricRawEvent] = []

        for log in logs {
            let day = normalizer.day(containing: log.date)
            let identity = ObservationAdapterSupport.recordID(
                log.id,
                fallback: ObservationAdapterSupport.fallback(date: log.date, discriminator: "medications")
            )

            if let adherence {
                let source = MetricSourceReference(
                    kind: .medicationAdherence,
                    recordID: identity.0,
                    field: "scheduled"
                )
                let eligible = log.medicationAdherence.filter { !$0.isAsNeeded }
                let state: MetricObservationState
                var flags = identity.1
                if !eligible.isEmpty {
                    state = .observed(.ratio(
                        numerator: eligible.filter(\.wasTaken).count,
                        denominator: eligible.count
                    ))
                } else if !log.medicationAdherence.isEmpty {
                    state = .notApplicable
                } else {
                    state = .missing
                    flags.insert(.ambiguousAbsence)
                }
                observations.append(MetricObservation(
                    metricID: adherence.id,
                    timestamp: log.date,
                    day: day,
                    state: state,
                    source: source,
                    qualityFlags: flags
                ))
            }

            for definition in occurrences {
                let acceptedNames = occurrenceNames[definition.id, default: [definition.displayName]]
                guard log.medicationsTaken.contains(where: { recorded in
                    acceptedNames.contains { ObservationAdapterSupport.matches(recorded, $0) }
                }) else { continue }
                let source = MetricSourceReference(
                    kind: .medicationOccurrence,
                    recordID: identity.0,
                    field: definition.displayName.lowercased()
                )
                observations.append(MetricObservation(
                    metricID: definition.id,
                    timestamp: log.date,
                    day: day,
                    state: .observed(.boolean(true)),
                    source: source,
                    qualityFlags: identity.1
                ))
                events.append(MetricRawEvent(
                    metricID: definition.id,
                    timestamp: log.date,
                    day: day,
                    source: source,
                    attributes: ["medication": .text(definition.displayName)]
                ))
            }
        }
        return MetricObservationBatch(observations: observations, rawEvents: events)
    }
}

// MARK: - Repository-backed events

struct FoodEntryObservationAdapter {
    let normalizer: MetricDayNormalizer

    func adapt(entries: [FoodEntry], definitions: [MetricDefinition]) -> MetricObservationBatch {
        let count = definitions.first { $0.id == MetricCatalog.mealCount.id }
        let occurrences = definitions.filter { $0.source == .foodEntries && $0.measurementLevel == .event }
        var result = MetricObservationBatch.empty

        for entry in entries {
            let day = normalizer.day(containing: entry.date)
            let identity = ObservationAdapterSupport.recordID(
                entry.id,
                fallback: ObservationAdapterSupport.fallback(date: entry.date, discriminator: entry.name)
            )
            let source = MetricSourceReference(kind: .foodEntry, recordID: identity.0)
            if let count {
                result.observations.append(MetricObservation(
                    metricID: count.id,
                    timestamp: entry.date,
                    day: day,
                    state: .observed(.number(1)),
                    source: source,
                    qualityFlags: identity.1
                ))
                result.rawEvents.append(MetricRawEvent(
                    metricID: count.id,
                    timestamp: entry.date,
                    day: day,
                    source: source,
                    attributes: [
                        "name": .text(entry.name),
                        "category": .text(entry.category.rawValue),
                        "favorite": .boolean(entry.isFavorite)
                    ]
                ))
            }
            for definition in occurrences where matches(entry: entry, definition: definition) {
                result.observations.append(MetricObservation(
                    metricID: definition.id,
                    timestamp: entry.date,
                    day: day,
                    state: .observed(.boolean(true)),
                    source: source,
                    qualityFlags: identity.1
                ))
            }
        }
        return result
    }

    private func matches(entry: FoodEntry, definition: MetricDefinition) -> Bool {
        if let identityID = entry.analyticsIdentityID,
           definition.id == DynamicMetricIdentityStore.canonicalID(family: .meal, sourceID: identityID) {
            return true
        }
        return ObservationAdapterSupport.matches(entry.name, definition.displayName)
    }
}

struct ActivityEntryObservationAdapter {
    let normalizer: MetricDayNormalizer

    func adapt(entries: [ActivityEntry], definitions: [MetricDefinition]) -> MetricObservationBatch {
        let count = definitions.first { $0.id == MetricCatalog.activityCount.id }
        let occurrences = definitions.filter { $0.source == .activityEntries && $0.measurementLevel == .event }
        var result = MetricObservationBatch.empty

        for entry in entries {
            let day = normalizer.day(containing: entry.date)
            let identity = ObservationAdapterSupport.recordID(
                entry.id,
                fallback: ObservationAdapterSupport.fallback(date: entry.date, discriminator: entry.name)
            )
            let source = MetricSourceReference(kind: .activityEntry, recordID: identity.0)
            if let count {
                result.observations.append(MetricObservation(
                    metricID: count.id,
                    timestamp: entry.date,
                    day: day,
                    state: .observed(.number(1)),
                    source: source,
                    qualityFlags: identity.1
                ))
                var attributes: [String: MetricEventAttribute] = [
                    "name": .text(entry.name),
                    "category": .text(entry.category.rawValue),
                    "favorite": .boolean(entry.isFavorite)
                ]
                if let duration = entry.duration { attributes["durationMinutes"] = .number(Double(duration)) }
                if let intensity = entry.intensity { attributes["intensity"] = .number(Double(intensity.intValue)) }
                result.rawEvents.append(MetricRawEvent(
                    metricID: count.id,
                    timestamp: entry.date,
                    day: day,
                    source: source,
                    attributes: attributes
                ))
            }
            for definition in occurrences where matches(entry: entry, definition: definition) {
                result.observations.append(MetricObservation(
                    metricID: definition.id,
                    timestamp: entry.date,
                    day: day,
                    state: .observed(.boolean(true)),
                    source: source,
                    qualityFlags: identity.1
                ))
            }
        }
        return result
    }

    private func matches(entry: ActivityEntry, definition: MetricDefinition) -> Bool {
        if let identityID = entry.analyticsIdentityID,
           definition.id == DynamicMetricIdentityStore.canonicalID(family: .activity, sourceID: identityID) {
            return true
        }
        return ObservationAdapterSupport.matches(entry.name, definition.displayName)
    }
}

struct BowelMovementObservationAdapter {
    let normalizer: MetricDayNormalizer

    func adapt(entries: [BowelMovement], definitions: [MetricDefinition]) -> MetricObservationBatch {
        let bristol = definitions.first(where: { $0.id == MetricCatalog.bristolStoolType.id })
        let frequency = definitions.first(where: { $0.id == MetricCatalog.bowelMovementFrequency.id })
        guard bristol != nil || frequency != nil else {
            return .empty
        }
        var result = MetricObservationBatch.empty

        for entry in entries {
            let day = normalizer.day(containing: entry.date)
            let identity = ObservationAdapterSupport.recordID(
                entry.id,
                fallback: ObservationAdapterSupport.fallback(date: entry.date, discriminator: String(entry.type))
            )
            let source = MetricSourceReference(kind: .bowelMovement, recordID: identity.0)
            var typeFlags = identity.1
            if !entry.isValidType { typeFlags.insert(.invalidSourceValue) }
            if let bristol {
                result.observations.append(MetricObservation(
                    metricID: bristol.id,
                    timestamp: entry.date,
                    day: day,
                    state: entry.isValidType ? .observed(.number(entry.type)) : .missing,
                    source: source,
                    qualityFlags: typeFlags
                ))
            }
            if let frequency {
                result.observations.append(MetricObservation(
                    metricID: frequency.id,
                    timestamp: entry.date,
                    day: day,
                    state: .observed(.number(1)),
                    source: source,
                    qualityFlags: identity.1
                ))
                result.rawEvents.append(MetricRawEvent(
                    metricID: frequency.id,
                    timestamp: entry.date,
                    day: day,
                    source: source,
                    attributes: ["bristolType": .number(entry.type)]
                ))
            }
        }
        return result
    }
}

struct CycleObservationAdapter {
    let normalizer: MetricDayNormalizer

    func adapt(entries: [Cycle], definitions: [MetricDefinition]) -> MetricObservationBatch {
        guard let flow = definitions.first(where: { $0.id == MetricCatalog.flowLevel.id }) else { return .empty }
        var result = MetricObservationBatch.empty

        for entry in entries {
            let day = normalizer.day(containing: entry.date)
            let identity = ObservationAdapterSupport.recordID(
                entry.id,
                fallback: ObservationAdapterSupport.fallback(date: entry.date, discriminator: entry.flow.rawValue)
            )
            let source = MetricSourceReference(kind: .cycleEntry, recordID: identity.0)
            result.observations.append(MetricObservation(
                metricID: flow.id,
                timestamp: entry.date,
                day: day,
                state: .observed(.number(entry.flow.numericValue)),
                source: source,
                qualityFlags: identity.1
            ))
            result.rawEvents.append(MetricRawEvent(
                metricID: flow.id,
                timestamp: entry.date,
                day: day,
                source: source,
                attributes: [
                    "flow": .text(entry.flow.rawValue),
                    "isStartOfCycle": .boolean(entry.isStartOfCycle),
                    "hasCramps": .boolean(entry.hasCramps)
                ]
            ))
        }
        return result
    }
}

// MARK: - Canonical composition

/// Composes repository results into a single canonical daily data set. AN-004 will own fetching
/// those results for explicit date intervals; this type intentionally has no database dependency.
struct MetricObservationPipeline {
    let normalizer: MetricDayNormalizer

    func makeDailyBatch(
        definitions: [MetricDefinition],
        logs: [DailyLog],
        foodEntries: [FoodEntry],
        activityEntries: [ActivityEntry],
        bowelMovements: [BowelMovement],
        cycleEntries: [Cycle],
        occurrenceNames: [MetricID: Set<String>] = [:]
    ) -> MetricObservationBatch {
        var batch = MetricObservationBatch.empty
        batch.append(DailyLogObservationAdapter(normalizer: normalizer).adapt(
            logs: logs,
            definitions: definitions
        ))
        batch.append(MedicationObservationAdapter(normalizer: normalizer).adapt(
            logs: logs,
            definitions: definitions,
            occurrenceNames: occurrenceNames
        ))
        batch.append(FoodEntryObservationAdapter(normalizer: normalizer).adapt(
            entries: foodEntries,
            definitions: definitions
        ))
        batch.append(ActivityEntryObservationAdapter(normalizer: normalizer).adapt(
            entries: activityEntries,
            definitions: definitions
        ))
        batch.append(BowelMovementObservationAdapter(normalizer: normalizer).adapt(
            entries: bowelMovements,
            definitions: definitions
        ))
        batch.append(CycleObservationAdapter(normalizer: normalizer).adapt(
            entries: cycleEntries,
            definitions: definitions
        ))
        return MetricDailyReducer(normalizer: normalizer).reduce(batch, definitions: definitions)
    }
}
