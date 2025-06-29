import SwiftUI
import CoreLocation

struct PostOnboardingLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var locationManager = LocationManager.shared
    @State private var hasRequestedPermission = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: CloveSpacing.large) {
                Spacer()
                
                // Icon and Title
                VStack(spacing: CloveSpacing.medium) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(CloveColors.accent)
                    
                    Text("Enable Weather Tracking?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)
                        .multilineTextAlignment(.center)
                }
                
                // Description
                VStack(spacing: CloveSpacing.medium) {
                    Text("Add weather context to your health logs automatically")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: CloveSpacing.small) {
                        LocationFeatureBullet(
                            icon: "thermometer.medium",
                            text: "Track temperature with your symptoms"
                        )
                        
                        LocationFeatureBullet(
                            icon: "cloud.rain.fill",
                            text: "See if weather affects your condition"
                        )
                        
                        LocationFeatureBullet(
                            icon: "lock.fill",
                            text: "Location data stays private"
                        )
                    }
                    .padding(.horizontal, CloveSpacing.medium)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: CloveSpacing.medium) {
                    // Enable Button
                    Button(action: {
                        requestLocationPermission()
                    }) {
                        HStack(spacing: CloveSpacing.small) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Enable Weather Tracking")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .fill(CloveColors.accent)
                        )
                    }
                    .disabled(locationManager.authorizationStatus == .authorizedWhenInUse || 
                             locationManager.authorizationStatus == .authorizedAlways)
                    
                    // Maybe Later Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    
                    // Status Text
                    if hasRequestedPermission {
                        LocationPermissionStatus(
                            authorizationStatus: locationManager.authorizationStatus,
                            onOpenSettings: {
                                locationManager.openLocationSettings()
                            }
                        )
                    }
                }
                .padding(.horizontal, CloveSpacing.large)
                .padding(.bottom, CloveSpacing.large)
            }
            .padding(CloveSpacing.medium)
            .navigationTitle("Weather Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Not Now") {
                        dismiss()
                    }
                    .foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if hasRequestedPermission && (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways) {
                // Auto-dismiss after successful permission
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    private func requestLocationPermission() {
        hasRequestedPermission = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        locationManager.requestLocationPermission()
    }
}

// MARK: - Supporting Components
struct LocationFeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CloveColors.accent)
                .frame(width: 20, alignment: .center)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CloveColors.primaryText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct LocationPermissionStatus: View {
    let authorizationStatus: CLAuthorizationStatus
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: CloveSpacing.small) {
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CloveColors.success)
                Text("Weather tracking enabled!")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CloveColors.success)
                
            case .denied, .restricted:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(CloveColors.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permission denied")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CloveColors.error)
                    
                    Button("Open Settings") {
                        onOpenSettings()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CloveColors.accent)
                }
                
            case .notDetermined:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Requesting permission...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
                
            @unknown default:
                EmptyView()
            }
        }
        .padding(.top, CloveSpacing.small)
    }
}

#Preview {
    PostOnboardingLocationView()
}