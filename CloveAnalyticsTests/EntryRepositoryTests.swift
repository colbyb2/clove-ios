import Foundation
import GRDB
import XCTest
@testable import Clove

/// CRUD contracts for the per-entry repositories, run against a real
/// in-memory SQLite database with production migrations.
final class EntryRepositoryTests: XCTestCase {
    private var database: TestDatabaseManager!
    private var revisions: TestRevisionSource!
    private let calendar = Calendar.current

    override func setUpWithError() throws {
        database = try TestDatabaseManager()
        revisions = TestRevisionSource()
    }

    // MARK: - Medications

    func testMedicationEditsRecordOneHistoryEntryPerChangedField() throws {
        let repo = MedicationRepository(databaseManager: database, analyticsRevisionSource: revisions)
        XCTAssertTrue(repo.saveMedication(TrackedMedication(name: "Naproxen", dosage: "250mg")))
        let id = try XCTUnwrap(repo.getTrackedMedications().first?.id)

        XCTAssertTrue(repo.updateMedication(id: id, name: "Naproxen", dosage: "500mg", instructions: "", isAsNeeded: true))

        let medication = try XCTUnwrap(repo.getTrackedMedications().first)
        XCTAssertEqual(medication.dosage, "500mg")
        XCTAssertTrue(medication.isAsNeeded)
        let changes = Set(repo.getMedicationHistory(for: id).map(\.changeType))
        XCTAssertEqual(changes, ["dosage_changed", "schedule_changed"])
        XCTAssertEqual(revisions.reasons.map(\.rawValue), Array(repeating: AnalyticsRevisionReason.medication.rawValue, count: 2))
    }

    func testDeletingMedicationKeepsARemovalHistoryEntry() throws {
        let repo = MedicationRepository(databaseManager: database, analyticsRevisionSource: revisions)
        XCTAssertTrue(repo.saveMedication(TrackedMedication(name: "Vitamin D")))
        let id = try XCTUnwrap(repo.getTrackedMedications().first?.id)

        XCTAssertTrue(repo.deleteMedication(id: id))

        XCTAssertTrue(repo.getTrackedMedications().isEmpty)
        XCTAssertEqual(repo.getMedicationHistory(for: id).map(\.changeType), ["removed"])
        XCTAssertFalse(repo.deleteMedication(id: id), "Deleting a missing medication reports failure")
    }

    func testOverallAdherenceIgnoresAsNeededMedicationsAndUnrecordedDays() throws {
        let repo = MedicationRepository(databaseManager: database, analyticsRevisionSource: revisions)
        XCTAssertTrue(repo.saveMedication(TrackedMedication(name: "Daily")))
        XCTAssertTrue(repo.saveMedication(TrackedMedication(name: "Rescue", isAsNeeded: true)))
        let meds = repo.getTrackedMedications()
        let daily = try XCTUnwrap(meds.first { $0.name == "Daily" }?.id)
        let rescue = try XCTUnwrap(meds.first { $0.name == "Rescue" }?.id)

        let logs = LogsRepo(databaseManager: database, analyticsRevisionSource: revisions)
        for (offset, taken) in [(1, true), (2, true), (3, false), (4, true)] {
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            try logs.persistLog(DailyLog(date: date, medicationAdherence: [
                MedicationAdherence(medicationId: daily, medicationName: "Daily", wasTaken: taken),
                MedicationAdherence(medicationId: rescue, medicationName: "Rescue", wasTaken: false, isAsNeeded: true)
            ]))
        }
        // A day with no adherence record must not count as a missed dose.
        try logs.persistLog(DailyLog(date: calendar.date(byAdding: .day, value: -5, to: Date())!, mood: 5))

        XCTAssertEqual(repo.calculateAdherencePercentage(for: daily, days: 30), 75, accuracy: 1e-9)
        XCTAssertEqual(repo.calculateOverallAdherencePercentage(days: 30), 75, accuracy: 1e-9)
        XCTAssertEqual(repo.getAdherenceInsights(days: 30)["totalMedications"] as? Int, 1)
    }

    // MARK: - Food & activity entries

