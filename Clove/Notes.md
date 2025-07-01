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

## Insights Revamp Plan

### Overview
Transform the InsightsView from a basic chart display into a comprehensive analytics dashboard that empowers users to explore their health data through advanced visualizations, cross-reference analysis, and intelligent insights generation.

### Core Features Implementation

#### 1. **Universal Chart System**
**Goal**: Allow users to chart any trackable metric over customizable time periods

**Data Categories to Chart:**
- **Core Health Metrics**: Mood (1-10), Pain Level (1-10), Energy Level (1-10)
- **Symptoms**: All tracked symptoms with their ratings (1-10)
- **Medications**: Adherence rates, missed doses, medication counts
- **Lifestyle**: Activity frequency, meal patterns, sleep patterns (if added)
- **Environmental**: Weather correlation, flare day frequency
- **Aggregate Metrics**: Weekly/monthly averages, trend indicators

**Chart Types:**
- **Line Charts**: Default for continuous data (mood, pain, energy, symptoms)
- **Bar Charts**: For frequency data (medication adherence, activities, meals)
- **Area Charts**: For trend visualization with gradient fills
- **Heatmap Calendar**: Monthly view showing intensity patterns
- **Scatter Plots**: For correlation analysis

#### 2. **Cross-Reference Analysis**
**Goal**: Overlay any two metrics to identify correlations and patterns

**Features:**
- **Dual-Axis Charts**: Different scales for different metric types
- **Correlation Coefficient Display**: Calculate and show Pearson correlation (-1 to 1)
- **Pattern Highlighting**: Automatically highlight periods where both metrics trend together
- **Smart Suggestions**: Recommend interesting correlations based on user data
- **Saved Comparisons**: Allow users to bookmark useful metric combinations

**Example Correlations:**
- Pain Level vs Weather
- Medication Adherence vs Mood
- Activity Level vs Energy
- Symptom Severity vs Sleep Quality
- Flare Days vs Stress Levels

#### 3. **Time Period Management**
**UI Design**: Segmented control with custom range picker

**Predefined Periods:**
- 7 Days (detailed daily view)
- 30 Days (daily points)
- 3 Months (weekly averages)
- 6 Months (weekly averages)
- 1 Year (monthly averages)
- All Time (adaptive aggregation)

**Advanced Time Controls:**
- **Compare Mode**: "vs Previous Period" toggle
- **Custom Range**: Date picker for specific periods
- **Quick Filters**: "This Week", "Last Month", "Last Flare Period"
- **Zoom & Pan**: Interactive timeline navigation for large datasets

#### 4. **Smart Insights Engine**
**Goal**: Generate actionable insights automatically using pattern recognition

**Basic Analytics (Phase 1):**
- **Trend Analysis**: Calculate week-over-week, month-over-month changes
- **Streak Detection**: Identify consecutive good/bad days
- **Average Calculations**: Mean, median, mode for all metrics
- **Pattern Recognition**: Daily/weekly patterns, peak times
- **Threshold Alerts**: Configurable warnings for concerning trends

**Advanced Analytics (Phase 2 - ML Integration):**
- **Correlation Discovery**: Automatically find significant correlations
- **Seasonal Pattern Detection**: Identify weather/time-based patterns
- **Predictive Modeling**: Simple linear regression for trend forecasting
- **Anomaly Detection**: Flag unusual patterns or outliers
- **Personalized Recommendations**: Based on successful pattern identification

**Insight Categories:**
- **Achievements**: "7-day pain reduction streak!", "Best mood week this month!"
- **Correlations**: "Pain is 23% lower on sunny days", "Medication adherence improves mood by 15%"
- **Trends**: "Energy levels have improved 12% this month", "Flare frequency down 40%"
- **Recommendations**: "Consider tracking sleep - users with similar patterns benefit"
- **Warnings**: "Pain trending upward for 5 days", "Medication adherence below average"

### UI/UX Design Specification

#### 1. **Navigation & Layout**
**Header Section:**
- **Title**: "Health Insights" with data range indicator
- **Time Selector**: Prominent segmented control (7D, 30D, 3M, 6M, 1Y, All)
- **Filter Button**: Access to advanced filters and settings
- **Export Button**: Share insights or export data

**Tab Structure:**
- **Overview**: Dashboard with key insights and summary charts
- **Charts**: Individual metric visualization with detailed controls
- **Correlations**: Cross-reference analysis workspace
- **Trends**: Long-term pattern analysis and predictions

#### 2. **Overview Tab Design**
**Smart Insights Card**: Top priority
- **Gradient background** with CloveColors.accent
- **Rotating insights** with smooth animations
- **Achievement badges** for positive trends
- **Quick action buttons** for "Learn More" or "View Chart"

