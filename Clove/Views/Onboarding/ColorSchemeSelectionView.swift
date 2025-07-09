import SwiftUI

struct ColorSchemeSelectionView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @Environment(AppState.self) var appState
    @AppStorage(Constants.SELECTED_COLOR) private var selectedColor = ""
    
    @State private var appColor: Color = Theme.shared.accent
    @State private var selectedTheme: PredefinedTheme?
    
    // Predefined themes
    private let predefinedThemes: [PredefinedTheme] = [
        PredefinedTheme(name: "Ocean Breeze", color: Color(hex: "4A90E2"), description: "Calm and refreshing"),
        PredefinedTheme(name: "Sage Garden", color: Color(hex: "66af56"), description: "Natural and peaceful"),
        PredefinedTheme(name: "Sunset Glow", color: Color(hex: "f77a54"), description: "Warm and comforting"),
        PredefinedTheme(name: "Seaside Passion", color: Color(hex: "76bfad"), description: "Chill and soft")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.xlarge) {
                // Header
                VStack(spacing: CloveSpacing.medium) {
                    
                    Text("Choose Your Theme")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Personalize your app with a color that feels right for you")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CloveSpacing.large)
                }
                
                // Predefined themes section
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    HStack {
                        Text("Preset Themes")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: CloveSpacing.medium) {
                        ForEach(predefinedThemes) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: selectedTheme?.id == theme.id,
                                onTap: {
                                    selectedTheme = theme
                                    appColor = theme.color
                                    applyTheme(theme.color)
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, CloveSpacing.large)
                }
                
                // Custom color picker section
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    HStack {
                        Text("Custom Color")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    
                    VStack(spacing: CloveSpacing.medium) {
                        ColorPicker("Choose what fits best", selection: $appColor)
                            .padding(CloveSpacing.large)
                            .background(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .fill(CloveColors.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                                            .stroke(selectedTheme == nil ? appColor.opacity(0.3) : CloveColors.secondaryText.opacity(0.1), lineWidth: 2)
                                    )
                            )
                            .padding(.horizontal, CloveSpacing.large)
                    }
                }
                
                // Action buttons
                VStack(spacing: CloveSpacing.medium) {
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        HStack(spacing: CloveSpacing.small) {
                            Text("Continue")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CloveSpacing.large)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(appColor)
                        )
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    
                    Button(action: {
                        // Reset to default and continue
                        appColor = Color.accent
                        applyTheme(Color.accent)
                        selectedTheme = nil
                        viewModel.nextStep()
                    }) {
                        Text("Keep Default")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                }
            }
            .padding(.vertical, CloveSpacing.xlarge)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .onChange(of: appColor) { _, newValue in
            // Clear selected theme when using custom color
            if selectedTheme != nil && newValue != selectedTheme!.color {
                selectedTheme = nil
            }
            applyTheme(newValue)
        }
        .onAppear {
            // Initialize with current theme
            appColor = Theme.shared.accent
        }
    }
    
    private func applyTheme(_ color: Color) {
        Theme.shared.accent = color
        selectedColor = color.toString()
    }
}

// MARK: - Supporting Views

struct PredefinedTheme: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let description: String
}

struct ThemeCard: View {
    let theme: PredefinedTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CloveSpacing.medium) {
                // Color circle
                Circle()
                    .fill(theme.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .overlay(
                        Circle()
                            .stroke(theme.color.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: theme.color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: CloveSpacing.xsmall) {
                    Text(theme.name)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(1)
                    
                    Text(theme.description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CloveSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(isSelected ? theme.color : CloveColors.secondaryText.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}


// MARK: - Preview

#Preview {
    ColorSchemeSelectionView()
        .environment(OnboardingViewModel())
        .environment(AppState())
}
