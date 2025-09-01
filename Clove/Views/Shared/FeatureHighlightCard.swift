import SwiftUI

struct FeatureHighlightCard: View {
    let feature: WhatsNewFeature
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Feature icon
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.shared.accent)
            }
            
            // Feature content
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(feature.description)
                    .font(.system(size: 14))
                    .foregroundStyle(CloveColors.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: CloveSpacing.medium) {
        FeatureHighlightCard(
            feature: WhatsNewFeature(
                icon: "toilet",
                title: "Bowel Movement Tracking",
                description: "Track Bristol Stool Chart types to monitor digestive health patterns"
            )
        )
        
        FeatureHighlightCard(
            feature: WhatsNewFeature(
                icon: "chart.line.uptrend.xyaxis",
                title: "Enhanced Analytics",
                description: "Improved correlation analysis with better data aggregation"
            )
        )
    }
    .padding()
    .background(CloveColors.background)
}