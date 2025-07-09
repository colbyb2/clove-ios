# 🍀 Clove Health Tracker

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)
![GRDB](https://img.shields.io/badge/GRDB-6.0+-purple.svg)
![License](https://img.shields.io/badge/License-CCANC4.0-brightgreen.svg)

Clove is a comprehensive, privacy-focused iOS health tracking application built with SwiftUI that empowers users to monitor their symptoms, mood, pain levels, energy, medications, activities, and other health metrics. With its intuitive interface and powerful analytics, Clove helps users understand patterns in their health data and make informed decisions about their wellbeing.

## 📱 Features

### 🏠 Core Functionality
- **Daily Health Logging**: Track mood, pain, energy levels, and symptoms with customizable rating scales
- **Symptom Management**: Create and monitor custom symptoms with severity tracking
- **Medication Tracking**: Log medication adherence with detailed medication management
- **Activity & Lifestyle**: Record daily activities, meals, and weather conditions
- **Notes Integration**: Add contextual notes to daily logs for detailed record-keeping
- **Flare Day Tracking**: Mark and monitor flare-up days for chronic condition management

### 📊 Advanced Analytics & Insights
- **Smart Insights Engine**: AI-powered insights that identify patterns and trends in your health data
- **Correlation Analysis**: Discover relationships between different health metrics (e.g., weather vs. pain levels)
- **Interactive Charts**: Beautiful, responsive charts with multiple visualization types:
  - Line charts for trends over time
  - Bar charts for binary data (medication taken/not taken)
  - Area charts for cumulative data
- **Metric Explorer**: Deep-dive analysis tool for individual metrics with filtering and time period selection
- **Cross-Reference Analysis**: Compare multiple metrics simultaneously to identify correlations
- **Statistical Analysis**: Comprehensive statistics including mean, median, trends, and significance testing

### 🎨 Customization & Personalization
- **Custom Color Themes**: Choose from preset themes or create custom color schemes during onboarding
- **Configurable Tracking**: Enable/disable specific tracking modules based on your needs
- **Input Method Preferences**: Choose between slider inputs or plus/minus buttons for ratings
- **Personalized Dashboard**: Customize your insights dashboard with relevant widgets
- **Flexible Symptom Setup**: Create unlimited custom symptoms with personalized tracking

### 📅 Data Management & History
- **Calendar View**: Navigate through historical data with an intuitive calendar interface
- **Data Export**: Export your health data in multiple formats for sharing with healthcare providers
- **Offline-First**: All data stored locally with SQLite for privacy and reliability
- **Data Migration**: Automatic database schema migrations for seamless app updates
- **Backup & Restore**: Comprehensive data backup and restoration capabilities

### 🔐 Privacy & Security
- **Local Data Storage**: All health data stays on your device - no cloud storage or data sharing
- **No User Accounts**: No registration, login, or personal information required
- **HIPAA-Conscious Design**: Built with healthcare privacy best practices in mind
- **Secure Database**: Encrypted local SQLite database with GRDB framework

## 🛠 Technical Architecture

### Core Technologies
- **Framework**: SwiftUI with iOS 17+ features
- **Database**: GRDB.swift (SQLite wrapper) for robust data persistence
- **Charts**: Swift Charts framework for native chart rendering
- **Architecture**: MVVM pattern with Observable objects
- **Dependency Management**: Swift Package Manager

### Project Structure
```
Clove/
├── App/                    # App lifecycle and navigation
│   ├── AppState.swift      # Global app state management
│   ├── CloveApp.swift      # Main app entry point
│   └── MainTabView.swift   # Tab-based navigation
├── Models/                 # Data models and entities
│   ├── DailyLog.swift      # Core daily log model
│   ├── TrackedSymptom.swift# Custom symptom definitions
│   ├── UserSettings.swift  # User preferences
│   └── ...
├── ViewModels/            # Observable business logic classes
│   ├── TodayViewModel.swift# Today view logic
│   ├── InsightsViewModel.swift # Analytics logic
│   └── ...
├── Views/                 # SwiftUI views organized by feature
│   ├── Today/             # Daily logging interface
│   ├── Insights/          # Analytics and charts
│   ├── Calendar/          # Historical data view
│   ├── Settings/          # App configuration
│   ├── Onboarding/        # First-time setup flow
│   └── Shared/            # Reusable UI components
├── Services/              # Business logic and data processing
│   ├── ChartDataManager.swift # Chart data processing
│   ├── InsightsEngine.swift   # Analytics algorithms
│   └── ThemeManager.swift     # Color theme management
├── Repos/                 # Data access layer
│   ├── LogsRepo.swift     # Daily log operations
│   ├── SymptomsRepo.swift # Symptom management
│   └── UserSettingsRepo.swift # Settings persistence
├── Persistence/           # Database layer
│   ├── DatabaseManager.swift  # GRDB database manager
│   └── Migrations.swift       # Schema migrations
└── Resources/             # Constants, themes, extensions
    ├── Theme.swift        # UI theming system
    ├── Constants.swift    # App constants
    └── Extensions.swift   # Swift extensions
```

### Design Patterns
- **MVVM (Model-View-ViewModel)**: Clean separation of concerns with Observable ViewModels
- **Repository Pattern**: Abstracted data access layer for easy testing and maintenance
- **Singleton Pattern**: Shared instances for database and service managers
- **Observer Pattern**: SwiftUI's reactive updates with @Observable macro

### Database Schema
```sql
-- Core Tables
DailyLog              # Primary health log entries
TrackedSymptom        # User-defined symptoms
UserSettings          # App configuration
MedicationAdherence   # Medication tracking
MedicationHistoryEntry # Medication timeline

-- Key Features
- Automatic migrations with version control
- Foreign key constraints for data integrity
- Indexed columns for performance optimization
- JSON columns for flexible data storage
```

## 🚀 Getting Started

### Prerequisites
- macOS 14.0+ (for development)
- Xcode 15.0+
- iOS 17.0+ (for target devices)
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/colbyb2/clove-ios.git
   cd clove-ios
   ```

2. **Open in Xcode**
   ```bash
   open Clove.xcodeproj
   ```

3. **Install Dependencies**
   Dependencies are managed via Swift Package Manager and will be automatically resolved when opening the project.

4. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd+R` or click the play button to build and run

## 🎯 Usage Guide

### First-Time Setup
1. **Welcome & Onboarding**: Interactive setup wizard guides you through initial configuration
2. **Feature Selection**: Choose which health metrics you want to track
3. **Symptom Setup**: Add custom symptoms relevant to your health conditions
4. **Theme Selection**: Choose from preset color themes or create a custom theme
5. **Ready to Track**: Start logging your daily health data

### Daily Logging Workflow
1. **Open Today Tab**: Access the main logging interface
2. **Rate Your Metrics**: Use sliders or buttons to rate mood, pain, and energy
3. **Track Symptoms**: Log severity for your custom symptoms
4. **Record Activities**: Add meals, activities, and medications taken
5. **Add Context**: Include notes about your day or any relevant details
6. **Save Entry**: Data is automatically saved locally

### Analytics & Insights
1. **Explore Insights Tab**: View your health data analytics
2. **Metric Explorer**: Deep-dive into specific metrics with interactive charts
3. **Correlation Analysis**: Discover relationships between different health factors
4. **Time Period Analysis**: Compare data across different time periods
5. **Export Data**: Share insights with healthcare providers

### Customization Options
- **Tracking Modules**: Enable/disable specific health metrics
- **Input Methods**: Choose between sliders or button inputs
- **Color Themes**: Personalize app appearance
- **Dashboard Widgets**: Customize insights dashboard layout
- **Data Export**: Configure export formats and schedules

## 📊 Data Analytics Features

### Correlation Analysis
- **Pearson Correlation**: Statistical correlation coefficient calculation
- **Significance Testing**: P-value calculation for statistical significance
- **Visual Correlation**: Dual-axis charts showing relationship strength
- **Insight Generation**: AI-powered insights based on correlation patterns

### Chart Types & Visualizations
- **Line Charts**: Trend analysis over time with smooth interpolation
- **Bar Charts**: Binary data visualization (taken/not taken, yes/no)
- **Area Charts**: Cumulative data with gradient fills
- **Scatter Plots**: Correlation visualization between two metrics
- **Statistical Overlays**: Mean lines, confidence intervals, trend indicators

### Advanced Analytics
- **Trend Detection**: Automatic identification of increasing/decreasing patterns
- **Outlier Detection**: Identification of unusual data points
- **Seasonal Analysis**: Recognition of cyclical patterns
- **Predictive Insights**: Trend-based future projections
- **Statistical Summaries**: Comprehensive statistical breakdowns

## 🎨 Design System

### Color System
```swift
// Primary Colors
CloveColors.primaryText    # Main text color
CloveColors.secondaryText  # Secondary text color
CloveColors.background     # App background
CloveColors.card          # Card backgrounds

// Accent Colors
Theme.shared.accent       # User-customizable accent color
CloveColors.success       # Success states
CloveColors.error         # Error states
CloveColors.warning       # Warning states

// Semantic Colors
CloveColors.blue          # Information
CloveColors.green         # Positive trends
CloveColors.red           # Negative trends
CloveColors.orange        # Neutral highlights
```

## 🔧 Configuration

### User Settings
```swift
// Tracking Configuration
trackMood: Bool           # Enable mood tracking
trackPain: Bool           # Enable pain tracking
trackEnergy: Bool         # Enable energy tracking
trackSymptoms: Bool       # Enable symptom tracking
trackMeals: Bool          # Enable meal tracking
trackActivities: Bool     # Enable activity tracking
trackMeds: Bool           # Enable medication tracking
trackWeather: Bool        # Enable weather tracking
trackNotes: Bool          # Enable notes

// Input Preferences
useSliderInput: Bool      # Slider vs button input preference

// Theme Settings
selectedColor: String     # Custom theme color
```

### Constants Configuration
```swift
// App Storage Keys
ONBOARDING_FLAG          # Onboarding completion status
USE_SLIDER_INPUT         # Input method preference
SELECTED_COLOR           # Theme color selection
INSIGHTS_*               # Insights customization flags
```

## 🔄 Data Flow

### Input Flow
```
User Input → ViewModel → Repository → DatabaseManager → SQLite
```

### Display Flow
```
SQLite → DatabaseManager → Repository → ViewModel → SwiftUI View
```

### Analytics Flow
```
Raw Data → ChartDataManager → Statistical Processing → InsightsEngine → Visualization
```

## 🧪 Testing Strategy

### Current Testing Approach
- **Manual Testing**: Comprehensive manual testing through Xcode simulator
- **Device Testing**: Real device testing across different iOS versions
- **Data Integrity**: Database migration testing and data validation

## 📦 Dependencies

### Swift Package Manager Dependencies
```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
]
```

### Core Dependencies
- **GRDB.swift**: SQLite database framework with Swift integration
- **SwiftUI**: Native iOS UI framework
- **Swift Charts**: Native charting framework
- **Foundation**: Core iOS system frameworks
- **UIKit**: Additional UI components and utilities

## 🔐 Privacy & Security

### Data Privacy Principles
- **Local-First**: All health data stored exclusively on device
- **No Cloud Sync**: No remote data transmission or storage
- **No Analytics**: No usage analytics or telemetry
- **No Ads**: No advertising or tracking technologies

## 🌍 Accessibility

### Accessibility Features
- **VoiceOver Support**: Full screen reader compatibility
- **Dynamic Type**: Automatic text scaling support
- **Color Contrast**: WCAG-compliant color contrast ratios
- **Haptic Feedback**: Tactile feedback for interactions
- **Keyboard Navigation**: Full keyboard accessibility

### Inclusive Design
- **Multiple Input Methods**: Slider and button input options
- **Customizable Interface**: Adjustable colors and themes
- **Clear Navigation**: Intuitive navigation patterns
- **Error Prevention**: Clear validation and error messages

## 🤝 Contributing

### Development Guidelines
1. **Code Style**: Follow Swift API Design Guidelines
2. **Architecture**: Maintain MVVM pattern consistency
3. **Testing**: Include tests for new features
4. **Documentation**: Update documentation for API changes
5. **Privacy**: Maintain local-first data principles

### Contribution Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Review Criteria
- **Functionality**: Feature works as intended
- **Performance**: No significant performance regression
- **Privacy**: Maintains data privacy principles
- **Accessibility**: Supports accessibility features
- **Documentation**: Includes appropriate documentation

## 📄 License

This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International Public License - see the [LICENSE](LICENSE) file for details.

## 👥 Acknowledgments

- **GRDB.swift Team**: Excellent SQLite integration framework
- **Apple**: SwiftUI and Swift Charts frameworks
- **Healthcare Community**: Inspiration for privacy-focused health tracking
- **Open Source Contributors**: Various Swift and iOS development tools
- **Claude Code**: Speed up boilerplate

## 📞 Support

### Getting Help
- **Documentation**: Check this README and inline code documentation
- **Issues**: Create GitHub issues for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions and ideas

### Reporting Issues
When reporting issues, please include:
- iOS version and device model
- App version and build number
- Steps to reproduce the issue
- Expected vs actual behavior
- Screenshots if applicable

---

**Built with ❤️ for the illness community**

*Clove empowers individuals to take control of their health data with privacy, insights, and beautiful design.*
