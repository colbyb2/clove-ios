import SwiftUI

struct OccasionalFeaturesMenu: View {
    @Environment(\.dismiss) private var dismiss
    let settings: UserSettings
    let onFeatureSelected: (OccasionalFeature) -> Void

    enum OccasionalFeature {
        case cycle
        // Future: case sexualActivity, case appointment, etc.
    }

    private var availableFeatures: [OccasionalFeature] {
        var features: [OccasionalFeature] = []
        if settings.trackCycle { features.append(.cycle) }
        // Future: Add other occasional features here
        return features
    }

    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Add Entry")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primary)

                Text("Track occasional features")
                    .font(.system(.subheadline))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : -20)

            // Feature Grid
            if availableFeatures.isEmpty {
                Text("No occasional features enabled")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .padding()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(availableFeatures, id: \.self) { feature in
                        FeatureCard(feature: feature) {
                            onFeatureSelected(feature)
                        }
                    }
                }
                .padding(.horizontal)
                .opacity(animateIn ? 1 : 0)
                .scaleEffect(animateIn ? 1 : 0.8)
            }

            Spacer()
        }
        .padding(.top, 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
    }
}

extension OccasionalFeaturesMenu.OccasionalFeature: Hashable {}

struct FeatureCard: View {
    let feature: OccasionalFeaturesMenu.OccasionalFeature
    let onTap: () -> Void

    @State private var isPressed = false

    private var featureInfo: (name: String, emoji: String) {
        switch feature {
        case .cycle:
            return ("Cycle", "🩸")
        }
    }

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            // Dismiss after brief delay to show selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onTap()
            }
        }) {
            VStack(spacing: 12) {
                Text(featureInfo.emoji)
                    .font(.system(size: 40))

                Text(featureInfo.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .shadow(
                        color: .gray.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("\(featureInfo.name) tracking")
        .accessibilityHint("Tap to add \(featureInfo.name.lowercased()) entry")
    }
}

#Preview {
    OccasionalFeaturesMenu(settings: .allEnabled) { feature in
        print("Selected feature: \(feature)")
    }
    .presentationDetents([.height(300)])
    .presentationDragIndicator(.visible)
    .presentationBackground(CloveColors.card)
}
