import XCTest
@testable import Clove

final class ActivityCategoryTaxonomyTests: XCTestCase {
    func testPresetCategoriesAreSeededAndExistingEntriesKeepTheirCategoryID() throws {
        let database = try TestDatabaseManager()
        let categories = ActivityCategoryRepo(databaseManager: database)
        let activities = ActivityEntryRepo(databaseManager: database)

        XCTAssertEqual(categories.getAll().filter(\.isPreset).count, ActivityCategoryDefinition.presets.count)

        let saved = try XCTUnwrap(activities.save(ActivityEntry(name: "Walk", category: .exercise)))
        XCTAssertEqual(saved.categoryID, "exercise")
        XCTAssertEqual(activities.getAllEntries().first?.categoryID, "exercise")
    }

    func testRenamingCustomCategoryPreservesStableIdentityAndPastEntries() throws {
        let database = try TestDatabaseManager()
        let categories = ActivityCategoryRepo(databaseManager: database)
        let activities = ActivityEntryRepo(databaseManager: database)
        var category = try XCTUnwrap(categories.create(
            name: "Pacing",
            symbol: "figure.walk",
            colorHex: "3578C8"
        ))

        XCTAssertNotNil(activities.save(ActivityEntry(
            name: "Rest break",
            category: .other,
            categoryID: category.id
        )))

        let originalID = category.id
        category.name = "Energy Pacing"
        XCTAssertTrue(categories.save(category))

        XCTAssertEqual(categories.definition(for: originalID).name, "Energy Pacing")
        XCTAssertEqual(activities.getAllEntries().first?.categoryID, originalID)
    }

    func testDeletingCustomCategoryMovesEntriesToOther() throws {
        let database = try TestDatabaseManager()
        let categories = ActivityCategoryRepo(databaseManager: database)
        let activities = ActivityEntryRepo(databaseManager: database)
        let category = try XCTUnwrap(categories.create(
            name: "Physio",
            symbol: "cross.case.fill",
            colorHex: "39875A"
        ))
        XCTAssertNotNil(activities.save(ActivityEntry(
            name: "Shoulder exercises",
            category: .other,
            categoryID: category.id
        )))

        XCTAssertTrue(categories.delete(category))
        let entry = try XCTUnwrap(activities.getAllEntries().first)
        XCTAssertEqual(entry.categoryID, "other")
        XCTAssertEqual(entry.category, .other)
    }
}
