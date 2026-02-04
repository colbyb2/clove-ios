import SwiftUI

struct OccasionalFeaturesMenu: View {
    @Environment(\.dismiss) private var dismiss
    // Assuming you inject this, or just pass the boolean for preview
    let settings: UserSettings
    let onFeatureSelected: (OccasionalFeature) -> Void

    enum OccasionalFeature: CaseIterable {
        case cycle
    }

    // Dynamic filter based on settings
    private var availableFeatures: [OccasionalFeature] {
        var features: [OccasionalFeature] = []
        if settings.trackCycle { features.append(.cycle) }
        // Mocking future logic
        // features.append(.appointment)
        return features
    }

    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Header
            // Using a standard "Sheet" handle feel
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.bottom, 10)
                
                Text("Log Activity")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primary)

                Text("Select an occasional metric to track")
                    .font(.system(.subheadline))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)

            // MARK: - Feature Grid
            if availableFeatures.isEmpty {
                ContentUnavailableView(
                    "No Features Enabled",
                    systemImage: "slider.horizontal.3",
                    description: Text("Enable occasional tracking in Settings.")
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(availableFeatures, id: \.self) { feature in
                        Button(action: {
                            triggerHaptic()
                            onFeatureSelected(feature)
                        }) {
                            FeatureCardContent(feature: feature)
                        }
                        .buttonStyle(BouncyCardStyle()) // <--- The magic happens here
                    }
                }
                .padding(.horizontal)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.95)
            }

            Spacer()
        }
        .padding(.top, 10)
        .background(CloveColors.background) // Ensure contrast
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
    
    private func triggerHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Visual Components

struct FeatureCardContent: View {
    let feature: OccasionalFeaturesMenu.OccasionalFeature

    var info: (title: String, icon: String, color: Color) {
        switch feature {
        case .cycle:
            return ("Cycle", "drop.fill", Color.pink.opacity(0.8))
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(info.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: info.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(info.color)
            }

            Text(info.title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(CloveColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CloveColors.card)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        // Add a subtle border for definition
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Interaction Logic (The "Apple Feel")

struct BouncyCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        OccasionalFeaturesMenu(settings: .allEnabled) { _ in }
            .presentationDetents([.height(350)])
            .presentationCornerRadius(24)
    }
}
