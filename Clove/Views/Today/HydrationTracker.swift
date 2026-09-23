import SwiftUI

struct HydrationTracker: View {
    @Binding var ounces: Int
    var onAmountChanged: (Int) -> Void = { _ in }
    @AppStorage(Constants.HYDRATION_UNIT) private var unitRawValue = HydrationUnit.fluidOunces.rawValue
    @State private var showsAdjustment = false

    private var unit: HydrationUnit { HydrationUnit(rawValue: unitRawValue) ?? .fluidOunces }
    private var quickAmounts: [Int] { HydrationPreferences.quickAmounts(for: unit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Hydration", systemImage: "drop.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Text(unit.formatted(canonicalOunces: ounces))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.shared.accent)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(unit.formatted(canonicalOunces: ounces)) logged")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showsAdjustment.toggle() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.bold())
                        .foregroundStyle(CloveColors.secondaryText)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(showsAdjustment ? "Hide hydration adjustment" : "Adjust hydration precisely")
            }

            HStack(spacing: CloveSpacing.small) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button("+\(amount) \(unit.symbol)") {
                        add(amount)
                    }
                    .buttonStyle(HydrationQuickAddButtonStyle())
                    .accessibilityHint("Adds \(amount) \(unit.title.lowercased())")
                }
            }

            if showsAdjustment {
                Stepper(value: persistedDisplayAmount, in: 0...unit.displayValue(fromCanonicalOunces: 512), step: unit.adjustmentStep) {
                    Text("Adjust by \(unit.adjustmentStep) \(unit.symbol)")
                        .font(CloveFonts.small())
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .accessibilityValue(unit.formatted(canonicalOunces: ounces))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
        )
    }

    private func add(_ displayAmount: Int) {
        let canonicalAmount = unit.canonicalOunces(fromDisplayValue: displayAmount)
        ounces = min(ounces + canonicalAmount, 512)
        onAmountChanged(ounces)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var persistedDisplayAmount: Binding<Int> {
        Binding(
            get: { unit.displayValue(fromCanonicalOunces: ounces) },
            set: { newValue in
                let canonicalValue = unit.canonicalOunces(fromDisplayValue: newValue)
                ounces = canonicalValue
                onAmountChanged(canonicalValue)
            }
        )
    }
}

private struct HydrationQuickAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.shared.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.shared.accent.opacity(configuration.isPressed ? 0.2 : 0.09))
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
    }
}

#Preview {
    @Previewable @State var ounces = 40
    HydrationTracker(ounces: $ounces)
        .padding()
        .background(CloveColors.background)
}
