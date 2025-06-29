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
   @State private var appState = AppState()
   
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
}
