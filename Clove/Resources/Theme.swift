import SwiftUI

/// Colors
enum CloveColors {
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let accent = Color("Accent")
    static let background = Color("Background")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let card = Color("Card")
    static let success = Color("Success")
    static let error = Color("Error")
    static let info = Color("Info")
}

/// Fonts
enum CloveFonts {
    static func title() -> Font {
        Font.custom("Poppins-SemiBold", size: 22)
    }

    static func sectionTitle() -> Font {
        Font.custom("Poppins-Regular", size: 18)
    }

    static func body() -> Font {
        Font.custom("Inter-Regular", size: 16)
    }

    static func small() -> Font {
        Font.custom("Inter-Regular", size: 14)
    }
}

/// Spacing
enum CloveSpacing {
    static let xsmall: CGFloat = 6
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xlarge: CGFloat = 32
}

/// Corners
enum CloveCorners {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let full: CGFloat = 999 // for pills/circles
}
