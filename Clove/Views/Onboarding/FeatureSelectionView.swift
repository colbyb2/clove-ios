import SwiftUI

struct FeatureSelectionView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Build your check-in")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(CloveColors.primaryText)
                        Spacer()
                        Text("\(enabledCount) selected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.shared.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.shared.accent.opacity(0.11), in: Capsule())
                    }

                    Text("Choose what is useful now. You can change this anytime.")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.useRecommendedTracker()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.shared.accent)
                            .frame(width: 36, height: 36)
                            .background(Theme.shared.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended start")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CloveColors.primaryText)
                            Text("Mood, energy, symptoms, and notes")
                                .font(.caption)
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.shared.accent)
                    }
                    .padding(11)
                    .background(Theme.shared.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.shared.accent.opacity(0.16)))
                }
                .buttonStyle(.plain)

                featureSection(
                    title: "Daily wellbeing",
                    subtitle: "How you feel from day to day",
                    options: [.mood, .pain, .energy, .symptoms, .flare]
                )

                featureSection(
                    title: "Health and routines",
                    subtitle: "Habits, treatments, and body signals",
                    options: [.hydration, .meals, .activities, .medications, .bowel, .cycle]
                )

                featureSection(
                    title: "Personal context",
                    subtitle: "Extra detail when it helps",
                    options: [.notes, .plans, .weather]
                )
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.top, 8)
            .padding(.bottom, 100)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    viewModel.nextStep()
                } label: {
                    Text("Continue")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.shared.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(enabledCount == 0)
                .opacity(enabledCount == 0 ? 0.45 : 1)

                if enabledCount == 0 {
                    Text("Choose at least one item to create your check-in")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    private func featureSection(title: String, subtitle: String, options: [OnboardingFeature]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(CloveColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(options) { option in
                    featureTile(option)
                }
            }
        }
    }

    private func featureTile(_ option: OnboardingFeature) -> some View {
        let enabled = value(for: option)
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                setValue(!enabled, for: option)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: option.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(option.color)
                    .frame(width: 31, height: 31)
                    .background(option.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))

                Text(option.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(enabled ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(enabled ? option.color.opacity(0.07) : CloveColors.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(enabled ? option.color.opacity(0.25) : CloveColors.secondaryText.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(enabled ? "Selected" : "Not selected")
        .accessibilityHint(option.description)
    }

    private var enabledCount: Int {
        OnboardingFeature.allCases.reduce(0) { $0 + (value(for: $1) ? 1 : 0) }
    }

    private func value(for option: OnboardingFeature) -> Bool {
        switch option {
        case .mood: viewModel.baseSettings.trackMood
        case .pain: viewModel.baseSettings.trackPain
        case .energy: viewModel.baseSettings.trackEnergy
        case .symptoms: viewModel.baseSettings.trackSymptoms
        case .flare: viewModel.baseSettings.showFlareToggle
        case .hydration: viewModel.baseSettings.trackHydration
        case .meals: viewModel.baseSettings.trackMeals
        case .activities: viewModel.baseSettings.trackActivities
        case .medications: viewModel.baseSettings.trackMeds
        case .bowel: viewModel.baseSettings.trackBowelMovements
        case .cycle: viewModel.baseSettings.trackCycle
        case .notes: viewModel.baseSettings.trackNotes
        case .plans: viewModel.pacingPlansEnabled
        case .weather: viewModel.baseSettings.trackWeather
        }
    }

    private func setValue(_ value: Bool, for option: OnboardingFeature) {
        switch option {
        case .mood: viewModel.baseSettings.trackMood = value
        case .pain: viewModel.baseSettings.trackPain = value
        case .energy: viewModel.baseSettings.trackEnergy = value
        case .symptoms: viewModel.baseSettings.trackSymptoms = value
        case .flare: viewModel.baseSettings.showFlareToggle = value
        case .hydration: viewModel.baseSettings.trackHydration = value
        case .meals: viewModel.baseSettings.trackMeals = value
        case .activities: viewModel.baseSettings.trackActivities = value
        case .medications: viewModel.baseSettings.trackMeds = value
        case .bowel: viewModel.baseSettings.trackBowelMovements = value
        case .cycle: viewModel.baseSettings.trackCycle = value
        case .notes: viewModel.baseSettings.trackNotes = value
        case .plans: viewModel.pacingPlansEnabled = value
        case .weather: viewModel.baseSettings.trackWeather = value
        }
        viewModel.persistDraft()
    }
}

private enum OnboardingFeature: String, CaseIterable, Identifiable {
    case mood, pain, energy, symptoms, flare, hydration, meals, activities, medications, bowel, cycle, notes, plans, weather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: "Mood"
        case .pain: "Pain"
        case .energy: "Energy"
        case .symptoms: "Symptoms"
        case .flare: "Flare Day"
        case .hydration: "Hydration"
        case .meals: "Meals"
        case .activities: "Activities"
        case .medications: "Medications"
        case .bowel: "Bowel"
        case .cycle: "Cycle"
        case .notes: "Notes"
        case .plans: "Gentle Plans"
        case .weather: "Weather"
        }
    }

    var icon: String {
        switch self {
        case .mood: "face.smiling"
        case .pain: "bandage.fill"
        case .energy: "bolt.fill"
        case .symptoms: "stethoscope"
        case .flare: "exclamationmark.triangle.fill"
        case .hydration: "drop.fill"
        case .meals: "fork.knife"
        case .activities: "figure.run"
        case .medications: "pills.fill"
        case .bowel: "toilet.fill"
        case .cycle: "circle.dotted.circle.fill"
        case .notes: "note.text"
        case .plans: "leaf.fill"
        case .weather: "cloud.sun.fill"
        }
    }

    var color: Color {
        switch self {
        case .mood: .blue
        case .pain: .red
        case .energy: .yellow
        case .symptoms: .orange
        case .flare: .pink
        case .hydration: .cyan
        case .meals: .green
        case .activities: .mint
        case .medications: .purple
        case .bowel: .brown
        case .cycle: .pink
        case .notes: .indigo
        case .plans: .teal
        case .weather: .blue
        }
    }

    var description: String {
        switch self {
        case .mood: "Track a daily mood rating"
        case .pain: "Record overall pain intensity"
        case .energy: "Log your daily energy"
        case .symptoms: "Track the symptoms that matter to you"
        case .flare: "Mark days when symptoms flare"
        case .hydration: "Record daily water intake"
        case .meals: "Keep a simple meal log"
        case .activities: "Record movement and activities"
        case .medications: "Log medications you take"
        case .bowel: "Record bowel movements and Bristol type"
        case .cycle: "Record period days and flow when relevant"
        case .notes: "Add free-form context to a day"
        case .plans: "Keep an optional list separate from activity data"
        case .weather: "Manually record the day's conditions"
        }
    }
}

#Preview {
    FeatureSelectionView()
        .environment(OnboardingViewModel())
}
