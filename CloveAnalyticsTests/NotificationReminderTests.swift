import Foundation
import XCTest
@testable import Clove

final class NotificationReminderTests: XCTestCase {
    func testThreeRemindersCanBeAddedAndEditedIndependently() throws {
        let suiteName = "NotificationReminderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = NotificationSchedulerSpy()
        let store = NotificationStore(
            userDefaults: defaults,
            notificationScheduler: scheduler,
            storageKey: "test-reminders"
        )

        let morning = ScheduledNotification(
            title: "Morning",
            body: "Log",
            hour: 8,
            minute: 0,
            weekdays: [2, 3, 4, 5, 6]
        )
        let midday = ScheduledNotification(
            title: "Midday",
            body: "Log",
            hour: 12,
            minute: 30,
            weekdays: [2, 4, 6]
        )
        let evening = ScheduledNotification(
            title: "Evening",
            body: "Log",
            hour: 20,
            minute: 0,
            weekdays: [1, 7]
        )

        store.addNotification(morning)
        store.addNotification(midday)
        store.addNotification(evening)

        XCTAssertEqual(store.notifications.count, 3)
        XCTAssertEqual(scheduler.schedules.map(\.id), [morning.id, midday.id, evening.id])

        store.updateNotification(ScheduledNotification(
            id: midday.id,
            title: midday.title,
            body: "Take a midday symptom check-in",
            hour: 13,
            minute: 15,
            isEnabled: true,
            weekdays: [2, 3, 4, 5, 6],
            createdAt: midday.createdAt
        ))

        XCTAssertEqual(store.notifications.first(where: { $0.id == morning.id })?.hour, 8)
        XCTAssertEqual(store.notifications.first(where: { $0.id == midday.id })?.hour, 13)
        XCTAssertEqual(store.notifications.first(where: { $0.id == midday.id })?.weekdays, [2, 3, 4, 5, 6])
        XCTAssertEqual(
            store.notifications.first(where: { $0.id == midday.id })?.displayNote,
            "Take a midday symptom check-in"
        )
        XCTAssertEqual(store.notifications.first(where: { $0.id == evening.id })?.hour, 20)
        XCTAssertTrue(scheduler.cancelledIDs.contains(midday.id))
    }

    func testLegacyReminderWithoutWeekdaysDefaultsToEveryDay() throws {
        let reminder = ScheduledNotification(
            title: "Legacy",
            body: "Log",
            hour: 9,
            minute: 0
        )
        let encoded = try JSONEncoder().encode(reminder)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "weekdays")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ScheduledNotification.self, from: legacyData)

        XCTAssertEqual(decoded.weekdays, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(decoded.daysString, "Every day")
    }
}

private final class NotificationSchedulerSpy: LocalNotificationScheduling {
    struct Schedule {
        let id: String
        let hour: Int
        let minute: Int
        let weekdays: [Int]
    }

    var schedules: [Schedule] = []
    var cancelledIDs: [String] = []

    func scheduleRepeatingNotification(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        weekdays: [Int]
    ) {
        schedules.append(Schedule(id: id, hour: hour, minute: minute, weekdays: weekdays))
    }

    func cancelNotification(id: String) {
        cancelledIDs.append(id)
    }
}
