import SwiftUI

/// Color Extensions
extension Color {
    /// Initialize a color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (r, g, b) = (1, 1, 0) // bright yellow fallback
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

/// Date Extensions
extension Date: @retroactive Identifiable {
    func stripTime() -> Date {
        Calendar.current.startOfDay(for: self)
    }

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    public var id: String { self.iso8601String }
}
