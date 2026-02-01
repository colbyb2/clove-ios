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

    private let repo = CycleRepo.shared
    private let toastManager = ToastManager.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Track Cycle")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(CloveColors.primary)

                Text(formatDate(date))
                    .font(.system(.subheadline))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : -20)

            ScrollView {
                VStack(spacing: 24) {
                    // Flow Level Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Flow Level")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(CloveColors.primary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(FlowLevel.allCases) { flow in
                                FlowLevelCard(
                                    flow: flow,
                                    isSelected: selectedFlow == flow
                                ) {
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()

                                    selectedFlow = flow
                                }
                            }
                        }
                    }
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.8)

                    // Toggles Section
                    VStack(spacing: 16) {
                        // First day toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("First day of cycle")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(CloveColors.primary)

                                Text("Mark if this is day 1")
                                    .font(.system(.caption))
                                    .foregroundStyle(CloveColors.secondaryText)
                            }

                            Spacer()

                            Toggle("", isOn: $isStartOfCycle)
                                .labelsHidden()
                                .tint(Theme.shared.accent)
                                .onChange(of: isStartOfCycle) { _, _ in
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                        }
                        .padding()
                        .background(CloveColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))

                        // Cramps toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Has cramps")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(CloveColors.primary)

                                Text("Track cramping symptoms")
                                    .font(.system(.caption))
                                    .foregroundStyle(CloveColors.secondaryText)
                            }

                            Spacer()

                            Toggle("", isOn: $hasCramps)
                                .labelsHidden()
                                .tint(Theme.shared.accent)
                                .onChange(of: hasCramps) { _, _ in
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                        }
                        .padding()
                        .background(CloveColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
                    }
                    .opacity(animateIn ? 1 : 0)
                }
                .padding(.horizontal)
            }

            // Save Button
            Button(action: saveEntry) {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(selectedFlow == nil ? CloveColors.secondaryText : Theme.shared.accent)
                        .shadow(
                            color: selectedFlow == nil ? .clear : Theme.shared.accent.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                )
            }
            .disabled(selectedFlow == nil)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .opacity(animateIn ? 1 : 0)
        }
        .padding(.top, 30)
        .onAppear {
            // Load existing entry if provided
            if let entry = existingEntry {
                selectedFlow = entry.flow
                isStartOfCycle = entry.isStartOfCycle
                hasCramps = entry.hasCramps
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                animateIn = true
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
                message: "Cycle entry saved",
                color: CloveColors.success,
                icon: Image(systemName: "checkmark.circle")
            )
            onSave()
            dismiss()
        } else {
            toastManager.showToast(
                message: "Failed to save cycle entry",
                color: CloveColors.error
            )
        }
    }
}

struct FlowLevelCard: View {
    let flow: FlowLevel
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(flowEmoji(for: flow))
                    .font(.system(size: 32))
                    .scaleEffect(isSelected ? 1.2 : 1.0)

                Text(flow.displayName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(isSelected ? .white : CloveColors.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(isSelected ? Theme.shared.accent : CloveColors.card)
                    .shadow(
                        color: isSelected ? Theme.shared.accent.opacity(0.3) : .gray.opacity(0.2),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("\(flow.displayName) flow")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select \(flow.displayName.lowercased()) flow")
    }

    private func flowEmoji(for flow: FlowLevel) -> String {
        switch flow {
        case .spotting: return "💧"
        case .light: return "🩸"
        case .medium: return "🩸🩸"
        case .heavy: return "🩸🩸🩸"
        case .veryHeavy: return "🩸🩸🩸🩸"
        }
    }
}

#Preview {
    CycleEntrySheet(
        date: Date(),
        existingEntry: nil
    ) {
        print("Cycle entry saved")
    }
}
