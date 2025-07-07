import SwiftUI

// MARK: - Accessible Rating Input
struct AccessibleRatingInput: View {
    @Binding var value: Double
    let label: String
    let emoji: String?
    let minValue: Int
    let maxValue: Int
    let step: Int
    let showAlternativeControls: Bool
    
    @AppStorage(Constants.USE_SLIDER_INPUT) private var useSliderInput = true
    
    init(
        value: Binding<Double>,
        label: String,
        emoji: String? = nil,
        minValue: Int = 0,
        maxValue: Int = 10,
        step: Int = 1,
        showAlternativeControls: Bool = true
    ) {
        self._value = value
        self.label = label
        self.emoji = emoji
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.showAlternativeControls = showAlternativeControls
    }
    
    var body: some View {
        VStack(spacing: CloveSpacing.medium) {
            // Header with toggle for input method
            HStack {
                // Label with emoji
                HStack(spacing: CloveSpacing.small) {
                    if let emoji = emoji {
                        Text(emoji)
                            .font(.system(size: 20))
                    }
                    Text(label)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                // Current value display
                Text("\(Int(value))")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.shared.accent)
                
                if showAlternativeControls {
                    // Toggle input method button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            useSliderInput.toggle()
                        }
                        // Haptic feedback for mode switch
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: useSliderInput ? "plusminus" : "slider.horizontal.below.rectangle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                            .frame(width: 44, height: 44) // Minimum touch target
                    }
                    .accessibilityLabel("Switch input method")
                    .accessibilityHint(useSliderInput ? "Switch to plus minus buttons" : "Switch to slider")
                }
            }
            
            // Input control
            if useSliderInput {
                AccessibleSlider(
                    value: $value,
                    minValue: minValue,
                    maxValue: maxValue,
                    step: step
                )
            } else {
                PlusMinusControls(
                    value: $value,
                    minValue: minValue,
                    maxValue: maxValue,
                    step: step,
                    label: label
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label) rating")
        .accessibilityValue("\(Int(value)) out of \(maxValue)")
    }
}

// MARK: - Enhanced Accessible Slider
struct AccessibleSlider: View {
    @Binding var value: Double
    let minValue: Int
    let maxValue: Int
    let step: Int
    
    @State private var isDragging = false
    @State private var lastFeedbackValue: Double = -1
    
    var body: some View {
        VStack(spacing: CloveSpacing.small) {
            // Main slider with enhanced touch area
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CloveColors.background)
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.shared.accent)
                        .frame(
                            width: geometry.size.width * CGFloat((value - Double(minValue)) / Double(maxValue - minValue)),
                            height: 8
                        )
                    
                    // Thumb with larger touch area
                    let thumbPosition = geometry.size.width * CGFloat((value - Double(minValue)) / Double(maxValue - minValue))
                    
                    Circle()
                        .fill(Theme.shared.accent)
                        .frame(width: isDragging ? 28 : 24, height: isDragging ? 28 : 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .position(x: max(12, min(geometry.size.width - 12, thumbPosition)), y: geometry.size.height / 2)
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isDragging)
                }
                .frame(height: 44) // Minimum touch target height
                .contentShape(Rectangle()) // Make entire area tappable
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                // Start haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                            }
                            
                            let newValue = Double(minValue) + (gesture.location.x / geometry.size.width) * Double(maxValue - minValue)
                            let clampedValue = max(Double(minValue), min(Double(maxValue), newValue))
                            let steppedValue = round(clampedValue / Double(step)) * Double(step)
                            
                            // Provide haptic feedback when crossing integer values
                            if abs(steppedValue - lastFeedbackValue) >= Double(step) {
                                let selectionFeedback = UISelectionFeedbackGenerator()
                                selectionFeedback.selectionChanged()
                                lastFeedbackValue = steppedValue
                            }
                            
                            value = steppedValue
                        }
                        .onEnded { _ in
                            isDragging = false
                            // End haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                )
                .onTapGesture { location in
                    // Allow tapping to set value
                    let newValue = Double(minValue) + (location.x / geometry.size.width) * Double(maxValue - minValue)
                    let clampedValue = max(Double(minValue), min(Double(maxValue), newValue))
                    let steppedValue = round(clampedValue / Double(step)) * Double(step)
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        value = steppedValue
                    }
                    
                    // Haptic feedback for tap
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
            .frame(height: 44)
            
            // Value indicators
            HStack {
                Text("\(minValue)")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                
                Spacer()
                
                Text("\(maxValue)")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating slider")
        .accessibilityValue("\(Int(value)) out of \(maxValue)")
        .accessibilityAdjustableAction { direction in
            let change = direction == .increment ? step : -step
            let newValue = max(Double(minValue), min(Double(maxValue), value + Double(change)))
            value = newValue
            
            // Haptic feedback for accessibility adjustment
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
    }
}

// MARK: - Plus/Minus Controls
struct PlusMinusControls: View {
    @Binding var value: Double
    let minValue: Int
    let maxValue: Int
    let step: Int
    let label: String
    
    var body: some View {
        HStack(spacing: CloveSpacing.large) {
            // Minus button
            AccessibleStepperButton(
                icon: "minus",
                action: {
                    let newValue = max(Double(minValue), value - Double(step))
                    value = newValue
                },
                isEnabled: value > Double(minValue),
                style: .secondary
            )
            .accessibilityLabel("Decrease \(label)")
            .accessibilityHint("Decreases value by \(step)")
            
            Spacer()
            
            // Current value with larger touch area for direct editing
            Button(action: {
                // Could implement direct numeric input in the future
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                VStack(spacing: 4) {
                    Text("\(Int(value))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.shared.accent)
                    
                    Text("out of \(maxValue)")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .frame(minWidth: 80, minHeight: 60)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.card)
                        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                )
            }
            .accessibilityLabel("\(label) value: \(Int(value)) out of \(maxValue)")
            .accessibilityHint("Current rating value")
            
            Spacer()
            
            // Plus button
            AccessibleStepperButton(
                icon: "plus",
                action: {
                    let newValue = min(Double(maxValue), value + Double(step))
                    value = newValue
                },
                isEnabled: value < Double(maxValue),
                style: .primary
            )
            .accessibilityLabel("Increase \(label)")
            .accessibilityHint("Increases value by \(step)")
        }
    }
}

// MARK: - Accessible Stepper Button
struct AccessibleStepperButton: View {
    let icon: String
    let action: () -> Void
    let isEnabled: Bool
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    var body: some View {
        Button(action: {
            action()
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isEnabled ? foregroundColor : CloveColors.secondaryText.opacity(0.5))
                .frame(width: 56, height: 56) // Large touch target
                .background(
                    Circle()
                        .fill(isEnabled ? backgroundColor : CloveColors.background)
                        .shadow(
                            color: isEnabled ? shadowColor : .clear,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return Theme.shared.accent
        case .secondary: return CloveColors.card
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Theme.shared.accent
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return Theme.shared.accent.opacity(0.3)
        case .secondary: return .black.opacity(0.1)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        AccessibleRatingInput(
            value: .constant(7),
            label: "Pain Level",
            emoji: "🩹",
            maxValue: 10
        )
        
        AccessibleRatingInput(
            value: .constant(5),
            label: "Mood",
            emoji: "😊",
            maxValue: 10,
            showAlternativeControls: false
        )
        
        PlusMinusControls(
            value: .constant(3),
            minValue: 0,
            maxValue: 10,
            step: 1,
            label: "Energy"
        )
    }
    .padding()
    .background(CloveColors.background)
}