**Key Metrics Grid**: 2x2 layout
- **Mood Average**: Large number with trend arrow
- **Pain Reduction**: Percentage change with color coding
- **Energy Trend**: Sparkline with current level
- **Flare Frequency**: Count with comparison period

**Mini Chart Preview**: Horizontal scroll
- **Mood Over Time**: Small line chart
- **Recent Correlations**: Top 2-3 significant findings
- **Quick Insights**: Bite-sized observations

#### 3. **Charts Tab Design**
**Metric Selector**:
- **Grouped picker**: Core Health | Symptoms | Medications | Lifestyle
- **Search functionality** for quick metric finding
- **Recently viewed** metrics at top

**Chart Display**:
- **Full-screen chart** with CloveCorners.medium rounding
- **Interactive tooltips** showing exact values on tap
- **Zoom controls** for detailed examination
- **Chart type toggle**: Line/Area/Bar based on data type

**Chart Controls Panel**:
- **Time period selector** (synchronized with app-wide setting)
- **Chart customization**: Colors, line width, smoothing
- **Data options**: Show/hide gaps, interpolation method
- **Export options**: Save as image, share data

#### 4. **Correlations Tab Design**
**Metric Selection Interface**:
- **Two-column layout**: "Primary Metric" vs "Compare With"
- **Visual metric cards** with icons and recent values
- **Suggested combinations** based on user data and common patterns
- **Correlation strength indicator** (weak/moderate/strong)

**Correlation Display**:
- **Dual-axis chart** with different colors for each metric
- **Correlation coefficient** prominently displayed with interpretation
- **Pattern highlights**: Shaded regions where metrics align
- **Statistical summary**: R², p-value for significance testing

**Saved Correlations**:
- **Bookmark functionality** for interesting findings
- **Quick access grid** showing thumbnails of saved correlations
- **Share correlations** with healthcare providers

#### 5. **Trends Tab Design**
**Trend Categories**:
- **Short-term** (7-30 days): Daily pattern identification
- **Medium-term** (1-6 months): Weekly/monthly cycle detection
- **Long-term** (6+ months): Seasonal patterns and major trends

**Predictive Analysis**:
- **Trend projection**: Simple linear forecasting with confidence intervals
- **Pattern-based predictions**: "Based on similar periods..."
- **Goal tracking**: Set targets and track progress
- **Intervention recommendations**: Suggest actions based on patterns

### Technical Implementation Strategy

#### Phase 1: Foundation (Week 1-2)
1. **Create ChartDataManager**: Centralized data processing for all chart types
2. **Build Universal Chart Component**: Reusable chart view supporting all metric types
3. **Implement Time Period Management**: Global time state with persistence
4. **Create Metric Selector Interface**: Unified way to choose any trackable metric

#### Phase 2: Core Features (Week 3-4)
1. **Implement Cross-Reference System**: Dual metric charting with correlation calculation
2. **Build Insights Engine Foundation**: Basic statistical analysis (averages, trends, streaks)
3. **Create Overview Dashboard**: Key metrics summary with mini charts
4. **Add Interactive Features**: Tooltips, zoom, tap gestures

#### Phase 3: Advanced Analytics (Week 5-6)
1. **Implement ML Correlation Discovery**: Automatic pattern recognition
2. **Add Predictive Modeling**: Simple forecasting algorithms
3. **Create Smart Insights Generation**: Automated insight text generation
4. **Build Recommendation Engine**: Personalized suggestions based on patterns

#### Phase 4: Polish & Performance (Week 7)
1. **Optimize Chart Performance**: Lazy loading, data virtualization
2. **Add Export/Sharing**: Chart images, data export, insights sharing
3. **Implement Accessibility**: VoiceOver support, alternative data views
4. **Performance Testing**: Large dataset handling, memory optimization

### Data Architecture

#### Analytics Data Models
```swift
struct ChartDataPoint {
    let date: Date
    let value: Double
    let metricType: MetricType
    let category: MetricCategory
}

struct CorrelationAnalysis {
    let primaryMetric: MetricType
    let secondaryMetric: MetricType
    let coefficient: Double
    let significance: Double
    let dataPoints: [(Date, Double, Double)]
}

struct HealthInsight {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let relevancePeriod: DateInterval
    let actionable: Bool
}
```

#### Machine Learning Integration
- **Linear Regression**: For trend forecasting
- **Correlation Analysis**: Pearson/Spearman correlation calculation
- **Clustering**: Identify similar patterns in user behavior
- **Anomaly Detection**: Statistical outlier identification
- **Pattern Recognition**: Recurring cycle detection

### Success Metrics
- **User Engagement**: Time spent in Insights tab, feature usage rates
- **Insight Accuracy**: User feedback on generated insights
- **Correlation Discovery**: Number of meaningful correlations found
- **Predictive Accuracy**: Forecast vs actual outcome comparison
- **User Satisfaction**: App store reviews mentioning insights functionality
