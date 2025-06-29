import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    @Environment(OnboardingViewModel.self) var viewModel
    @State private var locationManager = LocationManager.shared
    @State private var showLocationAlert = false
    @State private var hasRequestedPermission = false
    
    var body: some View {
        VStack(spacing: CloveSpacing.large) {
            Spacer()
            
            // Icon and Title
            VStack(spacing: CloveSpacing.medium) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(CloveColors.accent)
                
                Text("Enable Weather Tracking")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Description
            VStack(spacing: CloveSpacing.medium) {
                Text("Get automatic weather context for your health logs")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(CloveColors.primaryText)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: CloveSpacing.small) {
                    FeatureBulletPoint(
                        icon: "cloud.sun.fill",
                        text: "Automatic weather data when you save logs",
                        color: CloveColors.accent
                    )
                    
                    FeatureBulletPoint(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Track correlations between weather and symptoms",
                        color: CloveColors.accent
                    )
                    
                    FeatureBulletPoint(
                        icon: "lock.shield.fill",
                        text: "Your location stays private and secure",
                        color: CloveColors.success
                    )
                }
                .padding(.horizontal, CloveSpacing.medium)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: CloveSpacing.medium) {
                // Enable Location Button
                Button(action: {
                    requestLocationPermission()
                }) {
                    HStack(spacing: CloveSpacing.small) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Enable Weather Tracking")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .fill(CloveColors.accent)
                    )
                }
                .disabled(locationManager.authorizationStatus == .authorizedWhenInUse || 
                         locationManager.authorizationStatus == .authorizedAlways)
                .accessibilityLabel("Enable weather tracking")
                .accessibilityHint("Requests location permission for automatic weather data")
                
                // Skip Button
                Button(action: {
                    skipLocationPermission()
                }) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .accessibilityLabel("Skip weather tracking")
                .accessibilityHint("Continue without location permission")
                
                // Status Text
                if hasRequestedPermission {
                    HStack(spacing: CloveSpacing.small) {
                        switch locationManager.authorizationStatus {
                        case .authorizedWhenInUse, .authorizedAlways:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CloveColors.success)
                            Text("Location permission granted!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CloveColors.success)
                            
                        case .denied, .restricted:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(CloveColors.error)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Permission denied")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CloveColors.error)
                                
                                Button("Open Settings") {
                                    locationManager.openLocationSettings()
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(CloveColors.accent)
                            }
                            
                        case .notDetermined:
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Waiting for permission...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CloveColors.secondaryText)
                            
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.top, CloveSpacing.small)
                }
            }
            .padding(.horizontal, CloveSpacing.large)
            .padding(.bottom, CloveSpacing.large)
        }
        .padding(CloveSpacing.medium)
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if hasRequestedPermission && (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways) {
                // Auto-advance after successful permission
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    viewModel.nextStep()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestLocationPermission() {
        hasRequestedPermission = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        locationManager.requestLocationPermission()
    }
    
    private func skipLocationPermission() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        viewModel.nextStep()
    }
}

// MARK: - Feature Bullet Point Component
struct FeatureBulletPoint: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24, alignment: .center)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CloveColors.primaryText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

#Preview {
    LocationPermissionView()
        .environment(OnboardingViewModel())
}