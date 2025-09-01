import Foundation

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    
    init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
    }
}