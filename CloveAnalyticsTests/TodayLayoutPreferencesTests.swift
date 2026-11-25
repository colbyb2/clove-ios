import XCTest
@testable import Clove

final class TodayLayoutPreferencesTests: XCTestCase {
    func testLayoutRoundTripsOrderVisibilityCollapseAndEssentials() throws {
        let suiteName = "TodayLayoutPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var preferences = TodayLayoutPreferences.default
        preferences.order.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        preferences.hidden = [.meals]
        preferences.collapsed = [.symptoms]
        preferences.essentials = [.mood, .energy]
        preferences.save(defaults: defaults)

        XCTAssertEqual(TodayLayoutPreferences.load(defaults: defaults), preferences)
    }

    func testLoadingOlderLayoutAppendsMissingModules() throws {
        let suiteName = "TodayLayoutPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let partial = TodayLayoutPreferences(
            order: [.mood, .pain],
            hidden: [],
            collapsed: [],
            essentials: [.mood]
        )
        partial.save(defaults: defaults)

        let loaded = TodayLayoutPreferences.load(defaults: defaults)
        XCTAssertEqual(loaded.order.prefix(2), [.mood, .pain])
        XCTAssertEqual(Set(loaded.order), Set(TodayModule.allCases))
        XCTAssertEqual(loaded.order.count, TodayModule.allCases.count)
    }

    func testLoadingLegacyLayoutRemovesPlansWithoutResettingOrder() throws {
        let suiteName = "TodayLayoutPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacy = TodayLayoutPreferences(
            order: [.energy, .plans, .mood, .pain],
            hidden: [.plans],
            collapsed: [.plans],
            essentials: [.plans, .energy]
        )
        legacy.save(defaults: defaults)

        let loaded = TodayLayoutPreferences.load(defaults: defaults)
        XCTAssertEqual(loaded.order.prefix(3), [.energy, .mood, .pain])
        XCTAssertFalse(loaded.order.contains(.plans))
        XCTAssertFalse(loaded.hidden.contains(.plans))
        XCTAssertFalse(loaded.collapsed.contains(.plans))
        XCTAssertFalse(loaded.essentials.contains(.plans))
    }

    func testLegacyGroupExpandsAtItsSavedPositionAndInheritsPreferences() throws {
        let data = Data(#"{"order":["energy","customMetrics","mood"],"hidden":["customMetrics"],"collapsed":[],"essentials":["customMetrics","energy"]}"#.utf8)
        var preferences = try JSONDecoder().decode(TodayLayoutPreferences.self, from: data)
        preferences.normalize()
        let items = preferences.items(customMetricIDs: ["weight", "sodium"])
        XCTAssertEqual(Array(items.prefix(4)), [.module(.energy), .customMetric("weight"), .customMetric("sodium"), .module(.mood)])
        XCTAssertTrue(preferences.isHidden(.customMetric("weight")))
        XCTAssertTrue(preferences.isEssential(.customMetric("sodium")))
        preferences.setItems(items)
        XCTAssertTrue(preferences.isHidden(.customMetric("sodium")))
        XCTAssertTrue(preferences.isEssential(.customMetric("weight")))
        XCTAssertFalse(preferences.items(customMetricIDs: ["weight", "sodium"]).contains(.module(.customMetrics)))
    }

    func testIndividualMetricPlacementAndPreferencesSurviveSaving() throws {
        let suiteName = "TodayLayoutPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var preferences = TodayLayoutPreferences.default
        var items = preferences.items(customMetricIDs: ["weight", "sodium"])
        items.removeAll { $0 == .customMetric("weight") || $0 == .customMetric("sodium") }
        items.insert(.customMetric("weight"), at: 0)
        items.insert(.customMetric("sodium"), at: 2)
        preferences.setItems(items)
        preferences.setHidden(true, for: .customMetric("weight"))
        preferences.setEssential(true, for: .customMetric("sodium"))
        preferences.save(defaults: defaults)

        let loaded = TodayLayoutPreferences.load(defaults: defaults)
        XCTAssertEqual(loaded.items(customMetricIDs: ["weight", "sodium"]), items)
        XCTAssertTrue(loaded.isHidden(.customMetric("weight")))
        XCTAssertFalse(loaded.isHidden(.customMetric("sodium")))
        XCTAssertFalse(loaded.isEssential(.customMetric("weight")))
        XCTAssertTrue(loaded.isEssential(.customMetric("sodium")))
        XCTAssertTrue(loaded.isEssential(.module(.mood)))
    }

    func testMissingMetricRetainsPlacementAndNewMetricsAppendWithoutDuplicates() {
        var preferences = TodayLayoutPreferences.default
        var items = preferences.items(customMetricIDs: ["weight"])
        items.removeAll { $0 == .customMetric("weight") }
        items.insert(.customMetric("weight"), at: 1)
        preferences.setItems(items)
        preferences.setHidden(true, for: .customMetric("weight"))

        // Disabled and archived metrics are filtered by the UI, not removed from storage.
        XCTAssertEqual(preferences.items(customMetricIDs: []), items)
        let updated = preferences.items(customMetricIDs: ["sodium", "weight", "sodium"])
        XCTAssertEqual(Array(updated.dropLast()), items)
        XCTAssertEqual(updated.last, .customMetric("sodium"))
        preferences.setItems(updated)
        XCTAssertTrue(preferences.isHidden(.customMetric("weight")))
        XCTAssertFalse(preferences.isHidden(.customMetric("sodium")))
        XCTAssertEqual(preferences.items(customMetricIDs: ["weight", "sodium"]), updated)
    }

}
