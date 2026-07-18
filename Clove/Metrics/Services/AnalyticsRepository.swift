import Foundation
import GRDB

struct AnalyticsRequest: Sendable {
    let interval: DateInterval
    let metricIDs: Set<MetricID>?
    let includeRawEvents: Bool

    init(
        interval: DateInterval,
        metricIDs: Set<MetricID>? = nil,
        includeRawEvents: Bool = true
    ) {
        self.interval = interval
        self.metricIDs = metricIDs
        self.includeRawEvents = includeRawEvents
    }
}

enum AnalyticsRepositoryError: Error, Equatable {
    case invalidInterval
    case unknownMetricIDs(Set<MetricID>)
}

struct MetricCoverage: Equatable, Sendable {
    let metricID: MetricID
    let interval: DateInterval
    let possibleDayCount: Int
    let sourceDayCount: Int
    let observedCount: Int
    let missingCount: Int
    let explicitNoneCount: Int
    let notApplicableCount: Int
    let firstObservation: Date?
    let lastObservation: Date?

    var observedDayFraction: Double {
        guard possibleDayCount > 0 else { return 0 }
        return Double(sourceDayCount) / Double(possibleDayCount)
    }
}

struct AnalyticsQueryDiagnostics: Equatable, Sendable {
    let databaseReadCount: Int
    let statementCount: Int
}

struct AnalyticsDataset: Equatable, Sendable {
    let interval: DateInterval
    let definitions: [MetricDefinition]
    let observations: [MetricObservation]
    let rawEvents: [MetricRawEvent]
    let coverage: [MetricID: MetricCoverage]
    let metricAliases: [String: Set<MetricID>]
    let diagnostics: AnalyticsQueryDiagnostics
    private let observationIndex: [MetricID: [MetricObservation]]

    init(interval: DateInterval, definitions: [MetricDefinition], observations: [MetricObservation],
         rawEvents: [MetricRawEvent], coverage: [MetricID: MetricCoverage],
         metricAliases: [String: Set<MetricID>], diagnostics: AnalyticsQueryDiagnostics) {
        self.interval = interval
        self.definitions = definitions
        self.observations = observations
        self.rawEvents = rawEvents
        self.coverage = coverage
        self.metricAliases = metricAliases
        self.diagnostics = diagnostics
        observationIndex = Dictionary(grouping: observations, by: \.metricID)
    }

    func observations(for metricID: MetricID) -> [MetricObservation] {
        observationIndex[metricID] ?? []
    }
}

protocol AnalyticsRepository {
    func load(_ request: AnalyticsRequest) throws -> AnalyticsDataset
}

struct AnalyticsSourceSnapshot {
    let logs: [DailyLog]
    let foodEntries: [FoodEntry]
    let activityEntries: [ActivityEntry]
    let bowelMovements: [BowelMovement]
    let cycleEntries: [Cycle]
    let trackedSymptoms: [TrackedSymptom]
    let trackedMedications: [TrackedMedication]
    let dynamicIdentities: [DynamicMetricIdentity]
    let metricAliases: [MetricIdentityAlias]
    let diagnostics: AnalyticsQueryDiagnostics
}

protocol AnalyticsSourceLoading {
    func load(in interval: DateInterval) throws -> AnalyticsSourceSnapshot
}

/// Loads every range-bound source in one serialized GRDB read. The number of SQL statements is
/// fixed by source family, not multiplied by the number of requested metrics.
struct GRDBAnalyticsSourceLoader: AnalyticsSourceLoading {
    let databaseManager: DatabaseManaging

    init(databaseManager: DatabaseManaging = DatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    func load(in interval: DateInterval) throws -> AnalyticsSourceSnapshot {
        try databaseManager.read { db in
            let bounds: StatementArguments = [interval.start, interval.end]
            let logs = try DailyLog.fetchAll(
                db,
                sql: "SELECT * FROM dailyLog WHERE date >= ? AND date < ? ORDER BY date ASC, id ASC",
                arguments: bounds
            )
            let foods = try FoodEntry.fetchAll(
                db,
                sql: "SELECT * FROM foodEntry WHERE date >= ? AND date < ? ORDER BY date ASC, id ASC",
                arguments: bounds
            )
            let activities = try ActivityEntry.fetchAll(
                db,
                sql: "SELECT * FROM activityEntry WHERE date >= ? AND date < ? ORDER BY date ASC, id ASC",
                arguments: bounds
            )
            let bowel = try BowelMovement.fetchAll(
                db,
                sql: "SELECT * FROM bowelMovement WHERE date >= ? AND date < ? ORDER BY date ASC, id ASC",
                arguments: bounds
            )
            let cycles = try Cycle.fetchAll(
                db,
                sql: "SELECT * FROM cycle WHERE date >= ? AND date < ? ORDER BY date ASC, id ASC",
                arguments: bounds
            )
            let symptoms = try TrackedSymptom.order(Column("id").asc).fetchAll(db)
            let medications = try TrackedMedication.order(Column("id").asc).fetchAll(db)
            let identities = try DynamicMetricIdentity
                .order(Column("family").asc, Column("id").asc)
                .fetchAll(db)
            let aliases = try MetricIdentityAlias
                .order(Column("aliasID").asc, Column("canonicalID").asc)
                .fetchAll(db)

            return AnalyticsSourceSnapshot(
                logs: logs,
                foodEntries: foods,
                activityEntries: activities,
                bowelMovements: bowel,
                cycleEntries: cycles,
                trackedSymptoms: symptoms,
                trackedMedications: medications,
                dynamicIdentities: identities,
                metricAliases: aliases,
                diagnostics: AnalyticsQueryDiagnostics(databaseReadCount: 1, statementCount: 9)
            )
        }
    }
}

struct DefaultAnalyticsRepository: AnalyticsRepository {
    let sourceLoader: any AnalyticsSourceLoading
    let normalizer: MetricDayNormalizer

