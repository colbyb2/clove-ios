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
    
    static let version_1_5_0 = Popup(
        id: "whats_new_1_5_0",
        type: .whatsNew,
        icon: "sparkles",
        title: "What's New",
        message: "We've added some exciting new features and improvements to create a better experience!",
        features: [
            WhatsNewFeature(
                icon: "fork.knife.circle",
                title: "Overhauled Meals/Activities Features",
                description: "Much more robust and easy to use meal/activity tracking!"
            ),
            WhatsNewFeature(
                icon: "drop.circle.fill",
                title: "Cycle",
                description: "Track your period and cycle, view statistics, and see period predictions!"
            ),
            WhatsNewFeature(
                icon: "ladybug.fill",
                title: "Bug Fixes",
                description: "Ensuring the best possible experience!"
            ),
        ],
        version: "1.5.0"
    )

    static let version_1_6_0 = Popup(
        id: "whats_new_1_6_0",
        type: .whatsNew,
        icon: "sparkles",
        title: "Clove Just Got Smarter",
        message: "Explore your health more deeply, track your day more quickly, and make sense of your patterns with less effort.",
        features: [
            WhatsNewFeature(
                icon: "chart.xyaxis.line",
                title: "All-New Health Insights",
                description: "A redesigned dashboard, richer metric charts, clearer findings, personal baselines, and easier-to-understand comparisons."
            ),
            WhatsNewFeature(
                icon: "drop.fill",
                title: "Hydration Tracking",
                description: "Quickly log water throughout the day, set a daily goal, and review progress in charts and History."
            ),
            WhatsNewFeature(
                icon: "bolt.fill",
                title: "Faster Daily Logging",
                description: "Automatic saving, editable entries, and clearer symptom tools make daily tracking quicker and easier."
            )
        ],
        version: "1.6.0"
    )

    static let version_1_7_0 = Popup(
        id: "whats_new_1_7_0",
        type: .whatsNew,
        icon: "leaf.fill",
        title: "A Clearer, Calmer Clove",
        message: "The places you use most have been rebuilt to make tracking faster and your history easier to understand.",
        features: [
            WhatsNewFeature(
                icon: "checkmark.circle.fill",
                title: "A Calmer Daily Check-In",
                description: "Today is cleaner and easier to personalize, with focused check-ins, flexible rating controls, quick symptom logging, and optional Gentle Plans."
            ),
            WhatsNewFeature(
                icon: "calendar.badge.clock",
                title: "History You Can Explore",
                description: "A completely redesigned calendar, richer day summaries, clearer full-day details, and more useful search make it easier to revisit your records."
            ),
            WhatsNewFeature(
                icon: "sparkles.rectangle.stack.fill",
                title: "Insights Made Understandable",
                description: "Metric Explorer, Discover, tracking coverage, and comparisons now prioritize the clearest signals and explain what your data can—and cannot—show."
            ),
            WhatsNewFeature(
                icon: "wand.and.stars",
                title: "Polished From the Start",
                description: "A new onboarding experience, improved tracker customization, flexible reminders, and richer in-app notifications help Clove fit the way you track."
            )
        ],
        version: "1.7.0"
    )
    
    static let allWhatsNewPopups: [Popup] = [
        version_1_7_0
    ]
}
