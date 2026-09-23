import SwiftUI
import XCTest
@testable import Clove

final class UndoRecoveryTests: XCTestCase {
    func testBasicToastCallDispatchesWithoutRecursiveProtocolFallback() {
        let spy = SixArgumentToastSpy()
        let toast: ToastManaging = spy

        toast.showToast(
            message: "Settings saved successfully",
            color: .green,
            icon: nil,
            duration: 3
        )

        XCTAssertEqual(spy.message, "Settings saved successfully")
        XCTAssertEqual(spy.callCount, 1)
        XCTAssertNil(spy.actionTitle)
    }

    func testToastUndoActionCanRestoreDeletedEntry() {
        let toast: ToastManaging = MockToastManager()
        var restored = false

        toast.showToast(
            message: "Entry deleted",
            color: .gray,
            icon: nil,
            duration: 8,
            actionTitle: "Undo",
            action: { restored = true }
        )

        let mock = toast as? MockToastManager
        XCTAssertEqual(mock?.actionTitle, "Undo")
        mock?.action?()
        XCTAssertTrue(restored)
    }
}

private final class SixArgumentToastSpy: ToastManaging {
    var isVisible = false
    var message = ""
    var color = Color.black
    var icon: Image?
    var duration = 3.0
    var showProgress = false
    var offset: CGFloat = 0
    var actionTitle: String?
    var callCount = 0

    func showToast(
        message: String,
        color: Color,
        icon: Image?,
        duration: Double,
        actionTitle: String?,
        action: (() -> Void)?
    ) {
        self.message = message
        self.color = color
        self.icon = icon
        self.duration = duration
        self.actionTitle = actionTitle
        callCount += 1
    }

    func hide() {
        isVisible = false
    }
}
