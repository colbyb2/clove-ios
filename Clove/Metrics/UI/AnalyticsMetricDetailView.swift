import SwiftUI
import Charts

enum AnalyticsRepositoryContainer {
    static let shared = CachedAnalyticsRepository(repository: DefaultAnalyticsRepository())
}

@MainActor
@Observable
final class AnalyticsMetricDetailViewModel {
    enum State {
        case idle
        case loading
        case loaded(AnalyticsChartResult)
        case empty(MetricDefinition)
        case failed(String)
    }

    var state: State = .idle
    private var loadGeneration = 0

    func load(
        providerID: String,
        interval: DateInterval,
        compare: Bool,
        granularity: AnalyticsGranularity,
        hydrationGoal: Double
    ) async {
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        do {
            let request = AnalyticsRequest(interval: interval, includeRawEvents: true)
            let dataset = try await AnalyticsRepositoryContainer.shared.load(request, granularity: granularity)
            try Task.checkCancellation()
            guard let definition = resolveDefinition(providerID: providerID, dataset: dataset) else {
                state = .failed("This metric could not be resolved after its identity migration.")
                return
            }
            let previous: AnalyticsDataset?
            if compare, let previousInterval = AnalyticsDateRangeFactory().previous(equalTo: interval) {
                previous = try await AnalyticsRepositoryContainer.shared.load(
                    AnalyticsRequest(interval: previousInterval, metricIDs: [definition.id], includeRawEvents: true),
                    granularity: granularity
                )
            } else {
                previous = nil
            }
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }
            let result = AnalyticsChartPipeline().build(
                definition: definition,
                dataset: dataset,
                previousDataset: previous,
                granularity: granularity,
                hydrationGoal: hydrationGoal
            )
            state = result.summary.value == nil ? .empty(definition) : .loaded(result)
        } catch is CancellationError {
            // A newer range or metric request owns the visible state.
        } catch {
            guard generation == loadGeneration else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func resolveDefinition(providerID: String, dataset: AnalyticsDataset) -> MetricDefinition? {
        let exactID = MetricID(rawValue: providerID)
        if let exact = dataset.definitions.first(where: { $0.id == exactID }) { return exact }
        guard let aliases = dataset.metricAliases[providerID], aliases.count == 1, let canonical = aliases.first else { return nil }
        return dataset.definitions.first { $0.id == canonical }
    }
}

struct AnalyticsMetricDetailView: View {
    private let metricID: String
    private let metricDisplayName: String
    private let metricIcon: String
    let timeManager = TimePeriodManager.shared

    @State private var viewModel = AnalyticsMetricDetailViewModel()
    @State private var displayMode: AnalyticsChartDisplayMode = .raw
    @State private var selectedDate: Date?
    @State private var selectedLog: DailyLog?
    @AppStorage(Constants.HYDRATION_GOAL_OUNCES) private var hydrationGoalOunces = 64

    init(metric: any MetricProvider) {
        metricID = metric.id
        metricDisplayName = metric.displayName
        metricIcon = metric.icon
    }

    init(definition: MetricDefinition) {
        metricID = definition.id.rawValue
        metricDisplayName = definition.displayName
        metricIcon = Self.icon(for: definition)
    }

    private var interval: DateInterval {
        timeManager.currentDateRange ?? AnalyticsDateRangeFactory().interval(for: .allTime)
    }

    private var granularity: AnalyticsGranularity {
        AnalyticsChartPipeline().granularity(for: interval)
    }

