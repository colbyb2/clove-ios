import SwiftUI
import XCTest
@testable import Clove

final class UndoRecoveryTests: XCTestCase {
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