    func testFoodEntriesAreScopedToTheirLocalDayAndShareIdentityByName() throws {
        let repo = FoodEntryRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let today = calendar.startOfDay(for: Date())
        let lateTonight = today.addingTimeInterval(23 * 3600 + 59 * 60)
        let tomorrowMorning = today.addingTimeInterval(24 * 3600 + 60)

        XCTAssertNotNil(repo.save(FoodEntry(name: "Oatmeal", category: .breakfast, date: today.addingTimeInterval(8 * 3600))))
        XCTAssertNotNil(repo.save(FoodEntry(name: "oatmeal", category: .snack, date: lateTonight)))
        XCTAssertNotNil(repo.save(FoodEntry(name: "Toast", category: .breakfast, date: tomorrowMorning)))

        let todays = repo.getEntriesForDate(today)
        XCTAssertEqual(todays.map(\.name), ["Oatmeal", "oatmeal"], "Ordered by time, midnight-bounded")
        XCTAssertEqual(Set(todays.compactMap(\.analyticsIdentityID)).count, 1, "Case variants share one analytics identity")
        XCTAssertEqual(repo.getEntriesGroupedByCategory(for: today).keys.sorted { $0.rawValue < $1.rawValue }, [.breakfast, .snack])
    }

    func testFoodFavoritesSearchAndDelete() throws {
        let repo = FoodEntryRepo(databaseManager: database, analyticsRevisionSource: revisions)
        XCTAssertTrue(repo.save([
            FoodEntry(name: "Greek yogurt", category: .breakfast),
            FoodEntry(name: "Green tea", category: .beverage)
        ]))
        let yogurt = try XCTUnwrap(repo.getAllEntries().first { $0.name == "Greek yogurt" })
        let yogurtID = try XCTUnwrap(yogurt.id)

        XCTAssertTrue(repo.toggleFavorite(id: yogurtID))
        XCTAssertEqual(repo.getFavorites().map(\.name), ["Greek yogurt"])
        XCTAssertTrue(repo.toggleFavorite(id: yogurtID))
        XCTAssertTrue(repo.getFavorites().isEmpty)

        XCTAssertEqual(Set(repo.search(query: "gre").map(\.name)), ["Greek yogurt", "Green tea"])
        XCTAssertTrue(repo.search(query: "").isEmpty)

        XCTAssertTrue(repo.delete(id: yogurtID))
        XCTAssertEqual(repo.getAllEntries().map(\.name), ["Green tea"])
    }

    func testRenamingFoodEntryKeepsItsAnalyticsIdentity() throws {
        let repo = FoodEntryRepo(databaseManager: database, analyticsRevisionSource: revisions)
        XCTAssertNotNil(repo.save(FoodEntry(name: "Coffee", category: .beverage)))
        var entry = try XCTUnwrap(repo.getAllEntries().first)
        let identity = entry.analyticsIdentityID

        entry.name = "Decaf coffee"
        entry.analyticsIdentityID = nil
        XCTAssertTrue(repo.update(entry))

        let updated = try XCTUnwrap(repo.getAllEntries().first)
        XCTAssertEqual(updated.name, "Decaf coffee")
        XCTAssertEqual(updated.analyticsIdentityID, identity)
        XCTAssertFalse(repo.update(FoodEntry(name: "No id", category: .snack)), "Updating an unsaved entry fails")
    }

    func testRecentFoodNamesAreDistinctAndMostRecentFirst() throws {
        let repo = FoodEntryRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let now = Date()
        XCTAssertTrue(repo.save([
            FoodEntry(name: "Rice", category: .dinner, date: now.addingTimeInterval(-5 * 86_400)),
            FoodEntry(name: "Soup", category: .lunch, date: now.addingTimeInterval(-3 * 86_400)),
            FoodEntry(name: "Rice", category: .dinner, date: now.addingTimeInterval(-1 * 86_400))
        ]))

        XCTAssertEqual(repo.getRecentFoodNames(limit: 5), ["Rice", "Soup"])
        XCTAssertEqual(repo.getRecentFoodNames(limit: 1), ["Rice"])
    }

