//
//  CloveApp.swift
//  Clove
//
//  Created by Colby Brown on 6/17/25.
//

import SwiftUI

@main
struct CloveApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState.phase {
                case .loading:
                    Text("Loading...")
                case .onboarding:
                    Text("Onboarding...")
                case .main:
                    MainTabView()
                    .environment(appState)
                }
            }
            .foregroundStyle(CloveColors.primaryText)
            .background(CloveColors.background)
            .toastable()
        }
    }

    init() {
        do {
            try DatabaseManager.shared.setupDatabase()
        } catch {
            print("Database setup failed: \(error)")
        }
    }
}
