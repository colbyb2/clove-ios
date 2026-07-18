import SwiftUI

struct HydrationTracker: View {
    @Binding var ounces: Int
    var onAmountChanged: (Int) -> Void = { _ in }

    private let quickAmounts = [8, 12, 16]

    var body: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack {
                Label("Hydration", systemImage: "drop.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)

                Spacer()

                Text("\(ounces) oz")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(CloveColors.blue)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(ounces) fluid ounces logged")
            }

            HStack(spacing: CloveSpacing.small) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button("+\(amount) oz") {
                        add(amount)
                    }
                    .buttonStyle(HydrationQuickAddButtonStyle())
                    .accessibilityHint("Adds \(amount) fluid ounces")
                }
            }

            Stepper(value: persistedOunces, in: 0...512, step: 1) {
                Text("Adjust by 1 oz")
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .accessibilityValue("\(ounces) fluid ounces")
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

    private func add(_ amount: Int) {
        ounces = min(ounces + amount, 512)
        onAmountChanged(ounces)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var persistedOunces: Binding<Int> {
        Binding(
            get: { ounces },
            set: { newValue in
                ounces = newValue
                onAmountChanged(newValue)
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
