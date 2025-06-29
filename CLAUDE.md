# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clove is a SwiftUI-based iOS health tracking application that helps users monitor symptoms, mood, pain levels, energy, and other health metrics. The app uses GRDB (SQLite) for local data persistence.

## Build & Development Commands

### Build Commands
```bash
# Build the project (Xcode required)
xcodebuild -project Clove.xcodeproj -scheme Clove build

# Build and run in simulator
xcodebuild -project Clove.xcodeproj -scheme Clove -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' build

# Open in Xcode
open Clove.xcodeproj
```

### Testing
- No automated test suite currently exists
- Testing is done through Xcode's built-in simulator and device testing

## Architecture

### App Structure
- **Entry Point**: `CloveApp.swift` - Main app with database initialization and app state management
- **App State**: `AppState.swift` - Observable class managing app launch phases (loading, onboarding, main)
- **Navigation**: `MainTabView.swift` - Tab-based navigation with 4 main sections:
  - Today: Daily symptom/mood logging
  - Insights: Data visualization and analytics
  - History: Calendar view of past logs
  - Settings: App customization

### Database Layer (GRDB + SQLite)
- **DatabaseManager**: Singleton providing centralized database access with read/write methods
- **Models**: Conform to `Codable`, `FetchableRecord`, `PersistableRecord`
  - `DailyLog`: Main log entry with mood, pain, energy, symptoms, notes
  - `TrackedSymptom`: User-configured symptoms to track
  - `UserSettings`: App configuration and feature toggles
- **Repositories**: Data access layer (LogsRepo, SymptomsRepo, UserSettingsRepo)
- **Migrations**: Version-controlled schema changes in `Migrations.swift`

### Architecture Patterns
- **MVVM**: ViewModels (Observable classes) handle business logic and state
- **Repository Pattern**: Repos abstract database operations
- **Singleton Pattern**: DatabaseManager, various repos use shared instances
- **Environment Objects**: AppState injected through SwiftUI environment

### Key Components
- **Theming**: Centralized colors, fonts, spacing in `Theme.swift`
- **Toast System**: Global toast notifications via `ToastManager`
- **Onboarding Flow**: Multi-step user setup process
- **Symptom Rating System**: Custom symptom tracking with JSON serialization

### Data Flow
1. Views → ViewModels (user interactions)
2. ViewModels → Repositories (business logic)
3. Repositories → DatabaseManager (data persistence)
4. Models handle serialization/deserialization

### File Organization
```
Clove/
├── App/                    # App lifecycle and navigation
├── Models/                 # Data models (GRDB entities)
├── ViewModels/            # Observable business logic classes
├── Views/                 # SwiftUI views organized by feature
├── Repos/                 # Data access layer
├── Persistence/           # Database setup and migrations
├── Resources/             # Constants, theme, extensions
└── Services/              # External services (currently empty)
```

## Dependencies

- **GRDB.swift**: SQLite database framework (via Swift Package Manager)
- **SwiftUI**: UI framework
- **Foundation**: Core iOS frameworks

## Development Notes

### Database Operations
- Always use DatabaseManager.shared for database access
- Wrap operations in `try dbManager.read{}` or `try dbManager.write{}`
- Add new migrations to `Migrations.all` array
- Use repository pattern rather than direct database calls in ViewModels

### State Management
- ViewModels use `@Observable` macro (iOS 17+)
- Environment injection for shared state (AppState)
- UserDefaults for simple app flags (onboarding completion)

### UI Patterns
- Custom theming system with CloveColors, CloveFonts, CloveSpacing
- Toast notifications for user feedback
- SwiftUI NavigationStack for navigation within tabs
- Custom UI components in Views/Shared/

### Data Serialization
- JSON encoding for complex data (symptom ratings in DailyLog)
- String arrays for simple lists (meals, activities, medications)
- Date handling for daily logs with proper timezone support
