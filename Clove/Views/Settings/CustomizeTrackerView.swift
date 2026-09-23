import SwiftUI

struct CustomizeTrackerView: View {
    @Environment(UserSettingsViewModel.self) private var viewModel
    @AppStorage(Constants.USE_SLIDER_INPUT) private var useSliderInput = true
    @AppStorage(Constants.PACING_PLANS_ENABLED) private var pacingPlansEnabled = false

    @State private var saveStatus: SaveStatus = .saved

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let trackingOptions = [
        TrackingOption(key: "trackMood", title: "Mood", icon: "face.smiling", color: .blue, description: "Track your daily mood levels"),
        TrackingOption(key: "trackPain", title: "Pain", icon: "bandage", color: .red, description: "Monitor pain intensity"),
        TrackingOption(key: "trackEnergy", title: "Energy", icon: "bolt.fill", color: .yellow, description: "Log your energy levels"),
        TrackingOption(key: "trackHydration", title: "Hydration", icon: "drop.fill", color: .blue, description: "Track daily water intake"),
        TrackingOption(key: "trackSymptoms", title: "Symptoms", icon: "stethoscope", color: .orange, description: "Track specific symptoms"),
        TrackingOption(key: "trackMeals", title: "Meals", icon: "fork.knife", color: .green, description: "Record your meals"),
        TrackingOption(key: "trackPlans", title: "Gentle Plans", icon: "leaf.fill", color: .teal, description: "Keep an optional pacing list"),
        TrackingOption(key: "trackActivities", title: "Activities", icon: "figure.run", color: .cyan, description: "Log physical activities"),
        TrackingOption(key: "trackMeds", title: "Medications", icon: "pills.fill", color: .purple, description: "Track medication adherence"),
        TrackingOption(key: "trackWeather", title: "Weather", icon: "cloud.sun", color: .mint, description: "Record weather conditions"),
        TrackingOption(key: "trackBowelMovements", title: "Bowel Movements", icon: "toilet", color: Color(hex: "9b6230"), description: "Track Bristol Stool Chart types"),
        TrackingOption(key: "trackCycle", title: "Cycle", icon: "drop.fill", color: Color(hex: "ff6b9d"), description: "Track period and flow levels"),
        TrackingOption(key: "trackNotes", title: "Notes", icon: "note.text", color: .indigo, description: "Add daily notes"),
        TrackingOption(key: "showFlareToggle", title: "Flare Day", icon: "exclamationmark.triangle", color: .pink, description: "Mark flare-up days")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeader

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(trackingOptions) { option in
                        TrackerFeatureTile(
                            option: option,
                            isEnabled: trackingValue(for: option.key)
                        ) {
                            setTrackingValue(for: option.key, value: !trackingValue(for: option.key))
                        }
                    }
                }

