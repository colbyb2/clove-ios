import SwiftUI

struct HydrationTracker: View {
    @Binding var ounces: Int
    var onAmountChanged: (Int) -> Void = { _ in }
    @AppStorage(Constants.HYDRATION_UNIT) private var unitRawValue = HydrationUnit.fluidOunces.rawValue

    private var unit: HydrationUnit { HydrationUnit(rawValue: unitRawValue) ?? .fluidOunces }
    private var quickAmounts: [Int] { HydrationPreferences.quickAmounts(for: unit) }

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Label("Hydration", systemImage: "drop.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Text(unit.formatted(canonicalOunces: ounces))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(CloveColors.blue)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(unit.formatted(canonicalOunces: ounces)) logged")
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

            Stepper(value: persistedDisplayAmount, in: 0...unit.displayValue(fromCanonicalOunces: 512), step: unit.adjustmentStep) {
                Text("Adjust by \(unit.adjustmentStep) \(unit.symbol)")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .accessibilityValue(unit.formatted(canonicalOunces: ounces))
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(CloveColors.blue.opacity(0.25), lineWidth: 1)
                )
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
            .foregroundStyle(CloveColors.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(CloveColors.blue.opacity(configuration.isPressed ? 0.2 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: CloveCorners.small))
    }
}

#Preview {
    @Previewable @State var ounces = 40
    HydrationTracker(ounces: $ounces)
        .padding()
        .background(CloveColors.background)
}
