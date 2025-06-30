import SwiftUI

/// Colors
enum CloveColors {
   static var primary = Color("MainColor")
   static var secondary = Color("SecondColor")
   static var accent = Color("Accent")
   static var background = Color("Background")
   static var primaryText = Color("PrimaryText")
   static var secondaryText = Color("SecondaryText")
   static var card = Color("Card")
   static var success = Color("Success")
   static var error = Color("Error")
   static var info = Color("Info")
   static var blue = Color("CloveBlue")
   static var green = Color("CloveGreen")
   static var yellow = Color("CloveYellow")
   static var orange = Color("CloveOrange")
   static var red = Color("CloveRed")
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
