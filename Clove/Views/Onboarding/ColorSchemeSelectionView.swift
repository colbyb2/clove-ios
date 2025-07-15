import SwiftUI

struct ColorSchemeSelectionView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @Environment(AppState.self) var appState
    @AppStorage(Constants.SELECTED_COLOR) private var selectedColor = ""
    
    @State private var appColor: Color = Theme.shared.accent
    @State private var selectedTheme: PredefinedTheme?
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = -30
    @State private var presetSectionOpacity: Double = 0
    @State private var presetSectionOffset: CGFloat = 50
    @State private var customSectionOpacity: Double = 0
    @State private var customSectionOffset: CGFloat = 50
    @State private var buttonsOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 50
    @State private var themeCardsVisible: [Bool] = Array(repeating: false, count: 4)
    
    // Predefined themes
    private let predefinedThemes: [PredefinedTheme] = [
        PredefinedTheme(name: "Ocean Breeze", color: Color(hex: "4A90E2"), description: "Calm and refreshing"),
        PredefinedTheme(name: "Sage Garden", color: Color(hex: "66af56"), description: "Natural and peaceful"),
        PredefinedTheme(name: "Sunset Glow", color: Color(hex: "f77a54"), description: "Warm and comforting"),
        PredefinedTheme(name: "Smooth Stone", color: Color(hex: "7c7c7c"), description: "Easy on the eyes")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: CloveSpacing.xlarge) {
                // Enhanced Header with gradient background
                VStack(spacing: CloveSpacing.medium) {
                    // Icon with animated gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        appColor.opacity(0.2),
                                        appColor.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .blur(radius: 20)
                        
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        appColor,
                                        appColor.opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(headerOpacity)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: headerOpacity)
                    
                    Text("Choose Your Theme")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    CloveColors.primaryText,
                                    CloveColors.primaryText.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                    
                    Text("Personalize your app with a color that feels right for you")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CloveSpacing.large)
                        .lineSpacing(2)
                }
                .opacity(headerOpacity)
                .offset(y: headerOffset)
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: headerOpacity)
                
                // Enhanced Predefined themes section
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preset Themes")
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Text("Carefully crafted color palettes")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: CloveSpacing.medium) {
                        ForEach(Array(predefinedThemes.enumerated()), id: \.element.id) { index, theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: selectedTheme?.id == theme.id,
                                onTap: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTheme = theme
                                        appColor = theme.color
                                    }
                                    applyTheme(theme.color)
                                    
                                    // Enhanced haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            )
                            .opacity(themeCardsVisible[index] ? 1 : 0)
                            .scaleEffect(themeCardsVisible[index] ? 1 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6 + Double(index) * 0.1), value: themeCardsVisible[index])
                        }
                    }
                    .padding(.horizontal, CloveSpacing.large)
                }
                .opacity(presetSectionOpacity)
                .offset(y: presetSectionOffset)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: presetSectionOpacity)
                
                // Enhanced Custom color picker section
                VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Color")
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                                .foregroundStyle(CloveColors.primaryText)
                            
                            Text("Create your own unique theme")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(CloveColors.secondaryText)
                        }
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
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        selectedTheme == nil ? appColor.opacity(0.4) : CloveColors.secondaryText.opacity(0.1),
                                                        selectedTheme == nil ? appColor.opacity(0.2) : CloveColors.secondaryText.opacity(0.05)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: selectedTheme == nil ? appColor.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
                            )
                            .padding(.horizontal, CloveSpacing.large)
                    }
                }
                .opacity(customSectionOpacity)
                .offset(y: customSectionOffset)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: customSectionOpacity)
                
                // Enhanced Action buttons
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
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            appColor,
                                            appColor.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: appColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .padding(.horizontal, CloveSpacing.large)
                    .scaleEffect(0.98)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appColor)
                    
                    Button(action: {
                        // Reset to default and continue with subtle animation
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            appColor = Color.accent
                            selectedTheme = nil
                        }
                        applyTheme(Color.accent)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.nextStep()
                        }
                    }) {
                        HStack(spacing: CloveSpacing.xsmall) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Keep Default")
                                .font(.system(.body, design: .rounded))
                        }
                        .foregroundStyle(CloveColors.secondaryText)
                    }
                }
                .opacity(buttonsOpacity)
                .offset(y: buttonsOffset)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(1.2), value: buttonsOpacity)
            }
            .padding(.vertical, CloveSpacing.xlarge)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    CloveColors.background,
                    appColor.opacity(0.02)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onChange(of: appColor) { _, newValue in
            // Clear selected theme when using custom color
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selectedTheme != nil && !colorsAreEqual(newValue, selectedTheme!.color) {
                    selectedTheme = nil
                }
            }
            applyTheme(newValue)
        }
        .onAppear {
            // Initialize with current theme
            appColor = Theme.shared.accent
            
            // Trigger entrance animations
            withAnimation {
                headerOpacity = 1.0
                headerOffset = 0
                presetSectionOpacity = 1.0
                presetSectionOffset = 0
                customSectionOpacity = 1.0
                customSectionOffset = 0
                buttonsOpacity = 1.0
                buttonsOffset = 0
                
                // Animate theme cards individually
                for i in 0..<themeCardsVisible.count {
                    themeCardsVisible[i] = true
                }
            }
        }
    }
    
    private func applyTheme(_ color: Color) {
        Theme.shared.accent = color
        selectedColor = color.toString()
    }
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        // Convert colors to strings for comparison since Color comparison can be unreliable
        return color1.toString() == color2.toString()
    }
}

// MARK: - Supporting Views

struct PredefinedTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    let description: String
    
    init(name: String, color: Color, description: String) {
        self.id = name // Use name as stable identifier
        self.name = name
        self.color = color
        self.description = description
    }
    
    static func == (lhs: PredefinedTheme, rhs: PredefinedTheme) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ThemeCard: View {
    let theme: PredefinedTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTap()
            }
        }) {
            VStack(spacing: CloveSpacing.medium) {
                // Enhanced color circle with multiple layers
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(theme.color.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .blur(radius: 10)
                        .opacity(isSelected ? 1 : 0)
                    
                    // Color circle
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.color,
                                    theme.color.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .opacity(isSelected ? 1 : 0)
                        )
                        .overlay(
                            Circle()
                                .stroke(theme.color.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: theme.color.opacity(0.3), radius: isSelected ? 12 : 8, x: 0, y: 4)
                    
                    // Checkmark for selection
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(isSelected ? 1 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
                
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
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isSelected ? theme.color.opacity(0.6) : CloveColors.secondaryText.opacity(0.1),
                                        isSelected ? theme.color.opacity(0.3) : CloveColors.secondaryText.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: isSelected ? theme.color.opacity(0.2) : .black.opacity(0.03), radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.03 : (isPressed ? 0.97 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    ColorSchemeSelectionView()
        .environment(OnboardingViewModel())
        .environment(AppState())
}
