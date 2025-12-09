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
    
    static let version_1_4_0 = Popup(
        id: "whats_new_1_4_0",
        type: .whatsNew,
        icon: "sparkles",
        title: "What's New",
        message: "We've added some exciting new features and improvements to create a better experience!",
        features: [
            WhatsNewFeature(
                icon: "iphone.gen2",
                title: "Improved UI",
                description: "Upgraded user experience based on your feedback!"
            ),
            WhatsNewFeature(
                icon: "sparkle.magnifyingglass",
                title: "Search",
                description: "New search tab allows you to instantly find any and all information within your data!"
            ),
            WhatsNewFeature(
                icon: "bolt.heart.fill",
                title: "Symptom Enhancements",
                description: "Add a one time symptom, switch between 0-10 scale OR Yes/No Rating, and find old inactive symptoms in the explorer!"
            ),
            WhatsNewFeature(
                icon: "plus.app",
                title: "And More!",
                description: "Check settings for a full change log."
            )
        ],
        version: "1.4.0"
    )
    
    static let allWhatsNewPopups: [Popup] = [
        version_1_4_0
    ]
}
