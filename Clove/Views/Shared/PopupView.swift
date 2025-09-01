import SwiftUI

struct PopupView: View {
    let popup: Popup
    
    var body: some View {
        Group {
            switch popup.type {
            case .terms:
                LegalPopupView(popup: popup)
            case .whatsNew:
                WhatsNewPopupView(popup: popup)
            }
        }
    }
}

struct LegalPopupView: View {
    let popup: Popup
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isVisible)
                .onTapGesture {
                    // Optional: dismiss on backdrop tap
                    // dismissPopup()
                }
            
            // Popup content
            legalPopupContent
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
    
    private var legalPopupContent: some View {
        VStack(spacing: 0) {
            // Header with title
            legalPopupHeader
            
            // Scrollable content area
            legalScrollableContent
            
            // Bottom button
            legalDoneButton
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.8, 600))
        .background(legalPopupBackground)
        .padding(.horizontal, 24)
    }
    
    private var legalPopupHeader: some View {
        VStack(spacing: 16) {
            // Title
            Text(popup.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
            
            // Divider
            Divider()
                .background(Color(.systemGray4))
        }
    }
    
    private var legalScrollableContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text(popup.message)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var legalDoneButton: some View {
        VStack(spacing: 0) {
            // Top divider
            Divider()
                .background(Color(.systemGray4))
            
            // Button
            Button(action: {
                dismissLegalPopup()
            }) {
                Text("Done")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.shared.accent)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
        }
    }
    
    private var legalPopupBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(
                color: .black.opacity(0.15),
                radius: 20,
                x: 0,
                y: 10
            )
    }
    
    private func dismissLegalPopup() {
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

// MARK: - Usage Examples
extension PopupView {
    static func privacyPolicy() -> some View {
        let longMessage = """
        Privacy Policy
        
        Last updated: [Date]
        
        This Privacy Policy describes how we collect, use, and protect your personal information when you use our chronic illness tracking application.
        
        Information We Collect:
        • Health data you voluntarily input (symptoms, mood, pain levels)
        • Usage analytics to improve app performance
        • Device information for compatibility purposes
        
        How We Use Your Information:
        • To provide personalized health tracking features
        • To generate insights about your health patterns
        • To improve our services and user experience
        • To ensure app security and prevent misuse
        
        Data Protection:
        • All health data is encrypted both in transit and at rest
        • We use industry-standard security measures
        • Your data is never sold to third parties
        • You maintain full control over your data
        
        Your Rights:
        • Access your personal data at any time
        • Request deletion of your account and data
        • Export your data in a portable format
        • Opt out of non-essential data collection
        
        Contact Us:
        If you have questions about this Privacy Policy, please contact us at privacy@example.com
        
        Changes to This Policy:
        We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.
        
        By continuing to use our app, you acknowledge that you have read and understood this Privacy Policy.
        """
        
        return PopupView(
            popup: Popup(
                id: "privacy",
                title: "Privacy Policy",
                message: longMessage
            )
        )
    }
}

#Preview {
    ZStack {
        // Background content
        VStack(spacing: 20) {
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 100)
                .cornerRadius(12)
            
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 150)
                .cornerRadius(12)
        }
        .padding()
        
        // Popup overlay
        PopupView.privacyPolicy()
    }
}
