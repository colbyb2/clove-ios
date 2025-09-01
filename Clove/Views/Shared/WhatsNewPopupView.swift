import SwiftUI

struct WhatsNewPopupView: View {
    let popup: Popup
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isVisible)
            
            // Popup content
            popupContent
                .scaleEffect(isVisible ? 1 : 0.9)
                .opacity(isVisible ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    private var popupContent: some View {
        VStack(spacing: 0) {
            // Header with title and version
            headerSection
            
            // Features section
            featuresSection
            
            // Action button
            actionButton
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.7, 500))
        .background(popupBackground)
        .padding(.horizontal, 24)
    }
    
    private var headerSection: some View {
        VStack(spacing: CloveSpacing.medium) {
            // App icon or feature icon
            ZStack {
                Circle()
                    .fill(Theme.shared.accent.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: popup.icon ?? "star.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.shared.accent)
            }
            
            // Title
            Text(popup.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
                .multilineTextAlignment(.center)
            
            // Version badge
            if let version = popup.version {
                Text("Version \(version)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.shared.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.shared.accent.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.shared.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.top, CloveSpacing.large)
        .padding(.bottom, CloveSpacing.medium)
        .padding(.horizontal, CloveSpacing.medium)
    }
    
    private var featuresSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: CloveSpacing.medium) {
                // Introduction message if provided
                if !popup.message.isEmpty {
                    Text(popup.message)
                        .font(.system(size: 16))
                        .foregroundStyle(CloveColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CloveSpacing.medium)
                }
                
                // Feature highlights
                if let features = popup.features, !features.isEmpty {
                    LazyVStack(spacing: CloveSpacing.small) {
                        ForEach(features) { feature in
                            FeatureHighlightCard(feature: feature)
                        }
                    }
                    .padding(.horizontal, CloveSpacing.medium)
                }
            }
            .padding(.vertical, CloveSpacing.medium)
            .padding(.bottom, CloveSpacing.large)
        }
    }
    
    private var actionButton: some View {
        VStack(spacing: 0) {
            Divider()
                .background(CloveColors.secondaryText.opacity(0.2))
            
            Button(action: {
                dismissPopup()
            }) {
                HStack(spacing: CloveSpacing.small) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Got it!")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(Theme.shared.accent)
                )
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.vertical, CloveSpacing.medium)
        }
        .background(CloveColors.card)
    }
    
    private var popupBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(CloveColors.card)
            .shadow(
                color: .black.opacity(0.15),
                radius: 20,
                x: 0,
                y: 10
            )
    }
    
    private func dismissPopup() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        // Dismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            PopupManager.shared.close()
        }
    }
}

#Preview {
    ZStack {
        CloveColors.background
            .ignoresSafeArea()
        
        WhatsNewPopupView(
            popup: Popup(
                id: "whats_new_1_2_2",
                type: .whatsNew,
                icon: "sparkles",
                title: "What's New",
                message: "We've added some exciting new features to help you track your health more comprehensively!",
                features: [
                    WhatsNewFeature(
                        icon: "toilet",
                        title: "Bowel Movement Tracking",
                        description: "Track Bristol Stool Chart types to monitor digestive health patterns"
                    ),
                    WhatsNewFeature(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Enhanced Analytics",
                        description: "Improved correlation analysis with better data aggregation"
                    ),
                    WhatsNewFeature(
                        icon: "square.and.arrow.up",
                        title: "CSV Export Updates",
                        description: "Export now includes bowel movement data for comprehensive health records"
                    )
                ],
                version: "1.2.2"
            )
        )
    }
}