                arrangeTodayLink
                inputMethodSection
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.top, CloveSpacing.small)
            .padding(.bottom, CloveSpacing.xlarge)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Choose What to Track")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("Your daily tracker")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                    Text("\(enabledTrackingCount) on")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.shared.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.shared.accent.opacity(0.1), in: Capsule())
                }
                Text("Tap a feature to show or hide it. Changes save instantly.")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }

            Spacer(minLength: 8)

            Image(systemName: saveStatus.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(saveStatus.color)
                .frame(width: 32, height: 32)
                .background(saveStatus.color.opacity(0.1), in: Circle())
                .accessibilityLabel(saveStatus.accessibilityLabel)
        }
        .padding(.horizontal, 2)
    }

    private var arrangeTodayLink: some View {
        NavigationLink {
            TodayLayoutSettingsView(settings: viewModel.settings)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.shared.accent)
                    .frame(width: 38, height: 38)
                    .background(Theme.shared.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Arrange Today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    Text("Reorder enabled features and choose essentials")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(12)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .stroke(CloveColors.secondaryText.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var inputMethodSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rating controls")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CloveColors.primaryText)
                Text("Choose how you enter numbered ratings")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }

            HStack(spacing: 4) {
                inputMethodButton(
                    title: "Sliders",
                    icon: "slider.horizontal.3",
                    isSelected: useSliderInput
                ) { selectInputMethod(usesSliders: true) }

                inputMethodButton(
                    title: "Buttons",
                    icon: "plus.forwardslash.minus",
                    isSelected: !useSliderInput
                ) { selectInputMethod(usesSliders: false) }
            }
            .padding(3)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .stroke(CloveColors.secondaryText.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func inputMethodButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.shared.accent : CloveColors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    isSelected ? Theme.shared.accent.opacity(0.11) : Color.clear,
                    in: RoundedRectangle(cornerRadius: CloveCorners.small)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func trackingValue(for key: String) -> Bool {
        switch key {
        case "trackMood": viewModel.settings.trackMood
        case "trackPain": viewModel.settings.trackPain
        case "trackEnergy": viewModel.settings.trackEnergy
        case "trackHydration": viewModel.settings.trackHydration
        case "trackSymptoms": viewModel.settings.trackSymptoms
        case "trackMeals": viewModel.settings.trackMeals
        case "trackPlans": pacingPlansEnabled
        case "trackActivities": viewModel.settings.trackActivities
        case "trackMeds": viewModel.settings.trackMeds
        case "trackWeather": viewModel.settings.trackWeather
        case "trackBowelMovements": viewModel.settings.trackBowelMovements
        case "trackCycle": viewModel.settings.trackCycle
        case "trackNotes": viewModel.settings.trackNotes
        case "showFlareToggle": viewModel.settings.showFlareToggle
        default: false
        }
    }

    private func setTrackingValue(for key: String, value: Bool) {
        let previousValue = trackingValue(for: key)
        applyTrackingValue(for: key, value: value)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard key != "trackPlans" else {
            saveStatus = .saved
            return
        }

        saveStatus = .saving
        if viewModel.save(showSuccessFeedback: false) {
            saveStatus = .saved
        } else {
            applyTrackingValue(for: key, value: previousValue)
            saveStatus = .failed
        }
    }

    private func applyTrackingValue(for key: String, value: Bool) {
        switch key {
        case "trackMood": viewModel.settings.trackMood = value
        case "trackPain": viewModel.settings.trackPain = value
        case "trackEnergy": viewModel.settings.trackEnergy = value
        case "trackHydration": viewModel.settings.trackHydration = value
        case "trackSymptoms": viewModel.settings.trackSymptoms = value
        case "trackMeals": viewModel.settings.trackMeals = value
        case "trackPlans": pacingPlansEnabled = value
        case "trackActivities": viewModel.settings.trackActivities = value
        case "trackMeds": viewModel.settings.trackMeds = value
        case "trackWeather": viewModel.settings.trackWeather = value
        case "trackBowelMovements": viewModel.settings.trackBowelMovements = value
        case "trackCycle": viewModel.settings.trackCycle = value
        case "trackNotes": viewModel.settings.trackNotes = value
        case "showFlareToggle": viewModel.settings.showFlareToggle = value
        default: break
        }
    }

    private func selectInputMethod(usesSliders: Bool) {
        guard useSliderInput != usesSliders else { return }
        useSliderInput = usesSliders
        saveStatus = .saved
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var enabledTrackingCount: Int {
        trackingOptions.reduce(0) { $0 + (trackingValue(for: $1.key) ? 1 : 0) }
    }
}

private enum SaveStatus {
    case saving
    case saved
    case failed

    var icon: String {
        switch self {
        case .saving: "arrow.triangle.2.circlepath"
        case .saved: "checkmark"
        case .failed: "exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .saving: Theme.shared.accent
        case .saved: CloveColors.success
        case .failed: CloveColors.error
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .saving: "Saving changes"
        case .saved: "Changes saved automatically"
        case .failed: "Changes could not be saved"
        }
    }
}

private struct TrackingOption: Identifiable {
    let key: String
    let title: String
    let icon: String
    let color: Color
    let description: String

    var id: String { key }
}

private struct TrackerFeatureTile: View {
    let option: TrackingOption
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                Image(systemName: option.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(option.color)
                    .frame(width: 30, height: 30)
                    .background(option.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Text(option.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 2)

                ZStack {
                    Capsule()
                        .fill(isEnabled ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.22))
                        .frame(width: 32, height: 19)
                    Circle()
                        .fill(.white)
                        .frame(width: 15, height: 15)
                        .offset(x: isEnabled ? 6.5 : -6.5)
                        .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                isEnabled ? option.color.opacity(0.07) : CloveColors.card,
                in: RoundedRectangle(cornerRadius: CloveCorners.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .stroke(
                        isEnabled ? option.color.opacity(0.22) : CloveColors.secondaryText.opacity(0.08),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(isEnabled ? "On" : "Off")
        .accessibilityHint(option.description)
    }
}

#Preview {
    NavigationStack {
        CustomizeTrackerView()
            .environment(UserSettingsViewModel.preview())
    }
}
