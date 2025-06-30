# To Do

## Features
Mark sub tasks as complete [X] when finished.

### Medication Tracking
Description: Allow users to track their regular medications with a simple daily checklist approach. Track medication history (started/stopped/dosage changes) automatically for insights and correlation analysis.

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
