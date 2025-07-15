import SwiftUI

struct CompleteView: View {
    @Environment(AppState.self) var appState
    @Environment(OnboardingViewModel.self) var viewModel
    
    @State var animateDone: Bool = false
    
    // Enhanced animation states
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 50
    @State private var iconScale: CGFloat = 0.5
    @State private var iconRotation: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var particleOpacity: Double = 0
    @State private var celebrationScale: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var checkmarkOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.shared.accent.opacity(animateDone ? 0.1 : 0.03),
                        Theme.shared.accent.opacity(animateDone ? 0.2 : 0.05),
                        animateDone ? Theme.shared.accent.opacity(0.1) : Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
                
                // Floating particles effect
                ParticleField(isAnimating: animateDone)
                    .opacity(particleOpacity)
                
                if !animateDone {
                    // Initial content state
                    VStack(spacing: 32) {
                        Spacer()
                        
                        // Hero section
                        VStack(spacing: 24) {
                            // Enhanced icon with shimmer effect
                            ZStack {
                                // Pulse rings
                                ForEach(0..<3) { index in
                                    Circle()
                                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 2)
                                        .frame(width: 120 + CGFloat(index * 20), height: 120 + CGFloat(index * 20))
                                        .scaleEffect(pulseScale)
                                        .opacity(1.0 - Double(index) * 0.3)
                                        .animation(
                                            .easeInOut(duration: 2.0)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.3),
                                            value: pulseScale
                                        )
                                }
                                
                                // Main icon background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Theme.shared.accent.opacity(0.1),
                                                Theme.shared.accent.opacity(0.05)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Theme.shared.accent.opacity(0.2), radius: 20, x: 0, y: 10)
                                
                                // Icon with shimmer overlay
                                ZStack {
                                    Image(systemName: "leaf.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Theme.shared.accent,
                                                    Theme.shared.accent.opacity(0.8)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    // Shimmer effect
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clear,
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 30, height: 60)
                                        .offset(x: shimmerOffset)
                                        .animation(
                                            .linear(duration: 2.0)
                                            .repeatForever(autoreverses: false),
                                            value: shimmerOffset
                                        )
                                        .mask(
                                            Image(systemName: "leaf.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                        )
                                }
                            }
                            .scaleEffect(iconScale)
                            .rotationEffect(.degrees(iconRotation))
                            
                            // Text content with enhanced styling
                            VStack(spacing: 16) {
                                Text("You're all set!")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Theme.shared.accent,
                                                Theme.shared.accent.opacity(0.8)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .multilineTextAlignment(.center)
                                
                                VStack(spacing: 8) {
                                    Text("Your personal health companion is ready")
                                        .font(.system(.title3, design: .rounded, weight: .medium))
                                        .foregroundStyle(CloveColors.secondaryText)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Private • Secure • Free")
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .foregroundStyle(Theme.shared.accent.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Theme.shared.accent.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // Enhanced call-to-action
                        VStack(spacing: 16) {
                            CloveButton(text: "Start Your Journey", fontColor: .white) {
                                startCompletionAnimation()
                            }
                            .shadow(color: Theme.shared.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                            .scaleEffect(0.98)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: contentOpacity)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption)
                                Text("Your data stays on your device")
                                    .font(.system(.caption, design: .rounded))
                            }
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.7))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
                    
                } else {
                    // Success celebration state
                    VStack {
                        Spacer()
                        
                        ZStack {
                            // Success icon background with pulsing effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Theme.shared.accent.opacity(0.3),
                                            Theme.shared.accent.opacity(0.1),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 200, height: 200)
                                .scaleEffect(celebrationScale)
                            
                            // Main success circle
                            Circle()
                                .fill(Theme.shared.accent)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                )
                                .shadow(color: Theme.shared.accent.opacity(0.4), radius: 20, x: 0, y: 10)
                                .scaleEffect(celebrationScale)
                            
                            // Animated checkmark
                            Image(systemName: "checkmark")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(.white)
                                .scaleEffect(checkmarkScale)
                                .opacity(checkmarkOpacity)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            startEntranceAnimation()
        }
    }
    
    private func startEntranceAnimation() {
        // Initial entrance animations
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            contentOpacity = 1.0
            contentOffset = 0
            backgroundOpacity = 1.0
        }
        
        withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.2)) {
            iconScale = 1.0
        }
        
        withAnimation(.linear(duration: 2.0).delay(0.5)) {
            shimmerOffset = 200
        }
        
        // Start pulsing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            pulseScale = 1.1
        }
    }
    
    private func startCompletionAnimation() {
        Task {
            // Trigger the original animation flag
            withAnimation(.easeInOut(duration: 0.8)) {
                animateDone = true
                contentOpacity = 0
                particleOpacity = 1.0
            }
            
            // Wait a moment then show celebration
            try? await Task.sleep(for: .milliseconds(400))
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                celebrationScale = 1.0
            }
            
            // Animate checkmark with delay
            try? await Task.sleep(for: .milliseconds(200))
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkOpacity = 1.0
                checkmarkScale = 1.0
            }
            
            // Wait for celebration to complete
            try? await Task.sleep(for: .seconds(2.0))
            
            // Complete onboarding
            viewModel.completeOnboarding(appState: appState)
        }
    }
}

// MARK: - Supporting Views

struct ParticleField: View {
    let isAnimating: Bool
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Theme.shared.accent.opacity(0.6))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                        .scaleEffect(particle.scale)
                }
            }
        }
        .onAppear {
            if isAnimating {
                createParticles()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                createParticles()
            }
        }
    }
    
    private func createParticles() {
        particles = []
        for _ in 0..<20 {
            let particle = Particle()
            particles.append(particle)
            
            withAnimation(.easeOut(duration: Double.random(in: 1.0...3.0)).delay(Double.random(in: 0...1.0))) {
                particle.animate()
            }
        }
    }
}

class Particle: ObservableObject, Identifiable {
    let id = UUID()
    @Published var x: CGFloat = UIScreen.main.bounds.width / 2
    @Published var y: CGFloat = UIScreen.main.bounds.height / 2
    @Published var opacity: Double = 1.0
    @Published var scale: CGFloat = 1.0
    let size: CGFloat = CGFloat.random(in: 4...12)
    
    func animate() {
        x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
        y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
        opacity = 0.0
        scale = 0.0
    }
}

#Preview {
    CompleteView()
        .environment(OnboardingViewModel())
        .environment(AppState())
}
