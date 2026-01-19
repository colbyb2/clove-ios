import SwiftUI

/// Mock implementation of ToastManaging for testing and previews
final class MockToastManager: ToastManaging {
    var isVisible: Bool = false
    var message: String = ""
    var color: Color = .black
    var icon: Image? = nil
    var duration: Double = 3.0
    var showProgress: Bool = false
    var offset: CGFloat = 0

    /// Tracks the last message shown (useful for testing)
    var lastShownMessage: String?

    /// Tracks how many times showToast was called
    var showCallCount: Int = 0

    func showToast(message: String, color: Color, icon: Image?, duration: Double) {
        self.message = message
        self.color = color
        self.icon = icon
        self.duration = duration
        self.showProgress = duration > 2.0
        self.lastShownMessage = message
        self.showCallCount += 1
        self.isVisible = true
    }

    func hide() {
        isVisible = false
    }
}
