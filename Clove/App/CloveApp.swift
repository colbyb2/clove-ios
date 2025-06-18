//
//  CloveApp.swift
//  Clove
//
//  Created by Colby Brown on 6/17/25.
//

import SwiftUI

@main
struct CloveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
