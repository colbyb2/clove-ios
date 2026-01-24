import SwiftUI

/// Protocol for managing toast notifications
protocol ToastManaging: AnyObject {
    /// Whether the toast is currently visible
    var isVisible: Bool { get set }

    /// The message displayed in the toast
    var message: String { get set }

    /// The background color of the toast
    var color: Color { get set }

    /// Optional icon to display in the toast
    var icon: Image? { get set }

    /// Duration the toast is displayed
    var duration: Double { get set }

    /// Whether to show a progress indicator
    var showProgress: Bool { get set }

    /// Vertical offset for animations
    var offset: CGFloat { get set }

    /// Shows a toast notification
    /// - Parameters:
    ///   - message: The message to display
    ///   - color: The background color (default: .black)
    ///   - icon: Optional icon to display
    ///   - duration: How long to display the toast (default: 3.0 seconds)
    func showToast(message: String, color: Color, icon: Image?, duration: Double)

    /// Hides the currently visible toast
    func hide()
}

/// Protocol extension providing default parameters
extension ToastManaging {
    func showToast(
        message: String,
        color: Color = .black,
        icon: Image? = nil,
        duration: Double = 3.0
    ) {
        showToast(message: message, color: color, icon: icon, duration: duration)
    }
}

/// Conform ToastManager to the protocol
extension ToastManager: ToastManaging {}
