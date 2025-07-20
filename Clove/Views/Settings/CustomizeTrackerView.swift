import SwiftUI

struct CustomizeTrackerView: View {
    @Environment(UserSettingsViewModel.self) var viewModel
    @AppStorage(Constants.USE_SLIDER_INPUT) private var useSliderInput = true
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var trackingOpacity: Double = 0
    @State private var inputOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var trackingOffset: CGFloat = 30
    @State private var inputOffset: CGFloat = 30
    @State private var buttonOffset: CGFloat = 30
    @State private var trackingAnimations: [Bool] = Array(repeating: false, count: 10)
    
    // Tracking options with icons and colors
    private let trackingOptions = [
        TrackingOption(key: "trackMood", title: "Mood", icon: "face.smiling", color: .blue, description: "Track your daily mood levels"),
        TrackingOption(key: "trackPain", title: "Pain", icon: "bandage", color: .red, description: "Monitor pain intensity"),
        TrackingOption(key: "trackEnergy", title: "Energy", icon: "bolt.fill", color: .yellow, description: "Log your energy levels"),
        TrackingOption(key: "trackSymptoms", title: "Symptoms", icon: "stethoscope", color: .orange, description: "Track specific symptoms"),
        TrackingOption(key: "trackMeals", title: "Meals", icon: "fork.knife", color: .green, description: "Record your meals"),
        TrackingOption(key: "trackActivities", title: "Activities", icon: "figure.run", color: .cyan, description: "Log physical activities"),
        TrackingOption(key: "trackMeds", title: "Medications", icon: "pills.fill", color: .purple, description: "Track medication adherence"),
        TrackingOption(key: "trackWeather", title: "Weather", icon: "cloud.sun", color: .mint, description: "Record weather conditions"),
        TrackingOption(key: "trackNotes", title: "Notes", icon: "note.text", color: .indigo, description: "Add daily notes"),
        TrackingOption(key: "showFlareToggle", title: "Flare Toggle", icon: "exclamationmark.triangle", color: .pink, description: "Mark flare-up days")
    ]
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Theme.shared.accent.opacity(0.02),
                    CloveColors.background,
                    Theme.shared.accent.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CloveSpacing.xlarge) {
                    // Enhanced header
                    headerSection
                        .opacity(headerOpacity)
                        .offset(y: headerOffset)
                    
                    // Enhanced tracking options
                    trackingSection
                        .opacity(trackingOpacity)
                        .offset(y: trackingOffset)
                    
                    // Enhanced input method section
                    inputMethodSection
                        .opacity(inputOpacity)
                        .offset(y: inputOffset)
                    
                    // Enhanced save button
                    saveButtonSection
                        .opacity(buttonOpacity)
                        .offset(y: buttonOffset)
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.xlarge)
            }
        }
        .navigationTitle("Customize Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startEntranceAnimations()
        }
    }
    
    // MARK: - Animation Helpers
    
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerOpacity = 1.0
            headerOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            trackingOpacity = 1.0
            trackingOffset = 0
        }
        
        // Animate tracking options individually
        for i in 0..<trackingAnimations.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2 + Double(i) * 0.05)) {
                trackingAnimations[i] = true
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            inputOpacity = 1.0
            inputOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
            buttonOpacity = 1.0
            buttonOffset = 0
        }
    }
    
    // MARK: - Enhanced Header Section
    
    private var headerSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Icon and title
            HStack(spacing: CloveSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(Theme.shared.accent.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracker Customization")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Choose what to track daily")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            // Description
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Choose the metrics that YOU want to track.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineSpacing(2)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Enhanced Tracking Section
    
    private var trackingSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What to Track")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Select your health metrics")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                // Count badge
                let enabledCount = getEnabledTrackingCount()
                if enabledCount > 0 {
                    Text("\(enabledCount)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Theme.shared.accent)
                        )
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: CloveSpacing.medium) {
                ForEach(Array(trackingOptions.enumerated()), id: \.element.key) { index, option in
                    CompactTrackingToggleCard(
                        option: option,
                        isEnabled: getTrackingValue(for: option.key),
                        onToggle: { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                setTrackingValue(for: option.key, value: value)
                            }
                        }
                    )
                    .opacity(trackingAnimations.indices.contains(index) ? (trackingAnimations[index] ? 1.0 : 0) : 0)
                    .scaleEffect(trackingAnimations.indices.contains(index) ? (trackingAnimations[index] ? 1.0 : 0.9) : 0.9)
                }
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Enhanced Input Method Section
    
    private var inputMethodSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input Method")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Choose your preferred input style")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            VStack(spacing: CloveSpacing.medium) {
                // Slider option
                EnhancedInputMethodCard(
                    title: "Slider Input",
                    description: "Use sliders for quick rating adjustments",
                    icon: "slider.horizontal.3",
                    isSelected: useSliderInput,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            useSliderInput = true
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                )
                
                // Button option
                EnhancedInputMethodCard(
                    title: "Button Input",
                    description: "Use plus/minus buttons for precise control",
                    icon: "plus.forwardslash.minus",
                    isSelected: !useSliderInput,
                    onTap: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            useSliderInput = false
                        }
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                )
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Enhanced Save Button Section
    
    private var saveButtonSection: some View {
        VStack(spacing: CloveSpacing.small) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.save()
                }
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }) {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Save Changes")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .fill(
                            LinearGradient(
                                colors: [Theme.shared.accent, Theme.shared.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Theme.shared.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            
            Text("Changes will be applied immediately")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(CloveColors.secondaryText)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTrackingValue(for key: String) -> Bool {
        switch key {
        case "trackMood": return viewModel.settings.trackMood
        case "trackPain": return viewModel.settings.trackPain
        case "trackEnergy": return viewModel.settings.trackEnergy
        case "trackSymptoms": return viewModel.settings.trackSymptoms
        case "trackMeals": return viewModel.settings.trackMeals
        case "trackActivities": return viewModel.settings.trackActivities
        case "trackMeds": return viewModel.settings.trackMeds
        case "trackWeather": return viewModel.settings.trackWeather
        case "trackNotes": return viewModel.settings.trackNotes
        case "showFlareToggle": return viewModel.settings.showFlareToggle
        default: return false
        }
    }
    
    private func setTrackingValue(for key: String, value: Bool) {
        switch key {
        case "trackMood": viewModel.settings.trackMood = value
        case "trackPain": viewModel.settings.trackPain = value
        case "trackEnergy": viewModel.settings.trackEnergy = value
        case "trackSymptoms": viewModel.settings.trackSymptoms = value
        case "trackMeals": viewModel.settings.trackMeals = value
        case "trackActivities": viewModel.settings.trackActivities = value
        case "trackMeds": viewModel.settings.trackMeds = value
        case "trackWeather": viewModel.settings.trackWeather = value
        case "trackNotes": viewModel.settings.trackNotes = value
        case "showFlareToggle": viewModel.settings.showFlareToggle = value
        default: break
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func getEnabledTrackingCount() -> Int {
        return trackingOptions.reduce(0) { count, option in
            count + (getTrackingValue(for: option.key) ? 1 : 0)
        }
    }
}

// MARK: - Supporting Models and Views

struct TrackingOption {
    let key: String
    let title: String
    let icon: String
    let color: Color
    let description: String
}

struct CompactTrackingToggleCard: View {
    let option: TrackingOption
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isEnabled)
        }) {
            VStack(spacing: CloveSpacing.medium) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isEnabled ? option.color : option.color.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isEnabled ? option.color.opacity(0.3) : option.color.opacity(0.2), lineWidth: 2)
                        )
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isEnabled ? .white : option.color)
                }
                
                // Title and toggle
                VStack(spacing: CloveSpacing.small) {
                    Text(option.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    // Compact toggle
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isEnabled ? Theme.shared.accent : CloveColors.secondaryText.opacity(0.3))
                            .frame(width: 40, height: 24)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .offset(x: isEnabled ? 8 : -8)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEnabled)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.large)
                    .fill(
                        isEnabled ?
                        LinearGradient(
                            colors: [option.color.opacity(0.08), option.color.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [CloveColors.background, CloveColors.background],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.large)
                            .stroke(
                                isEnabled ? option.color.opacity(0.3) : CloveColors.secondaryText.opacity(0.1),
                                lineWidth: isEnabled ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isEnabled ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEnabled)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedInputMethodCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CloveSpacing.medium) {
                // Enhanced icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.shared.accent : Theme.shared.accent.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Theme.shared.accent.opacity(0.3) : Theme.shared.accent.opacity(0.2), lineWidth: 2)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Theme.shared.accent)
                }
                
                // Content
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text(description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineSpacing(1)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
            }
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.large)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Theme.shared.accent.opacity(0.08), Theme.shared.accent.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [CloveColors.background, CloveColors.background],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.large)
                            .stroke(
                                isSelected ? Theme.shared.accent.opacity(0.3) : Theme.shared.accent.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : (isPressed ? 0.98 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    NavigationView {
        CustomizeTrackerView()
            .environment(UserSettingsViewModel())
    }
}