    private var loadKey: String {
        [metricID, String(interval.start.timeIntervalSinceReferenceDate), String(interval.end.timeIntervalSinceReferenceDate), String(timeManager.isComparisonModeEnabled), String(hydrationGoalOunces)].joined(separator: "|")
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .empty(let definition):
                emptyView(definition)
            case .loaded(let result):
                detail(result)
            }
        }
        .task(id: loadKey) {
            await viewModel.load(
                providerID: metricID,
                interval: interval,
                compare: timeManager.isComparisonModeEnabled && timeManager.selectedPeriod != .allTime,
                granularity: granularity,
                hydrationGoal: Double(hydrationGoalOunces)
            )
        }
        .sheet(item: $selectedLog) { log in
            DailyLogDetailView(log: log)
        }
    }

    private var loadingView: some View {
        VStack(spacing: CloveSpacing.medium) {
            ProgressView()
            Text("Analyzing \(metricDisplayName)…")
                .font(CloveFonts.small())
                .foregroundStyle(CloveColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Analyze Metric", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.load(providerID: metricID, interval: interval, compare: timeManager.isComparisonModeEnabled, granularity: granularity, hydrationGoal: Double(hydrationGoalOunces)) }
            }
        }
        .frame(minHeight: 260)
    }

    private func emptyView(_ definition: MetricDefinition) -> some View {
        ContentUnavailableView(
            "No \(definition.displayName) Data",
            systemImage: "chart.xyaxis.line",
            description: Text("Nothing was recorded in this exact date range. Unrecorded days remain gaps, not zeroes.")
        )
        .frame(minHeight: 260)
    }

    private func detail(_ result: AnalyticsChartResult) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.large) {
            detailHeader(result)
            summaryCards(result)
            chartSection(result)
            comparisonSection(result)
            coverageSection(result)
            notableDatesSection(result)
            limitationsSection(result)
            relatedAnalysisLink(result)
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(CloveColors.card)
        )
    }

    private func detailHeader(_ result: AnalyticsChartResult) -> some View {
        HStack(alignment: .top, spacing: CloveSpacing.medium) {
            Image(systemName: metricIcon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.shared.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.definition.displayName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(CloveColors.primaryText)
                Text(result.definition.description)
                    .font(CloveFonts.small())
                    .foregroundStyle(CloveColors.secondaryText)
                Text(result.aggregationLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.shared.accent)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func summaryCards(_ result: AnalyticsChartResult) -> some View {
        if let value = result.summary.value {
            let items = summaryItems(value, definition: result.definition, trend: result.summary.trend)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CloveSpacing.small) {
                    ForEach(items, id: \.title) { summaryCard($0.title, $0.value) }
                }
                VStack(spacing: CloveSpacing.small) {
                    ForEach(items, id: \.title) { summaryCard($0.title, $0.value) }
                }
            }
        }
    }

    private func summaryCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(CloveColors.secondaryText)
            Text(value).font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(CloveColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CloveSpacing.small)
        .background(RoundedRectangle(cornerRadius: CloveCorners.small).fill(CloveColors.background))
    }

    private func chartSection(_ result: AnalyticsChartResult) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text("Chart").font(.headline).foregroundStyle(CloveColors.primaryText)
                Spacer()
                if supportsRolling(result) {
                    Picker("Chart display", selection: $displayMode) {
                        ForEach(AnalyticsChartDisplayMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180, minHeight: 44)
                }
            }
            typeAwareChart(result)
                .frame(height: 250)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(result.definition.displayName) chart")
                .accessibilityValue(accessibleSummary(result))

            if case .hydrationProgress(let goal) = result.family {
                HStack(spacing: 14) {
                    chartKey(color: CloveColors.success, text: "Met \(Int(goal)) oz goal")
                    chartKey(color: Theme.shared.accent, text: "Below goal")
                }
                .accessibilityElement(children: .combine)
            }

            if let point = selectedPoint(in: result) {
                Text("\(point.date.formatted(date: .abbreviated, time: .omitted)): \(format(point.value, definition: result.definition)) · \(result.aggregationLabel)")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                    .accessibilityLabel("Selected value \(format(point.value, definition: result.definition)) on \(point.date.formatted(date: .complete, time: .omitted))")
            }
        }
    }

    @ViewBuilder
    private func typeAwareChart(_ result: AnalyticsChartResult) -> some View {
        switch result.family {
        case .categoricalDistribution, .bristolDistribution:
            Chart(result.categories.filter { !$0.isPreviousPeriod }) { point in
                BarMark(x: .value("Count", point.count), y: .value("Category", point.category))
                    .foregroundStyle(Theme.shared.accent.gradient)
            }
            .chartXAxisLabel("Recorded observations")

        case .eventOccurrences:
            Chart(activePoints(result)) { point in
                PointMark(x: .value("Date", point.date), y: .value("Recorded", 1))
                    .symbolSize(90)
                    .foregroundStyle(Theme.shared.accent)
                if point.date == selectedPoint(in: result)?.date {
                    RuleMark(x: .value("Selected date", point.date)).foregroundStyle(Theme.shared.accent.opacity(0.6))
                }
            }
            .chartYScale(domain: 0...2)
            .chartYAxis(.hidden)
            .chartXSelection(value: $selectedDate)

        case .hydrationProgress(let goal):
            Chart {
                ForEach(activePoints(result)) { point in
                    BarMark(x: .value("Date", point.date), y: .value("Fluid ounces", point.value))
                        .foregroundStyle(point.value >= goal ? CloveColors.success : Theme.shared.accent)
                }
                RuleMark(y: .value("Daily goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(CloveColors.secondaryText)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("\(Int(goal)) oz goal")
                            .font(.caption2.bold())
                            .foregroundStyle(CloveColors.secondaryText)
                    }
            }
            .chartXSelection(value: $selectedDate)

        case .countBars, .binaryRate:
            Chart(activePoints(result)) { point in
                BarMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(Theme.shared.accent.gradient)
            }
            .chartYScale(domain: result.family == .binaryRate ? 0...100 : automaticDomain(result))
            .chartXSelection(value: $selectedDate)

        case .numericLine:
            Chart(activePoints(result)) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    series: .value("Continuous segment", point.segment)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(Theme.shared.accent)
                if point.date == selectedPoint(in: result)?.date {
                    PointMark(x: .value("Selected date", point.date), y: .value("Selected value", point.value))
                        .symbolSize(100)
                        .foregroundStyle(Theme.shared.accent)
                }
            }
            .chartYScale(domain: numericDomain(result.definition, result: result))
            .chartXSelection(value: $selectedDate)
        }
    }

    private func chartKey(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption)
                .foregroundStyle(CloveColors.secondaryText)
        }
    }

    @ViewBuilder
    private func comparisonSection(_ result: AnalyticsChartResult) -> some View {
        if let comparison = result.summary.comparison {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Period comparison").font(.headline).foregroundStyle(CloveColors.primaryText)
                HStack(spacing: CloveSpacing.small) {
                    summaryCard("Selected", primaryText(comparison.current, definition: result.definition))
                    summaryCard("Previous", primaryText(comparison.previous, definition: result.definition))
                }
                Text("Coverage: \(comparison.currentCoverage.sourceDayCount)/\(comparison.currentCoverage.possibleDayCount) days selected · \(comparison.previousCoverage.sourceDayCount)/\(comparison.previousCoverage.possibleDayCount) days previous")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }
        } else if timeManager.isComparisonModeEnabled && timeManager.selectedPeriod == .allTime {
            Text("Previous-period comparison is unavailable for All Time.")
                .font(.caption)
                .foregroundStyle(CloveColors.secondaryText)
        }
    }

    private func coverageSection(_ result: AnalyticsChartResult) -> some View {
        let coverage = result.summary.coverage
        return VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Text("Data coverage").font(.headline).foregroundStyle(CloveColors.primaryText)
                Spacer()
                Text("\(Int((coverage.observedDayFraction * 100).rounded()))%")
                    .font(.headline).foregroundStyle(Theme.shared.accent)
            }
            ProgressView(value: coverage.observedDayFraction).tint(Theme.shared.accent)
            Text("\(coverage.sourceDayCount) of \(coverage.possibleDayCount) days contain source data · \(coverage.observedCount) observations")
                .font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    @ViewBuilder
    private func notableDatesSection(_ result: AnalyticsChartResult) -> some View {
        if !result.summary.notableDates.isEmpty {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Text("Notable dates").font(.headline).foregroundStyle(CloveColors.primaryText)
                ForEach(result.summary.notableDates) { item in
                    Button {
                        selectedLog = LogsRepo.shared.getLogForDate(item.date) ?? DailyLog(date: item.date)
                    } label: {
                        HStack {
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(format(item.value, definition: result.definition)).fontWeight(.semibold)
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the daily record when one exists")
                }
            }
        }
    }

    @ViewBuilder
    private func limitationsSection(_ result: AnalyticsChartResult) -> some View {
        if !result.summary.limitations.isEmpty {
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                Label("About this result", systemImage: "info.circle").font(.headline)
                ForEach(result.summary.limitations, id: \.self) { limitation in
                    Text("• \(limitation)").font(.caption).foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
    }

    private func relatedAnalysisLink(_ result: AnalyticsChartResult) -> some View {
        NavigationLink(destination: CrossReferenceView()) {
            HStack {
                Label("Compare with another metric", systemImage: "arrow.triangle.branch")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .frame(minHeight: 44)
            .foregroundStyle(Theme.shared.accent)
        }
        .accessibilityHint("Opens relationship analysis")
    }

    private func activePoints(_ result: AnalyticsChartResult) -> [AnalyticsChartPoint] {
        displayMode == .rolling && supportsRolling(result) ? result.rollingPoints : result.points
    }

    private func supportsRolling(_ result: AnalyticsChartResult) -> Bool {
        result.granularity == .daily && [.continuous, .ordinal, .count, .percentage].contains(result.definition.measurementLevel) && result.points.count > 2
    }

    private func selectedPoint(in result: AnalyticsChartResult) -> AnalyticsChartPoint? {
        guard let selectedDate else { return nil }
        return activePoints(result).min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private func summaryItems(_ value: MetricSummaryValue, definition: MetricDefinition, trend: MetricTrendSummary?) -> [(title: String, value: String)] {
        var result: [(String, String)]
        switch value {
        case .numeric(let mean, let median, _, _, let total):
            result = [(total == nil ? "Average" : "Total", format(total ?? mean, definition: definition)), ("Median", format(median, definition: definition))]
        case .binary(let occurrences, let denominator, let rate):
            result = [("Occurrence rate", "\(Int(rate.rounded()))%"), ("Recorded", "\(occurrences) of \(denominator)")]
        case .categorical(_, let mode):
            result = [("Most common", mode ?? "—")]
        case .event(let occurrences, let activeDays):
            result = [("Occurrences", "\(occurrences)"), ("Active days", "\(activeDays)")]
        case .percentage(let value, let numerator, let denominator):
            result = [("Weighted rate", "\(Int(value.rounded()))%"), ("Doses", numerator.flatMap { n in denominator.map { "\(n) of \($0)" } } ?? "Observed days")]
        }
        if let trend { result.append(("Trend", trend.direction.rawValue.capitalized)) }
        return result
    }

    private func primaryText(_ value: MetricSummaryValue, definition: MetricDefinition) -> String {
        summaryItems(value, definition: definition, trend: nil).first?.value ?? "—"
    }

    private func format(_ value: Double, definition: MetricDefinition) -> String {
        let digits = definition.displayFormat.maximumFractionDigits
        return value.formatted(.number.precision(.fractionLength(0...digits))) + (definition.displayFormat.suffix ?? unitSuffix(definition.unit))
    }

    private func unitSuffix(_ unit: MetricUnit) -> String {
        switch unit {
        case .percentage: return "%"
        case .fluidOunces: return " oz"
        case .minutes: return " min"
        case .custom(let symbol): return " \(symbol)"
        default: return ""
        }
    }

    private func accessibleSummary(_ result: AnalyticsChartResult) -> String {
        let primary = result.summary.value.map { primaryText($0, definition: result.definition) } ?? "No observed value"
        return "\(primary). \(result.summary.coverage.observedCount) observations across \(result.summary.coverage.sourceDayCount) days. \(result.aggregationLabel)."
    }

    private func automaticDomain(_ result: AnalyticsChartResult) -> ClosedRange<Double> {
        0...max(1, (activePoints(result).map(\.value).max() ?? 1) * 1.1)
    }

    private func numericDomain(_ definition: MetricDefinition, result: AnalyticsChartResult) -> ClosedRange<Double> {
        switch definition.domain {
        case .numeric(let range): return range
        case .nonNegative: return automaticDomain(result)
        case .categories, .unrestricted:
            let values = activePoints(result).map(\.value)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 1
            return minimum == maximum ? (minimum - 1)...(maximum + 1) : minimum...maximum
        }
    }

    private static func icon(for definition: MetricDefinition) -> String {
        switch definition.id {
        case MetricCatalog.mood.id: return CloveSymbols.mood
        case MetricCatalog.painLevel.id: return CloveSymbols.pain
        case MetricCatalog.energyLevel.id: return CloveSymbols.energy
        case MetricCatalog.hydration.id: return CloveSymbols.hydration
        case MetricCatalog.bristolStoolType.id, MetricCatalog.bowelMovementFrequency.id: return CloveSymbols.bowelMovement
        case MetricCatalog.medicationAdherence.id: return CloveSymbols.medication
        case MetricCatalog.flowLevel.id: return CloveSymbols.cycle
        default:
            return switch definition.category {
            case .symptoms: CloveSymbols.symptom
            case .medications: CloveSymbols.medication
            case .activities: CloveSymbols.activities
            case .meals: CloveSymbols.meals
            case .environmental: CloveSymbols.weather
            case .lifestyle: "figure.mind.and.body"
            case .coreHealth: CloveSymbols.overview
            }
        }
    }
}
