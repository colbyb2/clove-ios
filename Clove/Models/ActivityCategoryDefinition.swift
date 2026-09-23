import Foundation
import GRDB
import SwiftUI

struct ActivityCategoryDefinition: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    var colorHex: String
    var isPreset: Bool
    var sortOrder: Int

    static let databaseTableName = "activityCategory"

    var color: Color { Color(hex: colorHex) }

    static let presets: [ActivityCategoryDefinition] = [
        .init(id: "exercise", name: "Exercise", symbol: "figure.run", colorHex: "3578C8", isPreset: true, sortOrder: 0),
        .init(id: "wellness", name: "Wellness", symbol: "heart.fill", colorHex: "39875A", isPreset: true, sortOrder: 1),
        .init(id: "social", name: "Social", symbol: "person.2.fill", colorHex: "B45F20", isPreset: true, sortOrder: 2),
        .init(id: "chores", name: "Chores", symbol: "house.fill", colorHex: "8A6A12", isPreset: true, sortOrder: 3),
        .init(id: "rest", name: "Rest", symbol: "bed.double.fill", colorHex: "7651B5", isPreset: true, sortOrder: 4),
        .init(id: "other", name: "Other", symbol: "ellipsis.circle.fill", colorHex: "66707A", isPreset: true, sortOrder: 5)
    ]

    static let fallback = presets.last!
}

enum ActivityCategoryStyle {
    static let symbols = [
        "figure.walk", "figure.run", "figure.strengthtraining.traditional", "figure.mind.and.body",
        "heart.fill", "cross.case.fill", "briefcase.fill", "house.fill",
        "person.2.fill", "paintpalette.fill", "book.fill", "bed.double.fill"
    ]

    // Dark enough for legible text/icons in light mode and distinct in dark mode.
    static let colors = ["3578C8", "39875A", "B45F20", "8A6A12", "7651B5", "A13D63", "217C7E", "66707A"]
}
