import SwiftUI
import XCTest
@testable import Clove

final class ToastManagerTests: XCTestCase {
    func testNotificationsStackAndDismissIndependently() {
        let manager = ToastManager()
        let first = manager.showPersistentToast(message: "First")
        let second = manager.showPersistentToast(message: "Second")

        XCTAssertEqual(manager.notifications.map(\.message), ["First", "Second"])
        XCTAssertTrue(manager.isVisible)

        manager.dismiss(first)

        XCTAssertEqual(manager.notifications.map(\.id), [second])
        XCTAssertEqual(manager.message, "Second")
        XCTAssertTrue(manager.isVisible)
    }

    func testPersistentNotificationHasNoTimer() async throws {
        let manager = ToastManager()
        manager.showPersistentToast(message: "Until dismissed")

        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(manager.notifications.count, 1)
        XCTAssertTrue(manager.notifications[0].isPersistent)
        manager.dismissAll()
    }

    func testTimedNotificationDismissesItselfWithoutRemovingPersistentNeighbor() async throws {
        let manager = ToastManager()
        manager.showPersistentToast(message: "Persistent")
        manager.postToast(message: "Brief", duration: 0.1)

        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(manager.notifications.map(\.message), ["Persistent"])
        manager.dismissAll()
    }

    func testActionDismissesOnlyItsNotificationAndRunsHandler() {
        let manager = ToastManager()
        var actionRan = false
        let actionable = manager.postToast(
            message: "Removed",
            duration: 10,
            actionTitle: "Undo"
        ) {
            actionRan = true
        }
        let neighbor = manager.showPersistentToast(message: "Neighbor")

        manager.performAction(for: actionable)

        XCTAssertTrue(actionRan)
        XCTAssertEqual(manager.notifications.map(\.id), [neighbor])
        manager.dismissAll()
    }

    func testCustomContentCanBePersistentAndDismissedByIdentifier() {
        let manager = ToastManager()
        let id = manager.showToast(color: .purple) { _ in
            HStack {
                Text("Custom")
                Button("Action") {}
            }
        }

        XCTAssertEqual(manager.notifications.count, 1)
        XCTAssertNotNil(manager.notifications[0].customContent)
        XCTAssertTrue(manager.notifications[0].isPersistent)

        manager.dismiss(id)
        XCTAssertTrue(manager.notifications.isEmpty)
    }
}
