# Adding Metrics to Clove iOS

This guide provides comprehensive instructions for adding new metrics to the Clove iOS health tracking application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Metric System Components](#metric-system-components)
3. [Adding a New Metric: Step-by-Step](#adding-a-new-metric-step-by-step)
4. [Code Examples](#code-examples)
5. [Best Practices](#best-practices)
6. [Testing Your Metric](#testing-your-metric)

---

## Architecture Overview

The Clove metrics system is built on a **provider-based architecture** that separates data access, processing, and visualization. This design enables:

- **Flexible data sources**: Metrics can pull from any data source (session logs, repositories, external APIs)
- **Consistent API**: All metrics implement the same `MetricProvider` protocol
- **Automatic registration**: Metrics are automatically discovered and registered
- **Efficient caching**: The `MetricRegistry` handles caching and invalidation
- **Type-safe data handling**: Strong typing for different metric data types

### Key Components

```
┌─────────────────────────────────────────────────────────────┐
│                      MetricRegistry                          │
│  (Central registry managing all metrics + caching)          │
└───────────────────────┬─────────────────────────────────────┘
                        │
            ┌───────────┴───────────┐
            │                       │
┌───────────▼─────────┐  ┌─────────▼──────────┐
│  Static Metrics     │  │  Dynamic Metrics    │
│  (CoreHealthMetrics)│  │  (Generated metrics)│
└───────────┬─────────┘  └─────────┬──────────┘
            │                       │
            └───────────┬───────────┘
                        │
            ┌───────────▼────────────┐
            │   MetricProvider       │
            │   (Protocol)           │
            └───────────┬────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐
│ getDataPoints│ │ formatValue│ │ chartConfig│
└──────────────┘ └────────────┘ └────────────┘
```

---

## Metric System Components

### 1. MetricProvider Protocol

The core protocol that all metrics must implement. Located in `Clove/Metrics/Core/MetricProvider.swift`.

**Required properties:**
- `id`: Unique identifier (e.g., "mood", "symptom_fatigue")
- `displayName`: Human-readable name shown in UI
- `description`: Detailed description of what the metric tracks
- `icon`: Emoji or SF Symbol for visual identification
- `category`: Classification (coreHealth, symptoms, medications, etc.)
- `dataType`: Type of data (continuous, binary, categorical, count, percentage)
- `chartType`: Preferred visualization (line, bar, area, scatter)
- `valueRange`: Optional valid range for the metric values

**Required methods:**
- `getDataPoints(for:)`: Fetch raw data points for a time period
- `getDataPointCount(for:)`: Count available data points
- `formatValue(_:)`: Format numeric values for display

**Optional methods with defaults:**
- `getLastValue()`: Get most recent value
- `getSmoothedData(for:)`: Get processed/smoothed data
- `getAggregatedDataPoints(for:maxPoints:)`: Get aggregated data for efficient charting
- `chartConfiguration`: Custom chart styling

### 2. MetricDataType Enum

Defines the type of data your metric represents. Located in `Clove/Metrics/Core/MetricDataTypes.swift`.

```swift
enum MetricDataType: Sendable, Equatable {
    case continuous(range: ClosedRange<Double>)  // 1-10 scale
    case binary                                  // 0/1, yes/no
    case categorical(values: [String])           // weather types, etc.
    case count                                   // number of items
    case percentage                              // 0-100%
    case custom                                  // completely custom handling
}
```

### 3. MetricCategory Enum

Categories organize metrics in the UI. Located in `Clove/Services/ChartDataManager.swift`.

Available categories:
- `coreHealth`: Fundamental health metrics (mood, pain, energy)
- `symptoms`: Symptom tracking
- `medications`: Medication adherence and tracking
- `lifestyle`: Lifestyle factors
- `environmental`: Weather and environmental conditions
- `activities`: Physical activities
- `meals`: Food and meal tracking

### 4. MetricRegistry

The central registry manages metric discovery, caching, and access. Located in `Clove/Metrics/Core/MetricRegistry.swift`.

**Static metrics** are defined in the `staticMetrics` array.
**Dynamic metrics** are generated based on user data (e.g., per-symptom or per-medication metrics).

---

## Adding a New Metric: Step-by-Step

### Step 1: Determine Metric Type

First, decide if your metric is:

**Static Metric**: Always available, tracks a fixed concept (e.g., mood, pain level)
- Add to `CoreHealthMetrics.swift`
- Register in `MetricRegistry.staticMetrics`

**Dynamic Metric**: Generated based on user data (e.g., per-symptom, per-food)
- Create a new provider struct in `DynamicMetrics.swift`
- Add generation logic to `MetricRegistry`

### Step 2: Choose the Data Type

Select the appropriate `MetricDataType`:
- **Continuous**: Ratings on a scale (1-10 mood, pain levels)
- **Binary**: Yes/No tracking (flare day, medication taken)
- **Categorical**: Named categories (weather types, symptom severity labels)
- **Count**: Numeric counts (number of activities, meals per day)
- **Percentage**: 0-100% values (medication adherence rate)

### Step 3: Identify Data Source

Determine where your data comes from:
- Session logs via `OptimizedDataLoader`
- Dedicated repository (e.g., `BowelMovementRepo`)
- External API or calculation

### Step 4: Create the MetricProvider Struct

Create a new struct conforming to `MetricProvider`. See [Code Examples](#code-examples) below.

### Step 5: Register the Metric

**For static metrics:**
Add to the `staticMetrics` array in `MetricRegistry`:

```swift
private let staticMetrics: [any MetricProvider] = [
    MoodMetricProvider(),
    PainLevelMetricProvider(),
    YourNewMetricProvider(), // Add here
]
```

**For dynamic metrics:**
Add a generation method in `MetricRegistry`:

```swift
private func generateYourMetrics() async -> [any MetricProvider] {
    let items = await dataLoader.getAvailableItems()
    return items.map { item in
        YourMetricProvider(itemName: item)
    }
}
```

Then call it in `getAllMetricProviders()`:

```swift
metrics.append(contentsOf: await generateYourMetrics())
```

### Step 6: Test Your Metric

1. Build and run the app
2. Navigate to the Insights/Metrics section
3. Verify your metric appears in the correct category
4. Check data loading and chart rendering
5. Test different time periods
6. Verify value formatting

---

## Code Examples

### Example 1: Simple Continuous Metric (Static)

A metric tracking sleep quality on a 1-10 scale:

```swift
struct SleepQualityMetricProvider: MetricProvider {
    let id = "sleep_quality"
    let displayName = "Sleep Quality"
    let description = "1-10 scale tracking sleep quality"
    let icon = "😴"
    let category: MetricCategory = .lifestyle
    let dataType: MetricDataType = .continuous(range: 1...10)
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 1...10
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let sleepQuality = log.sleepQuality else { return nil }
            return MetricDataPoint(
                date: log.date,
                value: Double(sleepQuality),
                rawValue: sleepQuality,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.sleepQuality != nil
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(Int(value.rounded()))
    }
}
```

### Example 2: Binary Metric (Static)

Tracking whether exercise was done each day:

```swift
struct ExerciseMetricProvider: MetricProvider {
    let id = "daily_exercise"
    let displayName = "Daily Exercise"
    let description = "Days when exercise was completed"
    let icon = "💪"
    let category: MetricCategory = .activities
    let dataType: MetricDataType = .binary
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...1
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.map { log in
            MetricDataPoint(
                date: log.date,
                value: log.didExercise ? 1.0 : 0.0,
                rawValue: log.didExercise,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        let logs = await dataLoader.filterSessionLogs(for: period)
        return logs.count // Count all days since we track both true/false
    }
    
    func formatValue(_ value: Double) -> String {
        return value == 1.0 ? "✅" : "❌"
    }
    
    // Custom chart configuration for binary metrics
    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .line,
            primaryColor: CloveColors.green,
            showGradient: false,
            lineWidth: 3.0,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}
```

### Example 3: Count Metric (Static)

Tracking number of water glasses consumed per day:

```swift
struct WaterIntakeMetricProvider: MetricProvider {
    let id = "water_intake"
    let displayName = "Water Intake"
    let description = "Number of glasses of water per day"
    let icon = "💧"
    let category: MetricCategory = .lifestyle
    let dataType: MetricDataType = .count
    let chartType: MetricChartType = .bar
    let valueRange: ClosedRange<Double>? = nil // No fixed upper limit
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.map { log in
            MetricDataPoint(
                date: log.date,
                value: Double(log.waterGlasses),
                rawValue: log.waterGlasses,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.waterGlasses > 0
        }
    }
    
    func formatValue(_ value: Double) -> String {
        let count = Int(value)
        return "\(count) glass\(count == 1 ? "" : "es")"
    }
}
```

### Example 4: Percentage Metric (Static)

Tracking goal completion rate:

```swift
struct GoalCompletionMetricProvider: MetricProvider {
    let id = "goal_completion"
    let displayName = "Goal Completion"
    let description = "Percentage of daily goals completed"
    let icon = "🎯"
    let category: MetricCategory = .lifestyle
    let dataType: MetricDataType = .percentage
    let chartType: MetricChartType = .area
    let valueRange: ClosedRange<Double>? = 0...100
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard !log.dailyGoals.isEmpty else { return nil }
            
            let completedCount = log.dailyGoals.filter { $0.isCompleted }.count
            let percentage = (Double(completedCount) / Double(log.dailyGoals.count)) * 100.0
            
            return MetricDataPoint(
                date: log.date,
                value: percentage,
                rawValue: log.dailyGoals,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            !log.dailyGoals.isEmpty
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(format: "%.0f%%", value)
    }
    
    var chartConfiguration: MetricChartConfiguration {
        MetricChartConfiguration(
            chartType: .area,
            primaryColor: CloveColors.purple,
            showGradient: true,
            lineWidth: 2.5,
            showDataPoints: true,
            enableInteraction: true
        )
    }
}
```

### Example 5: Categorical Metric (Static)

Tracking stress level categories:

```swift
struct StressLevelMetricProvider: MetricProvider {
    let id = "stress_level"
    let displayName = "Stress Level"
    let description = "Daily stress level category"
    let icon = "😰"
    let category: MetricCategory = .coreHealth
    let dataType: MetricDataType = .categorical(values: ["Low", "Moderate", "High", "Severe"])
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 1...4
    
    private let dataLoader = OptimizedDataLoader.shared
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.compactMap { log in
            guard let stressLevel = log.stressLevel else { return nil }
            
            return MetricDataPoint(
                date: log.date,
                value: convertStressToNumeric(stressLevel),
                rawValue: stressLevel,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.stressLevel != nil
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return convertNumericToStress(value)
    }
    
    // Convert categorical values to numeric for charting
    private func convertStressToNumeric(_ stress: String) -> Double {
        switch stress.lowercased() {
        case "low": return 1.0
        case "moderate": return 2.0
        case "high": return 3.0
        case "severe": return 4.0
        default: return 2.0 // Default to moderate
        }
    }
    
    private func convertNumericToStress(_ value: Double) -> String {
        switch value {
        case 1.0: return "Low"
        case 2.0: return "Moderate"
        case 3.0: return "High"
        case 4.0: return "Severe"
        default: return "Unknown"
        }
    }
}
```

### Example 6: Dynamic Metric (User-Specific)

Creating metrics for each tracked supplement:

```swift
struct SupplementMetricProvider: MetricProvider {
    let supplementName: String
    
    var id: String { 
        "supplement_\(supplementName.lowercased().replacingOccurrences(of: " ", with: "_"))" 
    }
    var displayName: String { supplementName }
    var description: String { "Days when \(supplementName) was taken" }
    let icon = "💊"
    let category: MetricCategory = .medications
    let dataType: MetricDataType = .binary
    let chartType: MetricChartType = .line
    let valueRange: ClosedRange<Double>? = 0...1
    
    private let dataLoader = OptimizedDataLoader.shared
    
    init(supplementName: String) {
        self.supplementName = supplementName
    }
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        let logs = await dataLoader.filterSessionLogs(for: period)
        
        return logs.map { log in
            let wasTaken = log.supplementsTaken.contains(supplementName)
            return MetricDataPoint(
                date: log.date,
                value: wasTaken ? 1.0 : 0.0,
                rawValue: wasTaken,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return await dataLoader.getDataPointCount(for: period) { log in
            log.supplementsTaken.contains(supplementName)
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return value == 1.0 ? "✅" : "❌"
    }
}
```

**Then register in MetricRegistry:**

```swift
private func generateSupplementMetrics() async -> [any MetricProvider] {
    let dataLoader = OptimizedDataLoader.shared
    let supplements = await dataLoader.getAvailableSupplements()
    
    return supplements.map { supplement in
        SupplementMetricProvider(supplementName: supplement)
    }
}

// In getAllMetricProviders():
metrics.append(contentsOf: await generateSupplementMetrics())
```

### Example 7: Using a Custom Repository

For metrics with dedicated data storage:

```swift
struct StepCountMetricProvider: MetricProvider {
    let id = "step_count"
    let displayName = "Step Count"
    let description = "Daily step count from HealthKit"
    let icon = "👣"
    let category: MetricCategory = .activities
    let dataType: MetricDataType = .count
    let chartType: MetricChartType = .bar
    let valueRange: ClosedRange<Double>? = nil
    
    func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
        // Using a dedicated repository instead of OptimizedDataLoader
        let steps = StepCountRepo.shared.getSteps(for: period)
        
        return steps.map { stepData in
            MetricDataPoint(
                date: stepData.date,
                value: Double(stepData.count),
                rawValue: stepData,
                metricId: id
            )
        }
    }
    
    func getDataPointCount(for period: TimePeriod) async -> Int {
        return StepCountRepo.shared.getSteps(for: period).count
    }
    
    func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
```

---

## Best Practices

### 1. Use Async/Await Properly

All data access methods are async. Always use `await` when calling them:

```swift
func getDataPoints(for period: TimePeriod) async -> [MetricDataPoint] {
    let logs = await dataLoader.filterSessionLogs(for: period)
    // Process logs...
}
```

### 2. Handle Missing Data Gracefully

Use `compactMap` to filter out nil values:

```swift
return logs.compactMap { log in
    guard let value = log.yourValue else { return nil }
    return MetricDataPoint(/* ... */)
}
```

### 3. Provide Efficient Data Counting

Implement `getDataPointCount(for:)` efficiently without loading full data:

```swift
func getDataPointCount(for period: TimePeriod) async -> Int {
    return await dataLoader.getDataPointCount(for: period) { log in
        log.yourValue != nil
    }
}
```

### 4. Choose Appropriate Chart Types

Match chart type to data type:
- **Continuous metrics**: `.line` or `.area`
- **Binary metrics**: `.line` with data points
- **Count/categorical**: `.bar`
- **Percentage**: `.area`

### 5. Use Descriptive IDs

Metric IDs should be:
- Unique across all metrics
- Lowercase with underscores
- Descriptive of the metric
- Prefixed if dynamic (e.g., `symptom_`, `medication_`)

### 6. Format Values Appropriately

Make values user-friendly:

```swift
// For integers: "7"
func formatValue(_ value: Double) -> String {
    return String(Int(value.rounded()))
}

// For percentages: "85%"
func formatValue(_ value: Double) -> String {
    return String(format: "%.0f%%", value)
}

// For decimals: "7.5"
func formatValue(_ value: Double) -> String {
    return String(format: "%.1f", value)
}

// For binary: "✅" or "❌"
func formatValue(_ value: Double) -> String {
    return value == 1.0 ? "✅" : "❌"
}
```

### 7. Customize Chart Appearance

Override `chartConfiguration` for custom styling:

```swift
var chartConfiguration: MetricChartConfiguration {
    MetricChartConfiguration(
        chartType: .area,
        primaryColor: CloveColors.purple,
        showGradient: true,
        lineWidth: 2.5,
        showDataPoints: false,
        enableInteraction: true
    )
}
```

### 8. Store Raw Values When Needed

For complex data types, store the original value:

```swift
MetricDataPoint(
    date: log.date,
    value: numericValue,
    rawValue: originalComplexObject, // Store for later access
    metricId: id
)
```

### 9. Invalidate Cache When Data Changes

When new data is logged, tell the registry to refresh:

```swift
// After saving new data
MetricRegistry.shared.invalidateCache()
```

### 10. Test Different Time Periods

Ensure your metric works correctly for all time periods:
- Week (7 days)
- Month (30 days)
- 3 Months
- 6 Months
- Year
- All Time

---

## Testing Your Metric

### Manual Testing Checklist

1. **Build and run** the app
2. **Navigate** to Insights/Metrics Explorer
3. **Verify appearance**: Check your metric shows in the correct category
4. **Check data loading**: Ensure data loads without errors
5. **Test time periods**: Switch between different time ranges
6. **Verify formatting**: Confirm values display correctly
7. **Test empty state**: Verify behavior when no data exists
8. **Check chart rendering**: Ensure chart displays appropriately
9. **Test interactions**: Tap data points, zoom, pan
10. **Performance**: Check loading times with large datasets

### Common Issues and Solutions

**Issue**: Metric doesn't appear in the list
- **Solution**: Check that the metric is registered in `MetricRegistry`
- **Solution**: Verify `getDataPointCount()` returns > 0

**Issue**: Data doesn't load
- **Solution**: Check async/await usage
- **Solution**: Verify data source is accessible
- **Solution**: Add debug prints in `getDataPoints(for:)`

**Issue**: Chart renders incorrectly
- **Solution**: Verify `chartType` matches `dataType`
- **Solution**: Check `valueRange` is set correctly
- **Solution**: Ensure data points have valid dates and values

**Issue**: Values display wrong format
- **Solution**: Review `formatValue(_:)` implementation
- **Solution**: Check for rounding or precision issues

**Issue**: Performance is slow
- **Solution**: Implement efficient `getDataPointCount(for:)`
- **Solution**: Use `getAggregatedDataPoints` for large datasets
- **Solution**: Ensure proper caching in data loader

---

## Summary

Adding a new metric to Clove involves:

1. **Choose** your metric type (static or dynamic)
2. **Select** appropriate data type and chart type
3. **Create** a struct conforming to `MetricProvider`
4. **Implement** required methods for data access
5. **Register** the metric in `MetricRegistry`
6. **Test** thoroughly across different time periods

The provider-based architecture makes it straightforward to add new metrics while maintaining consistency across the app. Follow the examples and best practices in this guide to create robust, performant metrics.

---

## Additional Resources

- **Core Files**:
  - `Clove/Metrics/Core/MetricProvider.swift` - Protocol definition
  - `Clove/Metrics/Core/MetricRegistry.swift` - Central registry
  - `Clove/Metrics/Core/MetricDataTypes.swift` - Type definitions

- **Examples**:
  - `Clove/Metrics/Providers/CoreHealthMetrics.swift` - Static metrics
  - `Clove/Metrics/Providers/DynamicMetrics.swift` - Dynamic metrics

- **Related Services**:
  - `Clove/Metrics/Services/OptimizedDataLoader.swift` - Efficient data loading
  - `Clove/Metrics/Services/ChartDataAggregator.swift` - Data aggregation
  - `Clove/Services/TimePeriodManager.swift` - Time period handling

For questions or issues, consult the existing metric implementations or reach out to the development team.