    init(
        sourceLoader: any AnalyticsSourceLoading = GRDBAnalyticsSourceLoader(),
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) {
        self.sourceLoader = sourceLoader
        self.normalizer = MetricDayNormalizer(calendar: calendar, timeZone: timeZone)
    }

    func load(_ request: AnalyticsRequest) throws -> AnalyticsDataset {
        try Task.checkCancellation()
        guard request.interval.duration > 0 else { throw AnalyticsRepositoryError.invalidInterval }
        let snapshot = try sourceLoader.load(in: request.interval)
        try Task.checkCancellation()
        let availableDefinitions = definitions(from: snapshot)
        let definitions: [MetricDefinition]

        if let requestedIDs = request.metricIDs {
            let availableIDs = Set(availableDefinitions.map(\.id))
            let unknown = requestedIDs.subtracting(availableIDs)
            guard unknown.isEmpty else { throw AnalyticsRepositoryError.unknownMetricIDs(unknown) }
            definitions = availableDefinitions.filter { requestedIDs.contains($0.id) }
        } else {
            definitions = availableDefinitions
        }

        let batch = MetricObservationPipeline(normalizer: normalizer).makeDailyBatch(
            definitions: definitions,
            logs: snapshot.logs,
            foodEntries: snapshot.foodEntries,
            activityEntries: snapshot.activityEntries,
            bowelMovements: snapshot.bowelMovements,
            cycleEntries: snapshot.cycleEntries,
            occurrenceNames: occurrenceNames(from: snapshot.metricAliases, definitions: definitions)
        )
        try Task.checkCancellation()
        let observations = batch.observations.sorted(by: Self.observationOrder)
        let rawEvents = request.includeRawEvents ? batch.rawEvents.sorted(by: Self.eventOrder) : []
        let dayCount = possibleDayCount(in: request.interval)
        let observationsByMetric = Dictionary(grouping: observations, by: \.metricID)
        let coverage = Dictionary(uniqueKeysWithValues: definitions.map { definition in
            let values = observationsByMetric[definition.id] ?? []
            return (definition.id, makeCoverage(
                for: definition.id,
                observations: values,
                interval: request.interval,
                possibleDayCount: dayCount
            ))
        })

        return AnalyticsDataset(
            interval: request.interval,
            definitions: definitions.sorted { $0.id.rawValue < $1.id.rawValue },
            observations: observations,
            rawEvents: rawEvents,
            coverage: coverage,
            metricAliases: aliasIndex(from: snapshot.metricAliases),
            diagnostics: snapshot.diagnostics
        )
    }

