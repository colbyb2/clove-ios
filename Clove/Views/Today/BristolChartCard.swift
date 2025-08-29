import SwiftUI

struct BristolChartCard: View {
    let type: BristolStoolType
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Type Number Circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.shared.accent : CloveColors.card)
                        .frame(width: 40, height: 40)
                        .shadow(color: isSelected ? Theme.shared.accent.opacity(0.3) : .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text("\(type.rawValue)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(isSelected ? .white : CloveColors.primaryText)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                
                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.description)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(isSelected ? .white : CloveColors.primaryText)
                        .multilineTextAlignment(.leading)
                    
                    Text(type.consistency)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Theme.shared.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.2) : Theme.shared.accent.opacity(0.1))
                        )
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .scaleEffect(1.2)
                }
            }
            .padding(16)
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
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("Bristol Stool Chart Type \(type.rawValue)")
        .accessibilityHint("\(type.description). Consistency: \(type.consistency). Tap to record this type.")
    }
}

#Preview {
    VStack(spacing: 12) {
        BristolChartCard(type: .type1, isSelected: false) {}
        BristolChartCard(type: .type4, isSelected: true) {}
        BristolChartCard(type: .type7, isSelected: false) {}
    }
    .padding()
    .background(CloveColors.background)
}
