import Foundation

/// Authoritative semantic definitions for Clove's current analytics metrics.
///
/// This catalog describes meaning only. Source adapters and database access are introduced by
/// `AN-003` and `AN-004`; presentation consumers migrate in Phase 2.
enum MetricCatalog {
    // MARK: Static Definitions

    static let mood = ratingDefinition(
        id: "mood",
        name: "Mood",
        description: "Daily self-reported mood score",
        sourceField: "mood",
        directionality: .higherIsBetter
    )

    static let painLevel = ratingDefinition(
        id: "pain_level",
        name: "Pain Level",
        description: "Daily self-reported pain intensity",
        sourceField: "painLevel",
        directionality: .lowerIsBetter
    )

    static let energyLevel = ratingDefinition(
        id: "energy_level",
        name: "Energy Level",
        description: "Daily self-reported energy score",
        sourceField: "energyLevel",
        directionality: .higherIsBetter
    )

    static let hydration = MetricDefinition(
        id: "hydration",
        displayName: "Hydration",
        description: "Daily water intake in fluid ounces",
        category: .coreHealth,
        source: .dailyLog(field: "waterIntake"),
        measurementLevel: .continuous,
        unit: .fluidOunces,
        domain: .nonNegative,
        directionality: .neutral,
        aggregation: MetricAggregationPolicy(daily: .latest, weekly: .average, monthly: .average),
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .trend, .distribution, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: standardSamples,
        recommendedVisualizations: [.bar, .line, .calendarHeatmap],
        displayFormat: MetricDisplayFormat(maximumFractionDigits: 0, suffix: " oz")
    )

    static let flareDay = MetricDefinition(
        id: "flare_day",
        displayName: "Flare Days",
        description: "Days explicitly recorded as flare or non-flare days",
        category: .coreHealth,
        source: .dailyLog(field: "isFlareDay"),
        measurementLevel: .binary,
        unit: .occurrence,
        domain: .numeric(0...1),
        directionality: .lowerIsBetter,
        aggregation: binaryAggregation,
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .frequency, .distribution, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: binarySamples,
        recommendedVisualizations: [.occurrenceStrip, .calendarHeatmap, .bar]
    )

    static let medicationAdherence = MetricDefinition(
        id: "medication_adherence",
        displayName: "Medication Adherence",
        description: "Eligible scheduled doses taken, excluding as-needed medication",
        category: .medications,
        source: .dailyLog(field: "medicationAdherenceJSON"),
        measurementLevel: .percentage,
        unit: .percentage,
        domain: .numeric(0...100),
        directionality: .higherIsBetter,
        aggregation: MetricAggregationPolicy(
            daily: .weightedPercentage,
            weekly: .weightedPercentage,
            monthly: .weightedPercentage
        ),
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .trend, .distribution, .frequency, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: standardSamples,
        recommendedVisualizations: [.bar, .line, .calendarHeatmap],
        displayFormat: MetricDisplayFormat(maximumFractionDigits: 0, suffix: "%")
    )

    static let weather = MetricDefinition(
        id: "weather",
        displayName: "Weather",
        description: "Daily weather category",
        category: .environmental,
        source: .dailyLog(field: "weather"),
        measurementLevel: .categorical,
        unit: .category,
        domain: .categories(["Stormy", "Rainy", "Gloomy", "Cloudy", "Snow", "Sunny"]),
        directionality: .neutral,
        aggregation: MetricAggregationPolicy(daily: .latest, weekly: .distribution, monthly: .distribution),
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .distribution, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: standardSamples,
        recommendedVisualizations: [.distribution, .stackedBar, .calendarHeatmap]
    )

    static let activityCount = countDefinition(
        id: "activity_count",
        name: "Activity Count",
        description: "Number of activity entries recorded per observed day",
        category: .activities
    )

    static let mealCount = countDefinition(
        id: "meal_count",
        name: "Meal Count",
        description: "Number of meal entries recorded per observed day",
        category: .meals
    )