    private func definitions(from snapshot: AnalyticsSourceSnapshot) -> [MetricDefinition] {
        var result = MetricCatalog.staticDefinitions

        var symptomsByID: [Int64: (name: String, isBinary: Bool)] = [:]
        for symptom in snapshot.trackedSymptoms {
            guard let id = symptom.id else { continue }
            symptomsByID[id] = (symptom.name, symptom.isBinary)
        }
        for rating in snapshot.logs.flatMap(\.symptomRatings) {
            symptomsByID[rating.symptomId] = (rating.symptomName, rating.isBinary)
        }
        result.append(contentsOf: symptomsByID.keys.sorted().map { id in
            let value = symptomsByID[id]!
            return MetricCatalog.symptom(
                id: MetricID(rawValue: "symptom:\(id)"),
                name: value.name,
                isBinary: value.isBinary
            )
        })

        var medicationNamesByID = Dictionary(uniqueKeysWithValues: snapshot.trackedMedications.compactMap {
            medication -> (Int64, String)? in
            guard let id = medication.id else { return nil }
            return (id, medication.name)
        })
        for adherence in snapshot.logs.flatMap(\.medicationAdherence) {
            medicationNamesByID[adherence.medicationId] = adherence.medicationName
        }
        result.append(contentsOf: medicationNamesByID.keys.sorted().map { id in
            MetricCatalog.medicationOccurrence(
                id: MetricID(rawValue: "medication:\(id)"),
                name: medicationNamesByID[id]!
            )
        })

        result.append(contentsOf: eventDefinitions(
            entries: snapshot.activityEntries.map { ($0.analyticsIdentityID, $0.name, $0.date) },
            family: .activity,
            identities: snapshot.dynamicIdentities,
            factory: MetricCatalog.activityOccurrence
        ))
        result.append(contentsOf: eventDefinitions(
            entries: snapshot.foodEntries.map { ($0.analyticsIdentityID, $0.name, $0.date) },
            family: .meal,
            identities: snapshot.dynamicIdentities,
            factory: MetricCatalog.mealOccurrence
        ))

        return Dictionary(grouping: result, by: \.id)
            .compactMap { $0.value.first }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func eventDefinitions(
        entries: [(identityID: Int64?, name: String, date: Date)],
        family: DynamicMetricFamily,
        identities: [DynamicMetricIdentity],
        factory: (MetricID, String) -> MetricDefinition
    ) -> [MetricDefinition] {
        var latestByID: [MetricID: (String, Date)] = [:]
        for entry in entries {
            let id = entry.identityID.map {
                DynamicMetricIdentityStore.canonicalID(family: family, sourceID: $0)
            } ?? MetricID(rawValue: DynamicMetricIdentityStore.legacyID(family: family, name: entry.name))
            if latestByID[id] == nil || latestByID[id]!.1 < entry.date {
                latestByID[id] = (entry.name, entry.date)
            }
        }
        let persistedNames = Dictionary(uniqueKeysWithValues: identities.compactMap {
            identity -> (MetricID, String)? in
            guard identity.family == family, let sourceID = identity.id else { return nil }
            return (DynamicMetricIdentityStore.canonicalID(family: family, sourceID: sourceID), identity.displayName)
        })
        return Set(latestByID.keys).union(persistedNames.keys).sorted { $0.rawValue < $1.rawValue }.compactMap { id in
            guard let name = persistedNames[id] ?? latestByID[id]?.0 else { return nil }
            return factory(id, name)
        }
    }

    private func aliasIndex(from aliases: [MetricIdentityAlias]) -> [String: Set<MetricID>] {
        Dictionary(grouping: aliases, by: \.aliasID).mapValues { values in
            Set(values.map { MetricID(rawValue: $0.canonicalID) })
        }
    }

    private func occurrenceNames(
        from aliases: [MetricIdentityAlias],
        definitions: [MetricDefinition]
    ) -> [MetricID: Set<String>] {
        let definitionIDs = Set(definitions.map(\.id))
        return Dictionary(grouping: aliases, by: { MetricID(rawValue: $0.canonicalID) })
            .filter { definitionIDs.contains($0.key) }
            .mapValues { Set($0.map(\.sourceName)) }
    }

    private func possibleDayCount(in interval: DateInterval) -> Int {
        var count = 0
        var day = normalizer.day(containing: interval.start)
        while day < interval.end {
            count += 1
            guard let next = normalizer.calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return count
    }

    private func makeCoverage(
        for metricID: MetricID,
        observations: [MetricObservation],
        interval: DateInterval,
        possibleDayCount: Int
    ) -> MetricCoverage {
        let observedCount = observations.filter {
            if case .observed = $0.state { return true }
            return false
        }.count
        return MetricCoverage(
            metricID: metricID,
            interval: interval,
            possibleDayCount: possibleDayCount,
            sourceDayCount: Set(observations.map { normalizer.dayKey(for: $0.day) }).count,
            observedCount: observedCount,
            missingCount: observations.filter { $0.state == .missing }.count,
            explicitNoneCount: observations.filter { $0.state == .explicitNone }.count,
            notApplicableCount: observations.filter { $0.state == .notApplicable }.count,
            firstObservation: observations.map(\.timestamp).min(),
            lastObservation: observations.map(\.timestamp).max()
        )
    }

    private static func observationOrder(_ lhs: MetricObservation, _ rhs: MetricObservation) -> Bool {
        if lhs.metricID.rawValue != rhs.metricID.rawValue { return lhs.metricID.rawValue < rhs.metricID.rawValue }
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private static func eventOrder(_ lhs: MetricRawEvent, _ rhs: MetricRawEvent) -> Bool {
        if lhs.metricID.rawValue != rhs.metricID.rawValue { return lhs.metricID.rawValue < rhs.metricID.rawValue }
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.id.rawValue < rhs.id.rawValue
    }
}