    func testActivityDurationTotalsOnlyTheRequestedDay() throws {
        let repo = ActivityEntryRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let today = calendar.startOfDay(for: Date())
        XCTAssertTrue(repo.save([
            ActivityEntry(name: "Walk", category: .exercise, date: today.addingTimeInterval(9 * 3600), duration: 30, intensity: .low),
            ActivityEntry(name: "Yoga", category: .wellness, date: today.addingTimeInterval(18 * 3600), duration: 45),
            ActivityEntry(name: "Nap", category: .rest, date: today.addingTimeInterval(-3600), duration: 60),
            ActivityEntry(name: "Chat", category: .social, date: today.addingTimeInterval(10 * 3600))
        ]))

        XCTAssertEqual(repo.getTotalDuration(for: today), 75)
        XCTAssertEqual(repo.getEntriesForDate(today).map(\.name), ["Walk", "Chat", "Yoga"])
        XCTAssertEqual(repo.getEntriesForDate(today).first?.intensity, .low)
    }

    // MARK: - Bowel movements & cycle

    func testBowelMovementsRoundTripUpdateAndDelete() throws {
        let repo = BowelMovementRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let today = calendar.startOfDay(for: Date())
        XCTAssertTrue(repo.save([
            BowelMovement(type: 4, date: today.addingTimeInterval(8 * 3600), notes: "normal"),
            BowelMovement(type: 6, date: today.addingTimeInterval(-3600))
        ]))

        var todays = repo.getBowelMovementsForDate(today)
        XCTAssertEqual(todays.map(\.type), [4])
        todays[0].type = 3
        XCTAssertTrue(repo.update(todays[0]))
        XCTAssertEqual(repo.getBowelMovementsForDate(today).first?.type, 3)

        XCTAssertTrue(repo.delete(id: try XCTUnwrap(todays[0].id)))
        XCTAssertTrue(repo.getBowelMovementsForDate(today).isEmpty)
        XCTAssertEqual(repo.getAllBowelMovements().count, 1)
    }

    func testCycleEntriesPreserveExplicitMarkersAndOptionalSigns() throws {
        let repo = CycleRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let today = calendar.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
        XCTAssertTrue(repo.save([
            Cycle(date: today, flow: .noFlow, isEndOfCycle: true, fertilitySigns: true)
        ]))

        let saved = try XCTUnwrap(repo.getCyclesForDate(today).first)
        XCTAssertEqual(saved.flow, .noFlow)
        XCTAssertEqual(saved.isEndOfCycle, true)
        XCTAssertEqual(saved.fertilitySigns, true)
        XCTAssertNil(saved.ovulation, "Unanswered optional sign stays nil, not false")
    }

    // MARK: - Daily log hydration

    func testSavingHydrationNeverOverwritesOtherDailyFields() throws {
        let repo = LogsRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let date = Date()
        try repo.persistLog(DailyLog(date: date, mood: 8, notes: "keep me"))

        try repo.persistWaterIntake(40, for: date)

        let log = try XCTUnwrap(try repo.loadLog(for: date))
        XCTAssertEqual(log.waterIntake, 40)
        XCTAssertEqual(log.mood, 8)
        XCTAssertEqual(log.notes, "keep me")
        XCTAssertEqual(try database.read { try DailyLog.fetchCount($0) }, 1)
    }

    func testClearingHydrationOnAnEmptyDayDoesNotCreateALog() throws {
        let repo = LogsRepo(databaseManager: database, analyticsRevisionSource: revisions)

        try repo.persistWaterIntake(nil, for: Date())

        XCTAssertEqual(try database.read { try DailyLog.fetchCount($0) }, 0)
    }

    func testLogRangeIsInclusiveOfBothEndDays() throws {
        let repo = LogsRepo(databaseManager: database, analyticsRevisionSource: revisions)
        let start = calendar.startOfDay(for: Date()).addingTimeInterval(-10 * 86_400)
        for offset in 0...4 {
            try repo.persistLog(DailyLog(date: calendar.date(byAdding: .day, value: offset, to: start)!, mood: offset))
        }

        let range = try repo.loadLogsInRange(
            from: calendar.date(byAdding: .day, value: 1, to: start)!,
            to: calendar.date(byAdding: .day, value: 3, to: start)!.addingTimeInterval(60)
        )
        XCTAssertEqual(range.map(\.mood), [1, 2, 3])
    }
}
