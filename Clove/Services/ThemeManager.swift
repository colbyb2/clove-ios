import SwiftUI

@Observable
class Theme {
   static let shared = Theme()
   var accent: Color = CloveColors.accent
}
