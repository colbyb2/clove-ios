import SwiftUI

struct Toast: View {
    @State private var progressValue: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            if ToastManager.shared.isVisible {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Icon
                        if let icon = ToastManager.shared.icon {
                            icon
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                        }

                        // Message text
                        Text(ToastManager.shared.message)
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ToastManager.shared.color)
                    )

                    // Progress bar
                    if ToastManager.shared.showProgress {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(width: geometry.size.width * progressValue, height: 3)
                        }
                        .frame(height: 3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .offset(y: ToastManager.shared.offset)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    progressValue = 1.0

                    // Start progress animation
                    if ToastManager.shared.showProgress {
                        withAnimation(.linear(duration: ToastManager.shared.duration)) {
                            progressValue = 0.0
                        }
                    }
                }
                .onChange(of: ToastManager.shared.isVisible) { _, newValue in
                    if newValue {
                        progressValue = 1.0
                        if ToastManager.shared.showProgress {
                            withAnimation(.linear(duration: ToastManager.shared.duration)) {
                                progressValue = 0.0
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: ToastManager.shared.isVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: ToastManager.shared.offset)
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
    var showProgress: Bool = false

    private var hideTask: Task<Void, Never>?

    func showToast(message: String, color: Color = .black, icon: Image? = nil, duration: Double = 3.0) {
        // Cancel any existing task
        hideTask?.cancel()

        // Set toast properties
        self.message = message
        self.color = color
        self.icon = icon
        self.duration = duration
        self.offset = 0
        self.showProgress = duration > 2.0

        // Haptic feedback
        if color == CloveColors.success {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } else if color == CloveColors.error {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        } else {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }

        // Show the toast
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            self.isVisible = true
        }

        // Hide after duration
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))

            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.isVisible = false
            }
        }
    }

    func hide() {
        hideTask?.cancel()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.isVisible = false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Success Toast") {
            ToastManager.shared.showToast(
                message: "Successfully saved your data!",
                color: CloveColors.success,
                icon: Image(systemName: "checkmark.circle.fill"),
                duration: 4.0
            )
        }

        Button("Error Toast") {
            ToastManager.shared.showToast(
                message: "Something went wrong. Please try again.",
                color: CloveColors.error,
                icon: Image(systemName: "exclamationmark.triangle.fill"),
                duration: 5.0
            )
        }

        Button("Info Toast") {
            ToastManager.shared.showToast(
                message: "This is an informational message",
                color: CloveColors.info,
                icon: Image(systemName: "info.circle.fill")
            )
        }
    }
    .toastable()
}
