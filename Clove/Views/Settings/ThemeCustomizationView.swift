import SwiftUI

struct ThemeCustomizationView: View {
    @AppStorage(Constants.SELECTED_COLOR) private var selectedColor = ""
    @State private var appColor: Color = Theme.shared.accent
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var colorSectionOpacity: Double = 0
    @State private var accessibilitySectionOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var colorSectionOffset: CGFloat = 30
    @State private var accessibilitySectionOffset: CGFloat = 30
    @State private var presetAnimations: [Bool] = Array(repeating: false, count: 8)
    
    // Predefined color themes
    private let colorPresets = [
        ColorPreset(name: "Blue", color: .blue, description: "Classic and calming"),
        ColorPreset(name: "Green", color: .green, description: "Natural and fresh"),
        ColorPreset(name: "Purple", color: .purple, description: "Creative and modern"),
        ColorPreset(name: "Orange", color: .orange, description: "Energetic and warm"),
        ColorPreset(name: "Pink", color: .pink, description: "Gentle and caring"),
        ColorPreset(name: "Teal", color: .teal, description: "Sophisticated and cool"),
        ColorPreset(name: "Indigo", color: .indigo, description: "Deep and professional"),
        ColorPreset(name: "Red", color: .red, description: "Bold and vibrant")
    ]
    
    var body: some View {
        ZStack {
            // Dynamic gradient background that adapts to selected color
            LinearGradient(
                colors: [
                    appColor.opacity(0.03),
                    CloveColors.background,
                    appColor.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: appColor)
            
            ScrollView {
                VStack(spacing: CloveSpacing.xlarge) {
                    // Enhanced header
                    headerSection
                        .opacity(headerOpacity)
                        .offset(y: headerOffset)
                    
                    // Enhanced color selection section
                    colorSelectionSection
                        .opacity(colorSectionOpacity)
                        .offset(y: colorSectionOffset)
                    
                    // Enhanced accessibility section
                    accessibilitySection
                        .opacity(accessibilitySectionOpacity)
                        .offset(y: accessibilitySectionOffset)
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.xlarge)
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appColor = Theme.shared.accent
            startEntranceAnimations()
        }
        .onChange(of: appColor) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                Theme.shared.accent = newValue
                selectedColor = newValue.toString()
            }
        }
    }
    
    // MARK: - Animation Helpers
    
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerOpacity = 1.0
            headerOffset = 0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            colorSectionOpacity = 1.0
            colorSectionOffset = 0
        }
        
        // Animate preset cards individually
        for i in 0..<presetAnimations.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2 + Double(i) * 0.05)) {
                presetAnimations[i] = true
            }
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            accessibilitySectionOpacity = 1.0
            accessibilitySectionOffset = 0
        }
    }
    
    // MARK: - Enhanced Header Section
    
    private var headerSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Icon and title with dynamic color
            HStack(spacing: CloveSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(appColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appColor)
                    
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(appColor)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Theme")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Personalize your experience")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            // Current color preview
            HStack(spacing: CloveSpacing.medium) {
                Text("Current Theme:")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.primaryText)
                
                Spacer()
                
                HStack(spacing: CloveSpacing.small) {
                    Circle()
                        .fill(appColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .shadow(color: appColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text(getColorName(for: appColor))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(appColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(appColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(appColor.opacity(0.3), lineWidth: 1)
                        )
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
    
    // MARK: - Enhanced Color Selection Section
    
    private var colorSelectionSection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Color")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Select from the following or choose your own")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            VStack(spacing: CloveSpacing.large) {
                // Color presets grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: CloveSpacing.medium) {
                    ForEach(Array(colorPresets.enumerated()), id: \.element.name) { index, preset in
                        ColorPresetCard(
                            preset: preset,
                            isSelected: colorsAreEqual(appColor, preset.color),
                            onTap: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    appColor = preset.color
                                }
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        )
                        .opacity(presetAnimations.indices.contains(index) ? (presetAnimations[index] ? 1.0 : 0) : 0)
                        .scaleEffect(presetAnimations.indices.contains(index) ? (presetAnimations[index] ? 1.0 : 0.8) : 0.8)
                    }
                }
                
                // Custom color picker
                VStack(spacing: CloveSpacing.medium) {
                    HStack {
                        Text("Custom Color")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Spacer()
                    }
                    
                    ColorPicker("Choose custom color", selection: $appColor)
                        .padding(CloveSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                                        .stroke(appColor.opacity(0.3), lineWidth: 1)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appColor)
                                )
                        )
                }
                
                // Reset button
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        appColor = Color.accent
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack(spacing: CloveSpacing.small) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Reset to Default")
                            .font(.system(.body, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(appColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(appColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: CloveCorners.medium)
                                    .stroke(appColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(colorsAreEqual(appColor, Color.accent))
                .opacity(colorsAreEqual(appColor, Color.accent) ? 0.5 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appColor)
            }
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Enhanced Accessibility Section
    
    private var accessibilitySection: some View {
        VStack(spacing: CloveSpacing.large) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("High contrast options")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
            
            // Grayscale option
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appColor = Color.gray
                }
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }) {
                HStack(spacing: CloveSpacing.medium) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "eye")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        Text("High Contrast Mode")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Text("Uses grayscale theme for better accessibility")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(CloveColors.secondaryText)
                            .lineSpacing(1)
                    }
                    
                    Spacer()
                    
                    if colorsAreEqual(appColor, Color.gray) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.gray)
                    }
                }
                .padding(CloveSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.large)
                        .fill(
                            colorsAreEqual(appColor, Color.gray) ?
                            LinearGradient(
                                colors: [Color.gray.opacity(0.08), Color.gray.opacity(0.03)],
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
                                    colorsAreEqual(appColor, Color.gray) ? Color.gray.opacity(0.3) : CloveColors.secondaryText.opacity(0.1),
                                    lineWidth: colorsAreEqual(appColor, Color.gray) ? 2 : 1
                                )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Methods
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        return color1.toString() == color2.toString()
    }
    
    private func getColorName(for color: Color) -> String {
        if let preset = colorPresets.first(where: { colorsAreEqual(color, $0.color) }) {
            return preset.name
        } else if colorsAreEqual(color, Color.gray) {
            return "Gray"
        } else if colorsAreEqual(color, Color.accent) {
            return "Default"
        } else {
            return "Custom"
        }
    }
}

// MARK: - Supporting Models and Views

struct ColorPreset {
    let name: String
    let color: Color
    let description: String
}

struct ColorPresetCard: View {
    let preset: ColorPreset
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CloveSpacing.small) {
                // Color circle
                ZStack {
                    Circle()
                        .fill(preset.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .opacity(isSelected ? 1 : 0)
                        )
                        .overlay(
                            Circle()
                                .stroke(preset.color.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: preset.color.opacity(0.3), radius: isSelected ? 8 : 4, x: 0, y: 2)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Name
                Text(preset.name)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [preset.color.opacity(0.08), preset.color.opacity(0.03)],
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
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(
                                isSelected ? preset.color.opacity(0.3) : preset.color.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : (isPressed ? 0.95 : 1.0))
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
        ThemeCustomizationView()
    }
}
