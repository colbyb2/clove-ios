import Foundation
import GRDB
import XCTest
@testable import Clove

/// Frozen copies of JSON that already exists on users' devices (onboarding
/// drafts in UserDefaults, JSON columns inside `dailyLog`, backups).
///
/// Never edit these fixtures to make a test pass. A failure means a model
/// change would make existing user data undecodable; add a decoding fallback
/// (`decodeIfPresent ?? default`) instead. Add a new fixture whenever a
/// shipped format gains a field.
final class PersistedFormatCompatibilityTests: XCTestCase {
    /// `UserSettings` as encoded by v1.7.0 (onboarding draft / backups).
    private let userSettingsV170 = """
        {"id":1,"trackMood":true,"trackPain":false,"trackEnergy":true,"trackHydration":true,
         "autoSaveEnabled":true,"trackSymptoms":true,"trackMeals":false,"trackActivities":false,
         "trackMeds":true,"showFlareToggle":false,"trackWeather":false,"trackNotes":true,
         "trackBowelMovements":false,"trackCycle":true}
        """

    func testUserSettingsFromV170Decodes() throws {
        let settings = try JSONDecoder().decode(UserSettings.self, from: Data(userSettingsV170.utf8))

        XCTAssertEqual(settings.id, 1)
        XCTAssertFalse(settings.trackPain)
        XCTAssertTrue(settings.trackHydration)
        XCTAssertTrue(settings.trackMeds)
        XCTAssertTrue(settings.trackCycle)
    }

    func testUserSettingsRoundTripsThroughJSONAndDatabase() throws {
        var settings = UserSettings.default
        settings.trackPain.toggle()
        settings.trackCycle.toggle()

        let json = try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(json.trackPain, settings.trackPain)
        XCTAssertEqual(json.trackCycle, settings.trackCycle)

        let database = try TestDatabaseManager()
        let repo = UserSettingsRepo(databaseManager: database)
        XCTAssertTrue(repo.saveSettings(settings))
        let stored = try XCTUnwrap(try repo.loadSettings())
        XCTAssertEqual(stored.trackPain, settings.trackPain)
        XCTAssertEqual(stored.trackCycle, settings.trackCycle)
        XCTAssertEqual(try database.read { try UserSettings.fetchCount($0) }, 1, "Settings stay a singleton row")
    }

    func testSymptomRatingsWrittenBeforeBinarySymptomsDecode() {
        let log = DailyLog(date: Date())
        var legacy = log
        legacy.symptomRatingsJSON = #"[{"symptomId":3,"symptomName":"Fatigue","rating":8}]"#

        XCTAssertEqual(legacy.symptomRatings.map(\.rating), [8])
        XCTAssertEqual(legacy.symptomRatings.first?.isBinary, false)
    }

    func testMedicationAdherenceJSONFromV170Decodes() {
        var log = DailyLog(date: Date())
        log.medicationAdherenceJSON = """
            [{"medicationId":2,"medicationName":"Metformin","wasTaken":true,"isAsNeeded":false}]
            """

        XCTAssertEqual(log.medicationAdherence, [
            MedicationAdherence(medicationId: 2, medicationName: "Metformin", wasTaken: true)
        ])
    }

    func testCorruptJSONColumnsDegradeToEmptyInsteadOfCrashing() {
        var log = DailyLog(date: Date())
        log.symptomRatingsJSON = "{not json"
        log.medicationAdherenceJSON = ""

        XCTAssertTrue(log.symptomRatings.isEmpty)
        XCTAssertTrue(log.medicationAdherence.isEmpty)
    }

    func testDailyLogWithoutNewerFieldsDecodes() throws {
        // Shape of a DailyLog in early backups: no dayKey, hydration,
        // weather, or adherence.
        let json = """
            {"date":0,"mood":5,"meals":[],"activities":[],"medicationsTaken":[],
             "isFlareDay":false,"symptomRatingsJSON":"[]"}
            """
        let log = try JSONDecoder().decode(DailyLog.self, from: Data(json.utf8))

        XCTAssertEqual(log.mood, 5)
        XCTAssertEqual(log.dayKey, LocalDayKey.make(for: log.date))
        XCTAssertEqual(log.medicationAdherenceJSON, "[]")
        XCTAssertNil(log.waterIntake)
    }

    func testTrackedSymptomFromBeforeOrderingAndArchivingDecodes() throws {
        let symptom = try JSONDecoder().decode(TrackedSymptom.self, from: Data(#"{"id":9,"name":"Rash"}"#.utf8))

        XCTAssertEqual(symptom.name, "Rash")
        XCTAssertFalse(symptom.isBinary)
        XCTAssertTrue(symptom.isActive)
        XCTAssertEqual(symptom.displayOrder, 0)
    }

    func testCycleFromBeforeEndMarkersAndSignsDecodes() throws {
        let json = #"{"id":1,"date":0,"flow":"light","isStartOfCycle":true,"hasCramps":false}"#
        let cycle = try JSONDecoder().decode(Cycle.self, from: Data(json.utf8))

        XCTAssertEqual(cycle.flow, .light)
        XCTAssertTrue(cycle.isStartOfCycle)
        XCTAssertNil(cycle.fertilitySigns)
    }

    func testLocalDayKeyIsStableAcrossTimeZonesAndInvertible() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let instant = Date(timeIntervalSince1970: 1_741_910_400) // 2025-03-14 00:00 UTC

        XCTAssertEqual(LocalDayKey.make(for: instant, calendar: tokyo), "2025-03-14")
        XCTAssertEqual(LocalDayKey.make(for: instant, calendar: losAngeles), "2025-03-13")

        let roundTripped = try XCTUnwrap(LocalDayKey.date(from: "2024-02-29", calendar: tokyo))
        XCTAssertEqual(LocalDayKey.make(for: roundTripped, calendar: tokyo), "2024-02-29")
        XCTAssertNil(LocalDayKey.date(from: "2024-02"))
        XCTAssertNil(LocalDayKey.date(from: "garbage"))
    }

    func testSymptomRatingVMOnlyPersistsAnsweredFiniteValuesInRange() {
        XCTAssertNil(SymptomRatingVM(symptomId: 1, symptomName: "A").toModel(), "Unanswered is not zero")
        XCTAssertNil(SymptomRatingVM(symptomId: 1, symptomName: "A", ratingDouble: .nan).toModel())
        XCTAssertEqual(SymptomRatingVM(symptomId: 1, symptomName: "A", ratingDouble: 0).toModel()?.rating, 0)
        XCTAssertEqual(SymptomRatingVM(symptomId: 1, symptomName: "A", ratingDouble: 6.6).toModel()?.rating, 7)
        XCTAssertEqual(SymptomRatingVM(symptomId: 1, symptomName: "A", ratingDouble: 14).toModel()?.rating, 10)
        XCTAssertEqual(SymptomRatingVM(symptomId: 1, symptomName: "A", ratingDouble: -2).toModel()?.rating, 0)
        XCTAssertEqual(
            SymptomRatingVM(symptomId: 1, symptomName: "A", ratingDouble: 1, isBinary: true).toModel()?.isBinary,
            true
        )
    }
}
