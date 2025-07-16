import SwiftUI

struct Toast: View {
    @State private var progressValue: Double = 1.0
    @State private var scaleEffect: CGFloat = 1.0
    @State private var rotationEffect: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if ToastManager.shared.isVisible {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        // Enhanced icon with animation
                        if let icon = ToastManager.shared.icon {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                icon
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                                    .scaleEffect(scaleEffect)
                                    .rotationEffect(.degrees(rotationEffect))
                            }
                        }
                        
                        // Message text with improved typography
                        Text(ToastManager.shared.message)
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                        
                        // Close button for longer toasts
                        if ToastManager.shared.duration > 4.0 {
                            Button(action: {
                                ToastManager.shared.hide()
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 20, height: 20)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.2))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            // Main background with enhanced gradient
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            ToastManager.shared.color,
                                            ToastManager.shared.color.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Subtle border highlight
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .white.opacity(0.3),
                                            .white.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                            
                            // Animated shimmer effect for success toasts
                            if ToastManager.shared.color == CloveColors.success {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                .clear,
                                                .white.opacity(0.2),
                                                .clear
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: ToastManager.shared.shimmerOffset)
                            }
                        }
                    )
                    
                    // Progress bar
                    if ToastManager.shared.showProgress {
                        HStack {
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(height: 3)
                                .overlay(
                                    GeometryReader { geometry in
                                        Rectangle()
                                            .fill(.white.opacity(0.8))
                                            .frame(width: geometry.size.width * progressValue)
                                    },
                                    alignment: .leading
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 1.5)
                                )
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 6)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ToastManager.shared.color.opacity(0.95))
                        .shadow(color: ToastManager.shared.color.opacity(0.3), radius: 12, x: 0, y: 6)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .scaleEffect(ToastManager.shared.toastScale)
                .offset(y: ToastManager.shared.offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                ToastManager.shared.offset = value.translation.height * 0.5
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -50 {
                                ToastManager.shared.hide()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    ToastManager.shared.offset = 0
                                }
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .move(edge: .top)).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .move(edge: .top)).combined(with: .opacity)
                ))
                .onAppear {
                    // Reset animation values
                    progressValue = 1.0
                    scaleEffect = 1.0
                    rotationEffect = 0
                    
                    // Icon animation based on toast type
                    if ToastManager.shared.color == CloveColors.success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                            scaleEffect = 1.2
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.4)) {
                            scaleEffect = 1.0
                        }
                    } else if ToastManager.shared.color == CloveColors.error {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 10).repeatCount(2, autoreverses: true).delay(0.1)) {
                            rotationEffect = 5
                        }
                    }
                    
                    // Start progress animation
                    if ToastManager.shared.showProgress {
                        withAnimation(.linear(duration: ToastManager.shared.duration)) {
                            progressValue = 0.0
                        }
                    }
                }
                .onChange(of: ToastManager.shared.isVisible) { _, newValue in
                    if newValue {
                        // Reset progress when toast becomes visible
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
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: ToastManager.shared.isVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: ToastManager.shared.offset)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: ToastManager.shared.toastScale)
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
    
    // Enhanced animation properties
    var toastScale: CGFloat = 1.0
    var showProgress: Bool = false
    var shimmerOffset: CGFloat = -200
    
    private var hideTask: Task<Void, Never>?
    private var shimmerTask: Task<Void, Never>?

    func showToast(message: String, color: Color = .black, icon: Image? = nil, duration: Double = 3.0) {
        // Cancel any existing tasks
        hideTask?.cancel()
        shimmerTask?.cancel()
        
        // Set toast properties
        self.message = message
        self.color = color
        self.icon = icon
        self.duration = duration
        self.offset = 0
        self.toastScale = 0.9
        self.showProgress = duration > 2.0 // Show progress for longer toasts
        
        // Enhanced haptic feedback
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
        
        // Show the toast with enhanced animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            self.isVisible = true
        }
        
        // Scale to full size
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
            self.toastScale = 1.0
        }
        
        // Start shimmer effect for success toasts
        if color == CloveColors.success {
            startShimmerEffect()
        }
        
        // Hide after duration
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            
            guard !Task.isCancelled else { return }
            
            // Pre-hide scale animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.toastScale = 0.95
            }
            
            // Hide with delay
            try? await Task.sleep(for: .seconds(0.1))
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.isVisible = false
                self.toastScale = 0.9
            }
        }
    }
    
    func hide() {
        hideTask?.cancel()
        shimmerTask?.cancel()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.toastScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.isVisible = false
                self.toastScale = 0.9
            }
        }
    }
    
    private func startShimmerEffect() {
        shimmerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.linear(duration: 1.0)) {
                self.shimmerOffset = 400
            }
            
            try? await Task.sleep(for: .seconds(1.0))
            
            guard !Task.isCancelled else { return }
            
            self.shimmerOffset = -200
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