    /// Current provider compatibility ID. This represents the recorded Bristol value, not frequency.
    /// `AN-006` owns migration to the stable `bristol_stool_type` ID.
    static let bristolStoolType = MetricDefinition(
        id: "bowelMovements",
        displayName: "Bristol Stool Type",
        description: "Bristol Stool Scale type recorded for each bowel movement",
        category: .coreHealth,
        source: .bowelMovements,
        measurementLevel: .ordinal,
        unit: .custom(symbol: "Bristol type"),
        domain: .numeric(1...7),
        directionality: .neutral,
        aggregation: MetricAggregationPolicy(daily: .distribution, weekly: .distribution, monthly: .distribution),
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .distribution, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: standardSamples,
        recommendedVisualizations: [.distribution, .stackedBar, .calendarHeatmap]
    )

    /// Derived from bowel-movement events and intentionally separate from Bristol type.
    static let bowelMovementFrequency = MetricDefinition(
        id: "bowel_movement_frequency",
        displayName: "Bowel Movement Frequency",
        description: "Number of bowel movements recorded per observed day",
        category: .coreHealth,
        source: .bowelMovements,
        measurementLevel: .count,
        unit: .count,
        domain: .nonNegative,
        directionality: .neutral,
        aggregation: MetricAggregationPolicy(daily: .sum, weekly: .average, monthly: .average),
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .trend, .distribution, .frequency, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: standardSamples,
        recommendedVisualizations: [.bar, .line, .calendarHeatmap]
    )

    static let flowLevel = MetricDefinition(
        id: "flow_level",
        displayName: "Flow Level",
        description: "Recorded period-flow intensity",
        category: .coreHealth,
        source: .cycleEntries,
        measurementLevel: .ordinal,
        unit: .custom(symbol: "flow level"),
        domain: .numeric(0...5),
        directionality: .neutral,
        aggregation: MetricAggregationPolicy(daily: .latest, weekly: .distribution, monthly: .distribution),
        unrecordedDayPolicy: .missing,
        supportedAnalyses: [.descriptive, .distribution, .periodComparison, .relationship, .laggedRelationship],
        minimumSamples: standardSamples,
        recommendedVisualizations: [.distribution, .stackedBar, .calendarHeatmap]
    )

    static let staticDefinitions: [MetricDefinition] = [
        mood,
        painLevel,
        energyLevel,
        hydration,
        flareDay,
        medicationAdherence,
        weather,
        activityCount,
        mealCount,
        bristolStoolType,
        bowelMovementFrequency,
        flowLevel
    ]

    static let registeredStaticDefinitions: [MetricDefinition] = staticDefinitions.filter {
        $0.id != bowelMovementFrequency.id
    }

    static let staticDefinitionsByID: [MetricID: MetricDefinition] = Dictionary(
        uniqueKeysWithValues: staticDefinitions.map { ($0.id, $0) }
    )

    // MARK: Dynamic Families

    static func symptom(id: MetricID, name: String, isBinary: Bool) -> MetricDefinition {
        MetricDefinition(
            id: id,
            displayName: name,
            description: isBinary ? "Whether \(name) was marked present" : "Recorded \(name) severity",
            category: .symptoms,
            source: .symptomRatings,
            measurementLevel: isBinary ? .binary : .ordinal,
            unit: isBinary ? .occurrence : .score,
            domain: .numeric(isBinary ? 0...1 : 0...10),
            directionality: .lowerIsBetter,
            aggregation: isBinary ? binaryAggregation : ratingAggregation,
            unrecordedDayPolicy: .missing,
            supportedAnalyses: isBinary
                ? [.descriptive, .frequency, .distribution, .periodComparison, .relationship, .laggedRelationship]
                : [.descriptive, .trend, .distribution, .periodComparison, .relationship, .laggedRelationship],
            minimumSamples: isBinary ? binarySamples : standardSamples,
            recommendedVisualizations: isBinary
                ? [.occurrenceStrip, .calendarHeatmap, .bar]
                : [.line, .distribution, .calendarHeatmap]
        )
    }

