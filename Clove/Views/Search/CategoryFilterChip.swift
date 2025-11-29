import SwiftUI

struct CategoryFilterChip: View {
    let category: SearchCategory
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: CloveSpacing.xsmall) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))

                Text(category.rawValue)
                    .font(CloveFonts.small())
            }
            .padding(.horizontal, CloveSpacing.medium)
            .padding(.vertical, CloveSpacing.small)
            .background(
                Capsule()
                    .fill(isActive ? category.color.opacity(0.2) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(category.color, lineWidth: isActive ? 0 : 1.5)
            )
            .foregroundStyle(isActive ? category.color : CloveColors.secondaryText)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: CloveSpacing.medium) {
        CategoryFilterChip(
            category: .notes,
            isActive: true,
            onTap: {}
        )

        CategoryFilterChip(
            category: .symptoms,
            isActive: false,
            onTap: {}
        )

        CategoryFilterChip(
            category: .meals,
            isActive: true,
            onTap: {}
        )
    }
    .padding()
}
