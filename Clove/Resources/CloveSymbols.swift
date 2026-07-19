import Foundation

/// The app-wide SF Symbol vocabulary. Keeping semantic icons here prevents the
/// same health concept from being represented differently between screens.
enum CloveSymbols {
    static let overview = "chart.bar.fill"
    static let mood = "face.smiling"
    static let pain = "bandage.fill"
    static let energy = "bolt.fill"
    static let hydration = "drop.fill"
    static let symptom = "stethoscope"
    static let medication = "pills.fill"
    static let bowelMovement = "toilet"
    static let cycle = "drop.circle.fill"
    static let meals = "fork.knife"
    static let activities = "figure.run"
    static let weather = "cloud.sun.fill"
    static let flare = "flame.fill"
    static let notes = "note.text"

    static func mood(for value: Double) -> String {
        switch value {
        case ...2: return "cloud.rain.fill"
        case ...4: return "cloud.fill"
        case ...6: return "minus.circle.fill"
        case ...8: return "sun.min.fill"
        default: return "sun.max.fill"
        }
    }

    static func weather(for value: String?) -> String {
        switch value {
        case "Sunny": return "sun.max.fill"
        case "Cloudy": return "cloud.fill"
        case "Rainy": return "cloud.rain.fill"
        case "Stormy": return "cloud.bolt.rain.fill"
        case "Snow": return "cloud.snow.fill"
        case "Gloomy": return "cloud.fog.fill"
        default: return weather
        }
    }
}
