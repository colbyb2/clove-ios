import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

@Observable
class WeatherManager {
    static let shared = WeatherManager()
    
    private let weatherService = WeatherService.shared
    private let locationManager = LocationManager.shared
    
    var isLoading = false
    var lastWeatherData: String?
    var weatherError: String?
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetches current weather data and returns a formatted string
    /// Returns nil if weather tracking is disabled, location not available, or on error
    func getCurrentWeatherString() async -> String? {
        // Check if user has weather tracking enabled
        guard let settings = UserSettingsRepo.shared.getSettings(),
              settings.trackWeather else {
            return nil
        }
        
        // Check if we have location permission
        guard locationManager.isLocationEnabled else {
            weatherError = "Location permission required for weather data"
            return nil
        }
        
        // Request current location
        locationManager.requestCurrentLocation()
        
        // Wait briefly for location update
        for _ in 0..<5 { // Wait up to 2.5 seconds
            if locationManager.currentLocation != nil { break }
            try? await Task.sleep(for: .milliseconds(500))
        }
        
        guard let location = locationManager.currentLocation else {
            weatherError = "Unable to get current location"
            return nil
        }
        
        return await fetchWeatherString(for: location)
    }
    
    // MARK: - Private Methods
    
    private func fetchWeatherString(for location: CLLocation) async -> String? {
        isLoading = true
        weatherError = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            let currentWeather = weather.currentWeather
            
            let weatherString = formatWeatherString(
                condition: currentWeather.condition,
                temperature: currentWeather.temperature,
                humidity: currentWeather.humidity,
                windSpeed: currentWeather.wind.speed
            )
            
            lastWeatherData = weatherString
            isLoading = false
            return weatherString
            
        } catch {
            weatherError = "Failed to fetch weather: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    private func formatWeatherString(
        condition: WeatherCondition,
        temperature: Measurement<UnitTemperature>,
        humidity: Double,
        windSpeed: Measurement<UnitSpeed>
    ) -> String {
        // Convert temperature to Fahrenheit for US users, Celsius for others
        let tempFormatter = MeasurementFormatter()
        tempFormatter.unitOptions = .providedUnit
        tempFormatter.numberFormatter.maximumFractionDigits = 0
        
        let temperatureValue = temperature.converted(to: .fahrenheit)
        let tempString = tempFormatter.string(from: temperatureValue)
        
        // Get human-readable condition
        let conditionString = getReadableCondition(condition)
        
        // Create compact weather string like "Sunny 72°F" or "Cloudy 45°F"
        return "\(conditionString) \(tempString)"
    }
    
    private func getReadableCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return "Clear"
        case .cloudy:
            return "Cloudy"
        case .haze:
            return "Hazy"
        case .mostlyClear:
            return "Mostly Clear"
        case .mostlyCloudy:
            return "Mostly Cloudy"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .rain:
            return "Rainy"
        case .heavyRain:
            return "Heavy Rain"
        case .isolatedThunderstorms:
            return "Isolated Storms"
        case .scatteredThunderstorms:
            return "Scattered Storms"
        case .strongStorms:
            return "Strong Storms"
        case .thunderstorms:
            return "Thunderstorms"
        case .snow:
            return "Snowy"
        case .blizzard:
            return "Blizzard"
        case .blowingSnow:
            return "Blowing Snow"
        case .freezingDrizzle:
            return "Freezing Drizzle"
        case .freezingRain:
            return "Freezing Rain"
        case .frigid:
            return "Frigid"
        case .hail:
            return "Hail"
        case .heavySnow:
            return "Heavy Snow"
        case .hot:
            return "Hot"
        case .sleet:
            return "Sleet"
        case .windy:
            return "Windy"
        case .wintryMix:
            return "Wintry Mix"
        case .blowingDust:
           return "Blowing Dust"
        case .breezy:
           return "Breezy"
        case .drizzle:
           return "Drizzle"
        case .flurries:
           return "Flurries"
        case .foggy:
           return "Foggy"
        case .hurricane:
           return "Hurricane"
        case .smoky:
           return "Smoky"
        case .sunFlurries:
           return "Sun Flurries"
        case .sunShowers:
           return "Sun Showers"
        case .tropicalStorm:
           return "Tropical Storm"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Weather Data Extension
extension WeatherManager {
    /// Gets a detailed weather description for display purposes
    func getDetailedWeatherString(from weatherString: String?) -> String? {
        guard let weather = weatherString else { return nil }
        
        // For now, just return the basic string
        // Could be expanded to include more details like humidity, wind, etc.
        return weather
    }
    
    /// Extracts just the temperature from a weather string
    func getTemperature(from weatherString: String?) -> String? {
        guard let weather = weatherString else { return nil }
        
        // Extract temperature using regex or string parsing
        let components = weather.components(separatedBy: " ")
        for component in components {
            if component.contains("°") {
                return component
            }
        }
        return nil
    }
    
    /// Extracts just the condition from a weather string
    func getCondition(from weatherString: String?) -> String? {
        guard let weather = weatherString else { return nil }
        
        // Extract condition (everything before the temperature)
        if let tempRange = weather.range(of: " \\d+°", options: .regularExpression) {
            return String(weather[..<tempRange.lowerBound])
        }
        return weather
    }
}
