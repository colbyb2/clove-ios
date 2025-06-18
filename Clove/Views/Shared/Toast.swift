import SwiftUI

struct Toast: View {  
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                if let icon = ToastManager.shared.icon {
                    icon
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                
                Text(ToastManager.shared.message)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(ToastManager.shared.color)
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
            .offset(y: ToastManager.shared.offset)
            .animation(.linear, value: ToastManager.shared.offset)
            .padding(.top, 20)
            
            Spacer()
        }
    }
}

struct ToastModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            Toast()
        }
    }
}

extension View {
    func toastable() -> some View {
        self.modifier(ToastModifier())
    }
}

@Observable
class ToastManager {
    static let shared = ToastManager()

    var offset: CGFloat = -150
    var message: String = "Test Toast"
    var color: Color = .blue
    var icon: Image? = nil
    var duration: Double = 3.0

    func showToast(message: String, color: Color = .blue, icon: Image? = nil, duration: Double = 3.0) {
        self.message = message
        self.color = color
        self.icon = icon
        self.duration = duration
        self.offset = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.offset = -150
        }
    }
}

#Preview {
   Toast()
}