    static func medicationOccurrence(id: MetricID, name: String) -> MetricDefinition {
        eventOccurrenceDefinition(
            id: id,
            name: name,
            description: "Days when \(name) was recorded as taken; scheduled and as-needed intent is not inferred",
            category: .medications,
            source: .dailyLog(field: "medicationsTaken")
        )
    }

    static func activityOccurrence(id: MetricID, name: String) -> MetricDefinition {
        eventOccurrenceDefinition(
            id: id,
            name: name,
            description: "Days when \(name) was recorded as an activity",
            category: .activities,
            source: .activityEntries
        )
    }

    static func mealOccurrence(id: MetricID, name: String) -> MetricDefinition {
        eventOccurrenceDefinition(
            id: id,
            name: name,
            description: "Days when \(name) was recorded as a meal or food",
            category: .meals,
            source: .foodEntries
        )
    }

    // MARK: Shared Policies

    private static let standardSamples = MetricMinimumSamples(
        descriptive: 1,
        trend: 7,
        relationship: 14,
        pattern: 14
    )

    private static let binarySamples = MetricMinimumSamples(
        descriptive: 1,
        trend: 14,
        relationship: 14,
        pattern: 28
    )

    private static let ratingAggregation = MetricAggregationPolicy(
        daily: .latest,
        weekly: .average,
        monthly: .average
    )

    private static let binaryAggregation = MetricAggregationPolicy(
        daily: .latest,
        weekly: .occurrenceRate,
        monthly: .occurrenceRate
    )

    private static func ratingDefinition(
        id: MetricID,
        name: String,
        description: String,
        sourceField: String,
        directionality: MetricDirectionality
    ) -> MetricDefinition {
        MetricDefinition(
            id: id,
            displayName: name,
            description: description,
            category: .coreHealth,
            source: .dailyLog(field: sourceField),
            measurementLevel: .ordinal,
            unit: .score,
            domain: .numeric(0...10),
            directionality: directionality,
            aggregation: ratingAggregation,
            unrecordedDayPolicy: .missing,
            supportedAnalyses: [.descriptive, .trend, .distribution, .periodComparison, .relationship, .laggedRelationship],
            minimumSamples: standardSamples,
            recommendedVisualizations: [.line, .distribution, .calendarHeatmap]
        )
    }

    private static func countDefinition(
        id: MetricID,
        name: String,
        description: String,
        category: MetricSemanticCategory
    ) -> MetricDefinition {
        MetricDefinition(
            id: id,
            displayName: name,
            description: description,
            category: category,
            source: category == .activities ? .activityEntries : .foodEntries,
            measurementLevel: .count,
            unit: .count,
            domain: .nonNegative,
            directionality: .neutral,
            aggregation: MetricAggregationPolicy(daily: .sum, weekly: .average, monthly: .average),
            unrecordedDayPolicy: .missing,
            supportedAnalyses: [.descriptive, .trend, .distribution, .frequency, .periodComparison, .relationship, .laggedRelationship],
            minimumSamples: standardSamples,
            recommendedVisualizations: [.bar, .line, .calendarHeatmap]
        )
    }

    private static func eventOccurrenceDefinition(
        id: MetricID,
        name: String,
        description: String,
        category: MetricSemanticCategory,
        source: MetricSource
    ) -> MetricDefinition {
        MetricDefinition(
            id: id,
            displayName: name,
            description: description,
            category: category,
            source: source,
            measurementLevel: .event,
            unit: .occurrence,
            domain: .unrestricted,
            directionality: .neutral,
            aggregation: MetricAggregationPolicy(daily: .none, weekly: .count, monthly: .count),
            unrecordedDayPolicy: .missing,
            supportedAnalyses: [.descriptive, .frequency, .distribution, .periodComparison, .relationship, .laggedRelationship, .eventOutcome],
            minimumSamples: binarySamples,
            recommendedVisualizations: [.eventOverlay, .occurrenceStrip, .calendarHeatmap]
        )
    }
}
