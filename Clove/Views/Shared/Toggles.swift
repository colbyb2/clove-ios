import SwiftUI

struct CloveToggle: View {
   @Binding var toggled: Bool
   
   var onColor: Color = .blue
   var offColor: Color = .gray
   var handleColor: Color = .white
   
   var body: some View {
      ZStack {
         (toggled ? onColor : offColor)
         
         HStack {
            if (toggled) {
               Spacer()
            }
            ZStack {
               Circle()
                  .foregroundStyle(handleColor)
               Text("🔥")
            }
            if (!toggled) {
               Spacer()
            }
         }
      }
      .clipShape(RoundedRectangle(cornerRadius: CloveCorners.full))
      .frame(width: 80, height: 40)
      .onTapGesture {
         withAnimation(.easeInOut(duration: 0.3)) {
            self.toggled.toggle()
         }
      }
   }
}

fileprivate struct PreviewToggle: View {
   @State var isToggled: Bool = false
   
   var body: some View {
      CloveToggle(toggled: $isToggled)
   }
}

#Preview {
   PreviewToggle()
}
