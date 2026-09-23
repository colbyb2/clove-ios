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
}
