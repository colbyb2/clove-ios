//
//  CloveApp.swift
//  Clove
//
//  Created by Colby Brown on 6/17/25.
//

import SwiftUI
import CoreLocation

@main
struct CloveApp: App {
   @AppStorage(Constants.ONBOARDING_FLAG) var onboardingCompleted: Bool = false
   @AppStorage("locationPermissionRequested") var locationPermissionRequested: Bool = false
   @State private var appState = AppState()
   @State private var showLocationPrompt = false
   
   var body: some Scene {
      WindowGroup {
         ZStack {
            CloveColors.background
               .ignoresSafeArea()
            
            switch appState.phase {
            case .loading:
               Text("Loading...")
            case .onboarding:
               OnboardingView()
                  .environment(appState)
            case .main:
               MainTabView()
                  .environment(appState)
            }
         }
         .foregroundStyle(CloveColors.primaryText)
         .toastable()
         .sheet(isPresented: $showLocationPrompt) {
            PostOnboardingLocationView()
         }
         .onAppear {
            checkLocationPermissionNeeded()
         }
      }
   }
   
   init() {
      do {
         try DatabaseManager.shared.setupDatabase()
      } catch {
         print("Database setup failed: \(error)")
      }
      
      if !onboardingCompleted {
         appState.phase = .onboarding
      } else {
         appState.phase = .main
      }
   }
   
   private func checkLocationPermissionNeeded() {
      // Only show location prompt if:
      // 1. Onboarding is completed
      // 2. We haven't asked for location permission before
      // 3. User has weather tracking enabled
      // 4. Location permission is still not determined or denied
      guard onboardingCompleted,
            !locationPermissionRequested,
            appState.phase == .main else { return }
      
      // Check if user has weather tracking enabled
      if let settings = UserSettingsRepo.shared.getSettings(),
         settings.trackWeather,
         LocationManager.shouldRequestLocationPermission() {
         
         // Delay showing the prompt to avoid overwhelming user at launch
         DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showLocationPrompt = true
            locationPermissionRequested = true
         }
      }
   }
}
