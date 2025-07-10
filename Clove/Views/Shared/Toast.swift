import SwiftUI

struct Toast: View {  
    var body: some View {
        VStack(spacing: 0) {
            if ToastManager.shared.isVisible {
                HStack(spacing: 12) {
                    if let icon = ToastManager.shared.icon {
                        icon
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    Text(ToastManager.shared.message)
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ToastManager.shared.color.opacity(0.7))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .offset(y: ToastManager.shared.offset)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height < -50 {
                                ToastManager.shared.hide()
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: ToastManager.shared.isVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0), value: ToastManager.shared.offset)
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
    
    private init() {}

    var offset: CGFloat = 0
    var message: String = ""
    var color: Color = .black
    var icon: Image? = nil
    var duration: Double = 3.0
    var isVisible: Bool = false
    
    private var hideTask: Task<Void, Never>?

    func showToast(message: String, color: Color = .black, icon: Image? = nil, duration: Double = 3.0) {
        // Cancel any existing hide task
        hideTask?.cancel()
        
        // Set toast properties (these won't animate as they're set before visibility)
        self.message = message
        self.color = color
        self.icon = icon
        self.duration = duration
        self.offset = 0
        
        // Haptic feedback based on toast type
        if color == CloveColors.success {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } else if color == CloveColors.error {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        } else {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Show the toast with animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.isVisible = true
        }
        
        // Hide after duration
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                self.isVisible = false
            }
        }
    }
    
    func hide() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            self.isVisible = false
        }
    }
}

#Preview {
   Toast()
      .onAppear {
         ToastManager.shared.showToast(message: "🚨 Test Toast Message")
      }
}
