import SwiftUI


struct CloveButton: View {
   @Environment(\.isEnabled) private var isEnabled
   
   var text = "Button"
   var background: Color = CloveColors.primary
   var fontColor: Color = CloveColors.primaryText
   
   var onClick: () -> Void = {}
   
   var body: some View {
      Button { onClick() } label: {
         ZStack {
            (isEnabled ? background : .gray)
            
            Text(text)
         }
      }
      .foregroundStyle(fontColor)
      .frame(height: 50)
      .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
      .shadow(radius: 2)
      .padding(.horizontal)
   }
}

#Preview {
   CloveButton(fontColor: .white)
}
