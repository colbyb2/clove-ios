# To Do

## Features
Mark sub tasks as complete [X] when finished.

### CSV Export
Description: Allow users to export their data as a CSV file.
Sub-Tasks:
- Add export data button to Settings [X]
- Create a sheet that opens when export data is clicked that allows the user to choose which categories/symptoms to include in the csv file (or all). [X]
- Create a DataManager class. This should have the @Observable macro and should be a singleton. This class will contain the logic for exporting data. [X]
- Write the export function. Turn the data the user wants into the proper csv file. Allow them to export to files or wherever else is a valid destination. [X] 

### Weather Tracking
Description: Instead of using WeatherKit or any API, the user will select the current weather from list of choices (if they enable weather as a tracked feature).
- Add Weather field to UserSettings (if not already there) [X]
- Double check that DailyLog, LogData, and Migration schema accounts for weather. [X]
- Add a tracking option to the onboarding selection options. [X]
- Add a weather selection to the TodayView that allows the user to select that days weather. [X]

### Medication Tracking
Description: Allow users to track their regular medications with a simple daily checklist approach. Track medication history (started/stopped/dosage changes) automatically for insights and correlation analysis.

**Phase 1: Core Medication Tracking**
- Create TrackedMedication data model with id, name, dosage, instructions, isAsNeeded fields [X]
- Create MedicationHistoryEntry data model for tracking medication changes over time [X]
- Add database migration for TrackedMedication and MedicationHistoryEntry tables [X]
- Create MedicationRepository (@Observable singleton) for managing user's regular medications [X]
- Update DailyLog to store medication adherence data (which meds were actually taken) [X]
- Update LogData class to include medicationsTaken array matching DailyLog structure [X]

**Phase 2: Medication Setup & Management**
- Create MedicationSetupSheet for adding/editing regular medications [X]
- Design medication entry form with name, dosage, instructions, and as-needed toggle [X]
- Implement medication list management (add, edit, delete with confirmation) [X]
- Add medication setup access from Settings view [X]
- Create medication suggestion system for common medications [X]
- Implement medication search/autocomplete functionality [X]

**Phase 3: Daily Tracking Interface**
- Create a selector similar to Weather for medication in TodayView [X]
- When this is clicked, open a sheet like Weather where the user is displayed a list of their medications. [X]
- Don't use toggles, use a "Checklist" of sort as the UI showing medication name and dosage [X]
- Add medication section to TodayView (only show if trackMeds enabled) [X]
- Implement taken/not-taken state with visual feedback and haptic response [X]
- Add "Add one-time medication" option for occasional meds [X]
- Update TodayViewModel to handle medication adherence saving [X]

**Phase 4: Automatic History Tracking**
- Implement automatic history entry creation when medications are added/removed [X]
- Detect dosage changes and create history entries with before/after values [X]
- Add change detection logic to compare medication lists over time [X]
- Create medication timeline view for viewing history [X]
- Implement medication change notifications/prompts for user context [X]

**Phase 5: Integration & Polish**
- Update onboarding to include medication tracking option [ ]
- Add medication data to CSV export functionality [ ]
- Update DailyLogDetailView to show medications taken that day [ ]
- Ensure medication data persists correctly across app launches [ ]
- Add medication adherence percentage calculations [ ]
- Implement medication-related accessibility features [ ]

**Phase 6: Insights & Analytics (Future)**
- Add medication adherence tracking to InsightsView [ ]
- Implement correlation analysis between medication changes and symptom patterns [ ]
- Create medication timeline visualization [ ]
- Add adherence scoring and missed dose pattern detection [ ]
- Implement medication-symptom correlation insights [ ]

## Analysis

### Insights View

#### Current Implementation Analysis
The InsightsView currently displays:
- MoodGraphView: Line chart showing mood over time with CloveColors.primary
- PainEnergyGraphView: Dual-line chart comparing pain (red) vs energy (blue) with legends
- SymptomSummaryView: Dropdown selector + line chart for individual symptom tracking
- Basic flare-up count text display
- Simple vertical stacking with 24pt spacing

#### Potential Improvements & Features

**Data Insights & Analytics:**
- Weather correlation analysis: Show how weather patterns affect symptoms/mood/pain
- Average ratings display with trend indicators (↑↓↔)
- Weekly/monthly summaries with percentage changes
- Streak tracking: consecutive good/bad days, symptom-free periods
- Pattern detection: identify triggers, best/worst time periods
- Correlation heatmap between different metrics
- Statistical insights: mean, median, standard deviation for each metric
- Predictive indicators based on historical patterns

**Enhanced Visualizations:**
- Add area charts with gradients for mood/pain/energy trends
- Heatmap calendar view showing intensity of symptoms over months
- Circular progress rings for weekly/monthly averages
- Bar charts for symptom frequency analysis
- Scatter plots showing correlations between metrics
- Stacked bar charts for comparing multiple symptoms simultaneously
- Mini sparklines for quick metric overviews
- Weather emoji overlay on charts to show correlation

**UI/UX Enhancements:**
- Card-based layout with individual chart containers
- Animated chart loading with spring animations
- Interactive chart tooltips showing exact values on tap/hover
- Smooth transitions between different time periods (week/month/3months/year)
- Pull-to-refresh functionality
- Haptic feedback on chart interactions
- Loading states with skeleton screens
- Error states with retry buttons

**Time Period Controls:**
- Segmented control for time ranges (7D, 30D, 3M, 6M, 1Y, All)
- Date range picker for custom periods
- "Compare to previous period" functionality
- Month/week navigation arrows
- Today/This Week/This Month quick filters

**Interactive Features:**
- Tap chart points to see detailed day information
- Zoom and pan functionality for longer time periods
- Multi-select for comparing different symptoms
- Chart type toggle (line/area/bar) for user preference
- Export individual charts as images
- Share insights summary via social/messaging

**Smart Insights Panel:**
- Automated insights generation ("Your pain was 20% lower this week")
- Personalized recommendations based on patterns
- Achievement badges for positive trends
- Warning alerts for concerning patterns
- Weekly/monthly insight notifications

**Performance & Data:**
- Lazy loading for large datasets
- Chart virtualization for better performance
- Local caching of computed insights
- Background data processing
- Progressive data loading (show recent first)

**Accessibility Improvements:**
- VoiceOver support with detailed chart descriptions
- High contrast mode support
- Dynamic type support for all text
- Voice control navigation
- Alternative data representations for screen readers

**Advanced Analytics:**
- Machine learning trend predictions
- Seasonal pattern detection
- Custom alert thresholds
- Data export in multiple formats
- Integration with Apple Health trends
- Custom insight dashboard creation
