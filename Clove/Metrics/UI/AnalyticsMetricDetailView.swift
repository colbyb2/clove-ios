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
        guard let aliases = dataset.metricAliases[providerID], aliases.count == 1,
              let canonical = aliases.first else { return nil }
        return dataset.definitions.first { $0.id == canonical }
    }
}

struct AnalyticsMetricDetailView: View {
    private struct SummaryItem {
        let title: String
        let value: String
        let color: Color
    }

    private let metricID: String
    private let metricDisplayName: String
    private let metricIcon: String
    let timeManager = TimePeriodManager.shared

    @State private var viewModel = AnalyticsMetricDetailViewModel()
    @State private var displayMode: AnalyticsChartDisplayMode = .raw
    @State private var selectedDate: Date?
    @State private var selectedLog: DailyLog?
    @State private var isQualityExpanded = false
    @AppStorage(Constants.HYDRATION_GOAL_OUNCES) private var hydrationGoalOunces = 64
    @AppStorage(Constants.HYDRATION_GOAL_ENABLED) private var hydrationGoalEnabled = true
    @AppStorage(Constants.HYDRATION_UNIT) private var hydrationUnitRawValue = HydrationUnit.fluidOunces.rawValue

    private var hydrationUnit: HydrationUnit {
        HydrationUnit(rawValue: hydrationUnitRawValue) ?? .fluidOunces
    }

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
        [metricID, String(interval.start.timeIntervalSinceReferenceDate),
         String(interval.end.timeIntervalSinceReferenceDate), String(timeManager.isComparisonModeEnabled),
         String(hydrationGoalOunces), String(hydrationGoalEnabled), hydrationUnitRawValue].joined(separator: "|")
    }

    /// Swift Charts writes `nil` when its selection gesture ends. Keeping the
    /// last real value lets a tap or drag-release remain actionable below the chart.
    private var persistentChartSelection: Binding<Date?> {
        Binding(
            get: { selectedDate },
            set: { newValue in
                if let newValue { selectedDate = newValue }
            }
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading: loadingView
            case .failed(let message): errorView(message)
            case .empty(let definition): emptyView(definition)
            case .loaded(let result): detail(result)
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
        .sheet(item: $selectedLog) { log in DailyLogDetailView(log: log) }
    }

    private var loadingView: some View {
        VStack(spacing: CloveSpacing.medium) {
            ProgressView().tint(Theme.shared.accent)
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
                Task {
                    await viewModel.load(
                        providerID: metricID, interval: interval,
                        compare: timeManager.isComparisonModeEnabled,
                        granularity: granularity, hydrationGoal: Double(hydrationGoalOunces)
                    )
                }
            }
        }
        .frame(minHeight: 260)
    }

    private func emptyView(_ definition: MetricDefinition) -> some View {
        ContentUnavailableView(
            "No \(definition.displayName) Data",
            systemImage: "chart.xyaxis.line",
            description: Text("Nothing was recorded in this date range. Unrecorded days remain gaps, not zeroes.")
        )
        .frame(minHeight: 260)
    }

    private func detail(_ result: AnalyticsChartResult) -> some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            overviewCard(result)
            chartCard(result)
            comparisonSection(result)
            notableDatesSection(result)
            relatedAnalysisLink(result)
            qualitySection(result)
        }
    }

    private func overviewCard(_ result: AnalyticsChartResult) -> some View {
        let tint = MetricPresentation.tint(for: result.definition)
        return VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: metricIcon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.definition.displayName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)
                    Text(result.definition.description)
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if let narrative = MetricPresentation.narrative(
                definition: result.definition,
                summary: result.summary,
                format: { format($0, definition: result.definition) }
            ) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(narrative.headline)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(CloveColors.primaryText)
                    Text(narrative.detail)
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            }

            summaryCards(result)
        }
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.large))
        .overlay {
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func summaryCards(_ result: AnalyticsChartResult) -> some View {
        if let value = result.summary.value {
            let items = summaryItems(value, definition: result.definition, trend: result.summary.trend)
            HStack(spacing: CloveSpacing.small) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.caption).foregroundStyle(CloveColors.secondaryText)
                        Text(item.value)
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(item.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CloveSpacing.small)
                    .background(CloveColors.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func chartCard(_ result: AnalyticsChartResult) -> some View {
        let tint = MetricPresentation.tint(for: result.definition)
        return VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MetricPresentation.chartTitle(for: result.family))
                        .font(.headline)
                        .foregroundStyle(CloveColors.primaryText)
                    Text(result.aggregationLabel)
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                Spacer()
                if supportsRolling(result) { displayModePicker(tint: tint) }
            }

            typeAwareChart(result)
                .frame(height: chartHeight(result))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(result.definition.displayName) chart")
                .accessibilityValue(accessibleSummary(result))

            chartLegend(result)

            if let point = selectedPoint(in: result) {
                selectedPointCard(point, result: result, tint: tint)
            }
        }
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.large))
    }

    private func displayModePicker(tint: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(AnalyticsChartDisplayMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { displayMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(displayMode == mode ? tint : CloveColors.secondaryText)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(displayMode == mode ? tint.opacity(0.15) : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(CloveColors.background, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart display")
    }

    @ViewBuilder
    private func typeAwareChart(_ result: AnalyticsChartResult) -> some View {
        let tint = MetricPresentation.tint(for: result.definition)
        switch result.family {
        case .categoricalDistribution, .bristolDistribution:
            let categories = orderedCategories(result)
            Chart(categories) { point in
                BarMark(x: .value("Count", point.count), y: .value("Category", point.category))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(categoryColor(point.category, result: result))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(categoryAnnotation(point, all: categories))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
            }
            .chartXAxisLabel("Recorded observations")
            .chartXAxis { AxisMarks(position: .bottom) { AxisGridLine().foregroundStyle(.secondary.opacity(0.18)); AxisValueLabel() } }
            .chartYAxis { AxisMarks { AxisValueLabel().font(.caption) } }
            .chartXScale(domain: categoryDomain(categories))

        case .eventOccurrences:
            Chart {
                RuleMark(y: .value("Timeline", 0))
                    .foregroundStyle(CloveColors.secondaryText.opacity(0.25))
                ForEach(activePoints(result)) { point in
                    PointMark(x: .value("Date", point.date), y: .value("Recorded", 0))
                        .symbolSize(point.date == selectedPoint(in: result)?.date ? 145 : 95)
                        .foregroundStyle(tint)
                    if point.date == selectedPoint(in: result)?.date {
                        RuleMark(x: .value("Selected date", point.date)).foregroundStyle(tint.opacity(0.45))
                    }
                }
            }
            .chartYScale(domain: -1...1)
            .chartYAxis(.hidden)
            .chartXSelection(value: persistentChartSelection)

        case .hydrationProgress(let goal):
            let displayGoal = displayHydration(goal)
            Chart {
                ForEach(activePoints(result)) { point in
                    BarMark(x: .value("Date", point.date), y: .value(hydrationUnit.title, displayHydration(point.value)))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(hydrationGoalEnabled && point.value >= goal ? CloveColors.success : tint)
                }
                if hydrationGoalEnabled {
                    RuleMark(y: .value("Daily goal", displayGoal))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(CloveColors.secondaryText)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(formatHydration(goal)) goal")
                                .font(.caption2.bold())
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                }
            }
            .chartXSelection(value: persistentChartSelection)

        case .countBars:
            Chart(activePoints(result)) { point in
                BarMark(x: .value("Date", point.date), y: .value("Count", point.value))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(tint.gradient)
            }
            .chartYScale(domain: automaticDomain(result))
            .chartXSelection(value: persistentChartSelection)

        case .binaryRate:
            Chart(activePoints(result)) { point in
                BarMark(x: .value("Date", point.date), y: .value("Rate", point.value))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(tint.gradient)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis { AxisMarks(values: [0, 25, 50, 75, 100]) { AxisGridLine(); AxisValueLabel() } }
            .chartXSelection(value: persistentChartSelection)

        case .numericLine:
            Chart(activePoints(result)) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    series: .value("Continuous segment", point.segment)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(tint)

                PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .symbolSize(point.date == selectedPoint(in: result)?.date ? 110 : 32)
                    .foregroundStyle(MetricPresentation.valueColor(point.value, definition: result.definition))
            }
            .chartYScale(domain: numericDomain(result.definition, result: result))
            .chartXSelection(value: persistentChartSelection)
            .chartPlotStyle { plot in plot.background(tint.opacity(0.035)) }
        }
    }

    @ViewBuilder
    private func chartLegend(_ result: AnalyticsChartResult) -> some View {
        if case .hydrationProgress(let goal) = result.family, hydrationGoalEnabled {
            HStack(spacing: 14) {
                chartKey(color: CloveColors.success, text: "Met \(formatHydration(goal)) goal")
                chartKey(color: MetricPresentation.tint(for: result.definition), text: "Below goal")
            }
            .accessibilityElement(children: .combine)
        } else if result.family == .numericLine, result.definition.directionality != .neutral {
            HStack(spacing: 12) {
                chartKey(color: CloveColors.red, text: "Less favorable")
                chartKey(color: CloveColors.success, text: "More favorable")
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func selectedPointCard(_ point: AnalyticsChartPoint, result: AnalyticsChartResult, tint: Color) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectionPeriodLabel(for: point, result: result))
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
                Text(selectedPointValue(point, result: result))
                    .font(.subheadline.bold())
                    .foregroundStyle(tint)
            }
            Spacer()
            if result.granularity == .daily {
                Button("View day") {
                    selectedLog = LogsRepo.shared.getLogForDate(point.date) ?? DailyLog(date: point.date)
                }
                .font(.caption.bold())
                .foregroundStyle(tint)
                .buttonStyle(.plain)
            } else {
                Label(
                    result.granularity == .weekly ? "Weekly summary" : "Monthly summary",
                    systemImage: "calendar"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(CloveColors.secondaryText)
            }
        }
        .padding(12)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func comparisonSection(_ result: AnalyticsChartResult) -> some View {
        if let comparison = result.summary.comparison {
            let color = MetricPresentation.statusColor(for: comparison.favorability)
            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                HStack {
                    Label("Compared with the previous period", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                    Spacer()
                    comparisonBadge(comparison, color: color)
                }
                HStack(spacing: CloveSpacing.small) {
                    comparisonValue("Current", comparison.current, definition: result.definition)
                    comparisonValue("Previous", comparison.previous, definition: result.definition)
                }
                Text("Based on \(comparison.currentCoverage.sourceDayCount) current and \(comparison.previousCoverage.sourceDayCount) previous recorded days.")
                    .font(.caption)
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(CloveSpacing.medium)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.large))
        } else if timeManager.isComparisonModeEnabled && timeManager.selectedPeriod == .allTime {
            Text("Previous-period comparison is unavailable for All Time.")
                .font(.caption)
                .foregroundStyle(CloveColors.secondaryText)
        }
    }

    private func comparisonBadge(_ comparison: MetricPeriodComparison, color: Color) -> some View {
        let text: String = switch comparison.favorability {
        case .favorable: "Improved"
        case .unfavorable: "Needs attention"
        case .neutral: comparison.direction?.rawValue.capitalized ?? "Current"
        }
        return Text(text)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func comparisonValue(_ label: String, _ value: MetricSummaryValue, definition: MetricDefinition) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(CloveColors.secondaryText)
            Text(primaryText(value, definition: definition))
                .font(.title3.bold())
                .foregroundStyle(CloveColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CloveColors.background, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func notableDatesSection(_ result: AnalyticsChartResult) -> some View {
        if !result.summary.notableDates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Label("Dates to review", systemImage: "calendar.badge.clock")
                    .font(.headline)
                    .padding(.bottom, 8)
                ForEach(Array(result.summary.notableDates.prefix(3))) { item in
                    Button {
                        selectedLog = LogsRepo.shared.getLogForDate(item.date) ?? DailyLog(date: item.date)
                    } label: {
                        HStack {
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(format(item.value, definition: result.definition))
                                .fontWeight(.semibold)
                                .foregroundStyle(MetricPresentation.valueColor(item.value, definition: result.definition))
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(CloveColors.secondaryText)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    if item.id != result.summary.notableDates.prefix(3).last?.id { Divider() }
                }
            }
            .padding(CloveSpacing.medium)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.large))
        }
    }

    private func relatedAnalysisLink(_ result: AnalyticsChartResult) -> some View {
        let tint = MetricPresentation.tint(for: result.definition)
        return NavigationLink(destination: CrossReferenceView()) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.body.bold())
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare with another metric").font(.headline)
                    Text("Explore how two recorded patterns move together")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CloveColors.secondaryText)
            }
            .padding(CloveSpacing.medium)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.large))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens relationship analysis")
    }

    private func qualitySection(_ result: AnalyticsChartResult) -> some View {
        let coverage = result.summary.coverage
        let isEvent = result.definition.measurementLevel == .event
        let percentage = Int((coverage.observedDayFraction * 100).rounded())
        let color: Color = !isEvent && coverage.observedDayFraction < 0.5
            ? CloveColors.orange
            : MetricPresentation.tint(for: result.definition)

        return DisclosureGroup(isExpanded: $isQualityExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if isEvent {
                    Text("\(coverage.sourceDayCount) days contain an explicitly recorded occurrence. Unrecorded days are not interpreted as zero, missed, or not taken.")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                } else {
                    ProgressView(value: coverage.observedDayFraction).tint(color)
                    Text("\(coverage.sourceDayCount) of \(coverage.possibleDayCount) days contain source data · \(coverage.observedCount) observations")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
                ForEach(result.summary.limitations, id: \.self) { limitation in
                    Text("• \(limitation)")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label(isEvent ? "Recording details" : "Data quality", systemImage: "checkmark.shield")
                    .font(.headline)
                    .foregroundStyle(CloveColors.primaryText)
                Spacer()
                Text(isEvent ? "\(coverage.sourceDayCount) days" : "\(percentage)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
        }
        .tint(CloveColors.secondaryText)
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.large))
    }

    private func summaryItems(_ value: MetricSummaryValue, definition: MetricDefinition, trend: MetricTrendSummary?) -> [SummaryItem] {
        let tint = MetricPresentation.tint(for: definition)
        var items: [SummaryItem]
        switch value {
        case .numeric(let mean, _, let minimum, let maximum, let total):
            items = [
                SummaryItem(title: total == nil ? "Average" : "Total", value: format(total ?? mean, definition: definition), color: MetricPresentation.valueColor(total ?? mean, definition: definition)),
                SummaryItem(title: "Recorded range", value: "\(format(minimum, definition: definition))–\(format(maximum, definition: definition))", color: tint)
            ]
        case .binary(let occurrences, let denominator, let rate):
            items = [
                SummaryItem(title: "Observed rate", value: "\(Int(rate.rounded()))%", color: tint),
                SummaryItem(title: "Recorded", value: "\(occurrences) of \(denominator)", color: tint)
            ]
        case .categorical(let buckets, let mode):
            items = [
                SummaryItem(title: "Most common", value: mode ?? "—", color: tint),
                SummaryItem(title: "Entries", value: "\(buckets.reduce(0) { $0 + $1.count })", color: tint)
            ]
        case .event(let occurrences, let activeDays):
            items = [
                SummaryItem(title: "Occurrences", value: "\(occurrences)", color: tint),
                SummaryItem(title: "Recorded days", value: "\(activeDays)", color: tint)
            ]
        case .percentage(let percentage, let numerator, let denominator):
            items = [
                SummaryItem(title: "Adherence", value: "\(Int(percentage.rounded()))%", color: tint),
                SummaryItem(title: "Eligible doses", value: numerator.flatMap { n in denominator.map { "\(n) of \($0)" } } ?? "Observed days", color: tint)
            ]
        }
        if let trend {
            let label: String = switch trend.favorability {
            case .favorable: "Improved"
            case .unfavorable: "Attention"
            case .neutral: trend.direction.rawValue.capitalized
            }
            items.append(SummaryItem(title: "Trend", value: label, color: MetricPresentation.statusColor(for: trend.favorability)))
        }
        return Array(items.prefix(3))
    }

    private func primaryText(_ value: MetricSummaryValue, definition: MetricDefinition) -> String {
        summaryItems(value, definition: definition, trend: nil).first?.value ?? "—"
    }

    private func selectedPointValue(_ point: AnalyticsChartPoint, result: AnalyticsChartResult) -> String {
        if result.definition.measurementLevel == .event {
            if result.granularity != .daily {
                let count = Int(point.value.rounded())
                return "\(count) \(count == 1 ? "occurrence" : "occurrences")"
            }
            return point.value > 1 ? "\(Int(point.value)) occurrences" : "Recorded"
        }
        return format(point.value, definition: result.definition)
    }

    private func selectionPeriodLabel(for point: AnalyticsChartPoint, result: AnalyticsChartResult) -> String {
        switch result.granularity {
        case .daily:
            return point.date.formatted(date: .abbreviated, time: .omitted)
        case .monthly:
            return point.date.formatted(.dateTime.month(.wide).year())
        case .weekly:
            let nextBucket = Calendar.current.date(byAdding: .day, value: 7, to: point.date) ?? point.date
            let bucketEnd = min(nextBucket, result.interval.end)
            let inclusiveEnd = Calendar.current.date(byAdding: .day, value: -1, to: bucketEnd) ?? point.date
            let formatter = DateIntervalFormatter()
            formatter.calendar = .current
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: point.date, to: max(point.date, inclusiveEnd))
        }
    }

    private func chartKey(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(text).font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
    }

    private func activePoints(_ result: AnalyticsChartResult) -> [AnalyticsChartPoint] {
        displayMode == .rolling && supportsRolling(result) ? result.rollingPoints : result.points
    }

    private func supportsRolling(_ result: AnalyticsChartResult) -> Bool {
        result.granularity == .daily &&
            [.continuous, .ordinal, .count, .percentage].contains(result.definition.measurementLevel) &&
            result.points.count > 2
    }

    private func selectedPoint(in result: AnalyticsChartResult) -> AnalyticsChartPoint? {
        guard let selectedDate else { return nil }
        return activePoints(result).min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private func chartHeight(_ result: AnalyticsChartResult) -> CGFloat {
        switch result.family {
        case .eventOccurrences: 150
        case .categoricalDistribution, .bristolDistribution:
            max(210, min(320, CGFloat(orderedCategories(result).count) * 38))
        default: 245
        }
    }

    private func orderedCategories(_ result: AnalyticsChartResult) -> [AnalyticsCategoryPoint] {
        let current = result.categories.filter { !$0.isPreviousPeriod }
        guard result.family == .bristolDistribution else {
            return current.sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.category < rhs.category : lhs.count > rhs.count
            }
        }
        let byType = Dictionary(uniqueKeysWithValues: current.map { ($0.category, $0) })
        return (1...7).map { type in
            byType["Type \(type)"] ?? AnalyticsCategoryPoint(category: "Type \(type)", count: 0, isPreviousPeriod: false)
        }
    }

    private func categoryColor(_ category: String, result: AnalyticsChartResult) -> Color {
        let tint = MetricPresentation.tint(for: result.definition)
        guard result.family == .bristolDistribution,
              let type = Int(category.replacingOccurrences(of: "Type ", with: "")) else { return tint }
        let palette: [Color] = [.indigo.opacity(0.55), .indigo.opacity(0.7), .indigo.opacity(0.88), .cyan, .teal, .blue.opacity(0.75), .blue.opacity(0.55)]
        return palette[max(0, min(6, type - 1))]
    }

    private func categoryAnnotation(_ point: AnalyticsCategoryPoint, all categories: [AnalyticsCategoryPoint]) -> String {
        let total = categories.reduce(0) { $0 + $1.count }
        guard total > 0 else { return "0" }
        let percentage = Int((Double(point.count) / Double(total) * 100).rounded())
        return "\(point.count) · \(percentage)%"
    }

    private func categoryDomain(_ categories: [AnalyticsCategoryPoint]) -> ClosedRange<Int> {
        0...max(1, Int(ceil(Double(categories.map(\.count).max() ?? 1) * 1.35)))
    }

    private func format(_ value: Double, definition: MetricDefinition) -> String {
        if definition.unit == .fluidOunces { return formatHydration(value) }
        let digits = definition.displayFormat.maximumFractionDigits
        return value.formatted(.number.precision(.fractionLength(0...digits))) +
            (definition.displayFormat.suffix ?? unitSuffix(definition.unit))
    }

    private func unitSuffix(_ unit: MetricUnit) -> String {
        switch unit {
        case .percentage: "%"
        case .fluidOunces: " oz"
        case .minutes: " min"
        case .custom(let symbol): " \(symbol)"
        default: ""
        }
    }

    private func displayHydration(_ ounces: Double) -> Double {
        hydrationUnit == .fluidOunces ? ounces : ounces * 29.5735
    }

    private func formatHydration(_ ounces: Double) -> String {
        "\(Int(displayHydration(ounces).rounded())) \(hydrationUnit.symbol)"
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
        case MetricCatalog.mood.id: CloveSymbols.mood
        case MetricCatalog.painLevel.id: CloveSymbols.pain
        case MetricCatalog.energyLevel.id: CloveSymbols.energy
        case MetricCatalog.hydration.id: CloveSymbols.hydration
        case MetricCatalog.bristolStoolType.id, MetricCatalog.bowelMovementFrequency.id: CloveSymbols.bowelMovement
        case MetricCatalog.medicationAdherence.id: CloveSymbols.medication
        case MetricCatalog.flowLevel.id: CloveSymbols.cycle
        default:
            switch definition.category {
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
