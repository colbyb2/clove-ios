import Foundation

enum WhatsNewContent {
    
    static let version_1_3_0 = Popup(
        id: "whats_new_1_3_0",
        type: .whatsNew,
        icon: "sparkles",
        title: "What's New",
        message: "We've added some exciting new features to help you track your health more comprehensively!",
        features: [
            WhatsNewFeature(
                icon: "toilet",
                title: "Bowel Movement Tracking",
                description: "Track Bristol Stool Chart types to monitor digestive health and correlations with other symptoms"
            ),
            WhatsNewFeature(
                icon: "chart.line.uptrend.xyaxis", 
                title: "Enhance Charts",
                description: "Rebuilt chart engine for better trend analysis and user experience."
            ),
            WhatsNewFeature(
                icon: "square.and.arrow.up",
                title: "CSV Export Updates", 
                description: "Export now includes bowel movement data with timestamps for comprehensive health records"
            )
        ],
        version: "1.3.0"
    )
    
    static let allWhatsNewPopups: [Popup] = [
        version_1_3_0
    ]
}
