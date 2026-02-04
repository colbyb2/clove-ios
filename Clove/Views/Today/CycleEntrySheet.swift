import SwiftUI

struct CycleEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let existingEntry: Cycle?
    let onSave: () -> Void

    @State private var selectedFlow: FlowLevel?
    @State private var isStartOfCycle: Bool = false
    @State private var hasCramps: Bool = false
    @State private var animateIn = false

    // Assuming these singletons exist based on your code
    private let repo = CycleRepo.shared
    private let toastManager = ToastManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ZStack {
                Text("Log Period")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primary)
                
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(CloveColors.secondaryText.opacity(0.5))
                    }
                }
            }
            .padding()
            .padding(.top, 10)

            ScrollView {
                VStack(spacing: 32) {
                    
                    // MARK: - Date Display
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Theme.shared.accent)
                        Text(date.formatted(date: .complete, time: .omitted))
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    .padding(.top, 12)
                    .opacity(animateIn ? 1 : 0)
                    
                    // MARK: - Flow Selector
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Flow Intensity")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            ForEach(FlowLevel.allCases, id: \.self) { flow in
                                FlowOptionCard(
                                    flow: flow,
                                    isSelected: selectedFlow == flow
                                ) {
                                    triggerHaptic()
                                    selectedFlow = flow
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                    // MARK: - Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Cycle Start Toggle
                            DetailSelectionRow(
                                title: "Period Started",
                                subtitle: "Mark as Day 1 of new cycle",
                                icon: "arrow.counterclockwise.circle.fill",
                                color: .blue,
                                isSelected: isStartOfCycle
                            ) {
                                triggerHaptic(style: .light)
                                isStartOfCycle.toggle()
                            }
                            
                            // Cramps Toggle
                            DetailSelectionRow(
                                title: "Cramping",
                                subtitle: "Pain or discomfort present",
                                icon: "bolt.heart.fill",
                                color: .orange,
                                isSelected: hasCramps
                            ) {
                                triggerHaptic(style: .light)
                                hasCramps.toggle()
                            }
                        }
                        .padding(.horizontal)
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                }
                .padding(.bottom, 100) // Space for button
            }
            
            // MARK: - Footer / Save
            VStack {
                Divider()
                Button(action: saveEntry) {
                    Text(existingEntry != nil ? "Update Entry" : "Save Entry")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isValid ? Theme.shared.accent : Color.gray.opacity(0.3))
                        )
                }
                .disabled(!isValid)
                .padding()
            }
            .background(CloveColors.card)
        }
        .background(CloveColors.background)
        .onAppear {
            if let entry = existingEntry {
                selectedFlow = entry.flow
                isStartOfCycle = entry.isStartOfCycle
                hasCramps = entry.hasCramps
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }
    
    private var isValid: Bool {
        selectedFlow != nil
    }

    private func saveEntry() {
        guard let flow = selectedFlow else { return }

        let entry = Cycle(
            id: existingEntry?.id,
            date: date,
            flow: flow,
            isStartOfCycle: isStartOfCycle,
            hasCramps: hasCramps
        )

        if repo.save([entry]) {
            toastManager.showToast(
                message: "Cycle logged",
                color: CloveColors.success,
                icon: Image(systemName: "checkmark.circle.fill")
            )
            onSave()
            dismiss()
        } else {
            toastManager.showToast(
                message: "Error saving",
                color: CloveColors.error
            )
        }
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Subcomponents

struct FlowOptionCard: View {
    let flow: FlowLevel
    let isSelected: Bool
    let action: () -> Void
    
    // Dynamic styling based on flow intensity
    var style: (icon: String, scale: CGFloat, color: Color) {
        switch flow {
        case .spotting: return ("drop", 0.8, .pink.opacity(0.6))
        case .light:    return ("drop.fill", 0.8, .pink.opacity(0.8))
        case .medium:   return ("drop.fill", 1.0, .pink)
        case .heavy:    return ("drop.fill", 1.2, .red)
        case .veryHeavy: return ("drop.triangle.fill", 1.1, .purple) // Or a deeper red
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: style.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : style.color)
                    .scaleEffect(style.scale)
                
                Text(flow.displayName)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(isSelected ? .white : CloveColors.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.shared.accent : CloveColors.card)
                    .shadow(
                        color: isSelected ? Theme.shared.accent.opacity(0.3) : Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

struct DetailSelectionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? color : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .foregroundStyle(isSelected ? .white : color)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(CloveColors.primary)
                    
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                // Custom Checkbox/Radio UI
                Circle()
                    .strokeBorder(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(Circle().fill(isSelected ? color : Color.clear))
                    .frame(width: 24, height: 24)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .padding(12)
            .background(CloveColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview Helpers
// Assuming these types exist in your project, defining mocks for preview
#Preview {
    CycleEntrySheet(
        date: Date(),
        existingEntry: nil
    ) {
        print("Saved")
    }
}
