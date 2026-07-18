import Foundation

/// App-model fixtures for every Phase 1 source adapter. Kept separate from the pure checks because
/// persistence models import GRDB.
enum MetricObservationAdapterChecks {
    static func assertAllPass(file: StaticString = #fileID, line: UInt = #line) {
        let zone = TimeZone(secondsFromGMT: 0)!
        let normalizer = MetricDayNormalizer(timeZone: zone)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let symptom = MetricCatalog.symptom(id: "symptom:1", name: "Fatigue", isBinary: false)
        let medication = MetricCatalog.medicationOccurrence(id: "medication:1", name: "Vitamin D")
        let meal = MetricCatalog.mealOccurrence(id: "meal:1", name: "Oatmeal")
        let activity = MetricCatalog.activityOccurrence(id: "activity:1", name: "Walking")
        let definitions = MetricCatalog.staticDefinitions + [symptom, medication, meal, activity]

        let log = DailyLog(
            id: 11,
            date: date,
            mood: 7,
            painLevel: 2,
            energyLevel: 6,
            waterIntake: 48,
            medicationsTaken: ["Vitamin D"],
            medicationAdherence: [
                MedicationAdherence(medicationId: 1, medicationName: "Vitamin D", wasTaken: true)
            ],
            isFlareDay: false,
            weather: "Sunny",
            symptomRatings: [SymptomRating(symptomId: 1, symptomName: "Fatigue", rating: 4)]
        )
        let food = FoodEntry(id: 21, name: "Oatmeal", category: .breakfast, date: date)
        let movement = ActivityEntry(
            id: 31,
            name: "Walking",
            category: .exercise,
            date: date,
            duration: 30,
            intensity: .medium
        )
        var bowel = BowelMovement(type: 4, date: date)
        bowel.id = 41
        let cycle = Cycle(id: 51, date: date, flow: .medium, isStartOfCycle: true)

        let batch = MetricObservationPipeline(normalizer: normalizer).makeDailyBatch(
            definitions: definitions,
            logs: [log],
            foodEntries: [food],
            activityEntries: [movement],
            bowelMovements: [bowel],
            cycleEntries: [cycle]
        )
        let representedIDs = Set(batch.observations.map(\.metricID))
        let expectedIDs = Set(definitions.map(\.id))
        precondition(
            expectedIDs.isSubset(of: representedIDs),
            "Missing adapter coverage for \(expectedIDs.subtracting(representedIDs))",
            file: file,
            line: line
        )

        precondition(batch.rawEvents.count == 5, "Expected one event per event source", file: file, line: line)
        precondition(
            batch.observations.first(where: { $0.metricID == MetricCatalog.mealCount.id })?.state == .observed(.number(1)),
            "Meal count did not reduce correctly",
            file: file,
            line: line
        )
        precondition(
            batch.observations.first(where: { $0.metricID == MetricCatalog.bowelMovementFrequency.id })?.state == .observed(.number(1)),
            "Bowel frequency did not remain distinct",
            file: file,
            line: line
        )
        precondition(
            batch.observations.first(where: { $0.metricID == MetricCatalog.bristolStoolType.id })?.state ==
                .observed(.distribution([MetricDistributionBucket(value: "number:4.0", count: 1)])),
            "Bristol type did not remain a distribution",
            file: file,
            line: line
        )

        let incomplete = DailyLog(id: 61, date: date, mood: nil)
        let missingMood = DailyLogObservationAdapter(normalizer: normalizer).adapt(
            logs: [incomplete],
            definitions: [MetricCatalog.mood]
        ).observations.first
        precondition(missingMood?.state == .missing, "Nil mood became a zero", file: file, line: line)

        let absentMedication = MedicationObservationAdapter(normalizer: normalizer).adapt(
            logs: [incomplete],
            definitions: [medication]
        )
        precondition(
            absentMedication.observations.isEmpty,
            "An absent medication event became a false negative observation",
            file: file,
            line: line
        )

        let editedLog = DailyLog(id: 11, date: date.addingTimeInterval(60), mood: 9)
        let originalMood = DailyLogObservationAdapter(normalizer: normalizer).adapt(
            logs: [log],
            definitions: [MetricCatalog.mood]
        ).observations.first
        let editedMood = DailyLogObservationAdapter(normalizer: normalizer).adapt(
            logs: [editedLog],
            definitions: [MetricCatalog.mood]
        ).observations.first
        precondition(
            originalMood?.id == editedMood?.id,
            "Edited persistence records changed canonical identity",
            file: file,
            line: line
        )
    }
}
