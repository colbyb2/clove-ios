import Foundation
import CoreLocation
import SwiftUI

@Observable
class LocationManager: NSObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var locationError: String?
    var isLocationEnabled: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced // Use reduced accuracy for privacy
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Permission was denied, user needs to go to settings
            locationError = "Location access was denied. Enable it in Settings to use weather tracking."
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized, request location
            requestCurrentLocation()
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
    
    func requestCurrentLocation() {
        guard isLocationEnabled else {
            locationError = "Location permission not granted"
            return
        }
        
        locationManager.requestLocation()
    }
    
    func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Permission Status Check
    
    static func hasLocationPermission() -> Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    static func shouldRequestLocationPermission() -> Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .notDetermined
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationError = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to get location: \(error.localizedDescription)"
        currentLocation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationError = nil
                // Don't automatically request location here, let the weather service handle it
            case .denied, .restricted:
                self.locationError = "Location access denied"
                self.currentLocation = nil
            case .notDetermined:
                self.locationError = nil
            @unknown default:
                self.locationError = "Unknown authorization status"
            }
        }
    }
}