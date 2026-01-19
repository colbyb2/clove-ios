import SwiftUI

/// Protocol for managing app theme
protocol ThemeManaging: AnyObject {
    /// The accent color for the app
    var accent: Color { get set }
}

/// Conform Theme to the protocol
extension Theme: ThemeManaging {}
