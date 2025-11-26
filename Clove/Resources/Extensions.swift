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
    
    func toString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return "\(red),\(green),\(blue),\(alpha)"
    }
    
    func adjustedBrightness(_ factor: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Scale each channel toward white (lighter) or toward black (darker)
        if factor > 1 {
            r = min(1.0, r + (1 - r) * (factor - 1))
            g = min(1.0, g + (1 - g) * (factor - 1))
            b = min(1.0, b + (1 - b) * (factor - 1))
        } else {
            r = max(0.0, r * factor)
            g = max(0.0, g * factor)
            b = max(0.0, b * factor)
        }
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

extension String {
    
    /// Turns a string of value "red,green,blue,alpha" to a Color
    func toColor() -> Color? {
        let rgbArray = self.components(separatedBy: ",")
        if let red = Double (rgbArray[0]), let green = Double (rgbArray[1]), let blue = Double(rgbArray[2]), let alpha = Double (rgbArray[3]){
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }
        return nil
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

/// View Extensions
extension View {
    
    /// Applies a modifier conditionally based on a boolean condition
    /// - Parameters:
    ///   - condition: Whether to apply the transformation
    ///   - transform: The transformation to apply if condition is true
    /// - Returns: The transformed view if condition is true, otherwise the original view
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies different transformations based on a boolean condition
    /// - Parameters:
    ///   - condition: The condition to evaluate
    ///   - ifTransform: The transformation to apply if condition is true
    ///   - elseTransform: The transformation to apply if condition is false
    /// - Returns: The transformed view based on the condition
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        @ViewBuilder then ifTransform: (Self) -> TrueContent,
        @ViewBuilder else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
}
