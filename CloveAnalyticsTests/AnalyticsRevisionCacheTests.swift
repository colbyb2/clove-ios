import XCTest
@testable import Clove

final class AnalyticsRevisionCacheTests: XCTestCase {
    func testCacheKeysExactRangeGranularityPolicyAndRevision() async throws {
        let repository = CountingAnalyticsRepository()
        let revision = TestRevisionSource()
        let cache = CachedAnalyticsRepository(repository: repository, revisionSource: revision, policyVersion: 3)
        let start = AnalyticsTestDates.date(1)
        let request = AnalyticsRequest(interval: DateInterval(start: start, duration: 86_400))

        _ = try await cache.load(request)
        _ = try await cache.load(request)
        XCTAssertEqual(repository.loadCount, 1)

        _ = try await cache.load(request, granularity: .weekly)
        XCTAssertEqual(repository.loadCount, 2)

        revision.bump(reason: .dailyLog)
        _ = try await cache.load(request)
        XCTAssertEqual(repository.loadCount, 3)

        let shifted = AnalyticsRequest(interval: DateInterval(start: start.addingTimeInterval(1), duration: 86_400))
        _ = try await cache.load(shifted)
        XCTAssertEqual(repository.loadCount, 4)
    }

    func testConcurrentIdenticalRequestsLoadOnce() async throws {
        let repository = CountingAnalyticsRepository()
        let cache = CachedAnalyticsRepository(repository: repository, revisionSource: TestRevisionSource())
        let request = AnalyticsRequest(interval: DateInterval(start: AnalyticsTestDates.date(1), duration: 86_400))

        try await withThrowingTaskGroup(of: AnalyticsDataset.self) { group in
            for _ in 0..<12 {
                group.addTask { try await cache.load(request) }
            }
            for try await _ in group {}
        }
        XCTAssertEqual(repository.loadCount, 1)
    }

    func testCancelledRequestDoesNotLoad() async {
        let repository = CountingAnalyticsRepository()
        let cache = CachedAnalyticsRepository(repository: repository, revisionSource: TestRevisionSource())
        let request = AnalyticsRequest(interval: DateInterval(start: AnalyticsTestDates.date(1), duration: 86_400))
        let task = Task {
            try Task.checkCancellation()
            return try await cache.load(request)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(repository.loadCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRepositoryWriteInvalidationMatrixAndPresentationSettingExclusion() throws {
        let database = try TestDatabaseManager()
        let revision = TestRevisionSource()

        let logs = LogsRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(logs.saveLog(DailyLog(date: AnalyticsTestDates.date(1), mood: 5)))
        XCTAssertEqual(revision.reasons.last, .dailyLog)
        XCTAssertTrue(logs.saveWaterIntake(16, for: AnalyticsTestDates.date(1)))
        XCTAssertEqual(revision.reasons.last, .dailyLog)

        let foods = FoodEntryRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertNotNil(foods.save(FoodEntry(name: "Soup", category: .lunch)))
        var food = try XCTUnwrap(foods.getAllEntries().first)
        food.name = "Stew"
        XCTAssertTrue(foods.update(food))
        XCTAssertTrue(foods.delete(id: try XCTUnwrap(food.id)))
        XCTAssertEqual(Array(revision.reasons.suffix(3)), [.food, .food, .food])

        let activities = ActivityEntryRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertNotNil(activities.save(ActivityEntry(name: "Walk", category: .exercise)))
        var activity = try XCTUnwrap(activities.getAllEntries().first)
        activity.duration = 20
        XCTAssertTrue(activities.update(activity))
        XCTAssertTrue(activities.delete(id: try XCTUnwrap(activity.id)))
        XCTAssertEqual(Array(revision.reasons.suffix(3)), [.activity, .activity, .activity])

        let bowel = BowelMovementRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(bowel.save([BowelMovement(type: 4, date: AnalyticsTestDates.date(1))]))
        var movement = try XCTUnwrap(bowel.getAllBowelMovements().first)
        movement.type = 5
        XCTAssertTrue(bowel.update(movement))
        XCTAssertTrue(bowel.delete(id: try XCTUnwrap(movement.id)))

        let cycles = CycleRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(cycles.save([Cycle(date: AnalyticsTestDates.date(1), flow: .light)]))
        let cycle = try XCTUnwrap(cycles.getAllCycles().first)
        XCTAssertTrue(cycles.delete(id: try XCTUnwrap(cycle.id)))

        let symptoms = SymptomsRepo(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(symptoms.saveSymptom(TrackedSymptom(name: "Fatigue")))
        let symptom = try XCTUnwrap(symptoms.getTrackedSymptoms().last)
        XCTAssertTrue(symptoms.updateSymptom(id: try XCTUnwrap(symptom.id), name: "Tiredness", isBinary: false))
        XCTAssertTrue(symptoms.deleteSymptom(id: try XCTUnwrap(symptom.id)))

        let medications = MedicationRepository(databaseManager: database, analyticsRevisionSource: revision)
        XCTAssertTrue(medications.saveMedication(TrackedMedication(name: "Vitamin D")))
        let medication = try XCTUnwrap(medications.getTrackedMedications().last)
        XCTAssertTrue(medications.updateMedication(
            id: try XCTUnwrap(medication.id),
            name: "Vitamin D3",
            dosage: "",
            instructions: "",
            isAsNeeded: false
        ))
        XCTAssertTrue(medications.deleteMedication(id: try XCTUnwrap(medication.id)))

        let settingsRepo = UserSettingsRepo(databaseManager: database, analyticsRevisionSource: revision)
        var settings = try XCTUnwrap(settingsRepo.getSettings())
        let beforePresentationChange = revision.currentRevision
        settings.autoSaveEnabled.toggle()
        XCTAssertTrue(settingsRepo.saveSettings(settings))
        XCTAssertEqual(revision.currentRevision, beforePresentationChange)
        settings.trackMood.toggle()
        XCTAssertTrue(settingsRepo.saveSettings(settings))
        XCTAssertEqual(revision.reasons.last, .analyticSettings)
    }
}
