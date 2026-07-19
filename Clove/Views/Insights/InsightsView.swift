import SwiftUI

@MainActor
@Observable
final class InsightsHomeViewModel {
    enum State { case idle, loading, loaded, failed(String) }

    var state: State = .idle
    var period: TimePeriod = TimePeriodManager.shared.selectedPeriod
    var customInterval: DateInterval? = TimePeriodManager.shared.isUsingCustomRange
        ? TimePeriodManager.shared.customRange
        : nil
    var dataset: AnalyticsDataset?
    var summaries: [MetricID: MetricAnalysisSummary] = [:]
    var insights: [HealthInsight] = []
    var snapshot: WellbeingSnapshot?
    var savedAnalyses: [SavedAnalysis] = []
    var providers: [String: any MetricProvider] = [:]
    var discoveryRun: DiscoveryRun?
    var contextAnalysis: ContextAnalysisResult?
    var baselines: [PersonalBaseline] = []
    var insightFeedback: [String: InsightFeedback] = [:]
    var hypotheses: [SavedHypothesis] = []

    var rangeLoadKey: String {
        if let customInterval {
            return "custom|\(customInterval.start.timeIntervalSinceReferenceDate)|\(customInterval.end.timeIntervalSinceReferenceDate)"
        }
        return period.rawValue
    }

    func selectPeriod(_ newPeriod: TimePeriod) {
        customInterval = nil
        period = newPeriod
        TimePeriodManager.shared.selectedPeriod = newPeriod
    }

    func selectCustomRange(_ interval: DateInterval) {
        customInterval = interval
        TimePeriodManager.shared.setCustomRange(interval)
    }

    func load() async {
        let started = Date()
        state = .loading
        do {
            let factory = AnalyticsDateRangeFactory()
            let interval: DateInterval
            if let customInterval {
                TimePeriodManager.shared.setCustomRange(customInterval)
                interval = customInterval
            } else {
                TimePeriodManager.shared.selectedPeriod = period
                interval = factory.interval(for: period)
            }
            let current = try await AnalyticsRepositoryContainer.shared.load(
                AnalyticsRequest(interval: interval, includeRawEvents: true),
                granularity: AnalyticsChartPipeline().granularity(for: interval)
            )
            let previous: AnalyticsDataset?
            if let previousInterval = factory.previous(equalTo: interval), customInterval != nil || period != .allTime {
                previous = try await AnalyticsRepositoryContainer.shared.load(
                    AnalyticsRequest(interval: previousInterval, includeRawEvents: true),
                    granularity: AnalyticsChartPipeline().granularity(for: previousInterval)
                )
            } else {
                previous = nil
            }

            dataset = current
            summaries = Dictionary(uniqueKeysWithValues: current.definitions.map { definition in
                (definition.id, MetricAnalysisSummaryEngine().summarize(
                    definition: definition, dataset: current, previousDataset: previous
                ))
            })
            insights = InsightGenerator().generate(dataset: current, previous: previous)
            snapshot = WellbeingSnapshotEngine().build(current: current, previous: previous)
            discoveryRun = AutomaticDiscoveryEngine().scan(dataset: current)
            let cycleStarts = CycleRepo.shared.getAllCycles().filter(\.isStartOfCycle).map(\.date)
            contextAnalysis = ContextAnalysisEngine().analyze(dataset: current, recordedCycleStarts: cycleStarts)
            baselines = current.definitions.compactMap { definition in
                PersonalBaselineEngine().build(definition: definition, observations: current.observations(for: definition.id))
            }.sorted { lhs, rhs in
                if lhs.position == .typical, rhs.position != .typical { return false }
                if lhs.position != .typical, rhs.position == .typical { return true }
                return abs(lhs.difference) > abs(rhs.difference)
            }
            savedAnalyses = (try? SavedAnalysisRepo().fetchAll()) ?? []
            reloadAdvancedPersistence()
            let available = await MetricRegistry.shared.getAllAvailableMetrics()
            providers = Dictionary(uniqueKeysWithValues: available.map {
                ($0.catalogMetricDefinition?.id.rawValue ?? $0.id, $0)
            })
            state = .loaded
            AnalyticsDiagnosticsRecorder.shared.recordLoad(.insightsHome, outcome: .success,
                duration: Date().timeIntervalSince(started))
        } catch is CancellationError {
            AnalyticsDiagnosticsRecorder.shared.recordLoad(.insightsHome, outcome: .cancelled,
                duration: Date().timeIntervalSince(started))
        } catch {
            state = .failed(error.localizedDescription)
            AnalyticsDiagnosticsRecorder.shared.recordLoad(.insightsHome, outcome: .failure,
                duration: Date().timeIntervalSince(started))
        }
    }

    var comparableChanges: [(MetricDefinition, MetricPeriodComparison)] {
        guard let dataset else { return [] }
        return summaries.values.compactMap { summary in
            guard let comparison = summary.comparison,
                  let definition = dataset.definitions.first(where: { $0.id == summary.metricID }) else { return nil }
            return (definition, comparison)
        }.sorted { abs($0.1.absoluteChange ?? 0) > abs($1.1.absoluteChange ?? 0) }
    }

    var trackedCoverage: [(MetricDefinition, MetricCoverage)] {
        guard let dataset else { return [] }
        return dataset.definitions.compactMap { definition in
            dataset.coverage[definition.id].map { (definition, $0) }
        }.filter { $0.1.sourceDayCount > 0 }
            .sorted { $0.1.observedDayFraction < $1.1.observedDayFraction }
    }

    var averageCoverage: Double? {
        guard !trackedCoverage.isEmpty else { return nil }
        return trackedCoverage.map { $0.1.observedDayFraction }.reduce(0, +) / Double(trackedCoverage.count)
    }

    func provider(for id: MetricID) -> (any MetricProvider)? {
        provider(forRawID: id.rawValue)
    }

    func provider(forRawID id: String?) -> (any MetricProvider)? {
        guard let id else { return defaultProvider }

        // An explicit metric selection must never silently become another metric.
        // Providers are keyed by their canonical catalog ID during `load()`, so use
        // that exact match first and retain the value scan only for legacy aliases.
        return providers[id] ?? providers.values.first {
            $0.id == id || $0.catalogMetricDefinition?.id.rawValue == id
        }
    }

    var defaultProvider: (any MetricProvider)? {
        providers.values.first(where: { $0.id == MetricCatalog.mood.id.rawValue })
            ?? providers.values.sorted { $0.displayName < $1.displayName }.first
    }

    var visibleDiscoveries: [AutomaticDiscovery] {
        let now = Date()
        return discoveryRun?.discoveries.filter { discovery in
            !(insightFeedback[discovery.id]?.isDismissed(at: now) ?? false)
        } ?? []
    }

    func feedback(for insightID: String) -> InsightFeedback {
        insightFeedback[insightID] ?? InsightFeedback(insightID: insightID)
    }

    func setRating(_ rating: InsightFeedbackRating?, for insightID: String) {
        var value = feedback(for: insightID)
        value.feedbackRating = value.feedbackRating == rating ? nil : rating
        save(value)
        AnalyticsDiagnosticsRecorder.shared.recordInteraction(.rateFinding, area: .discovery)
    }

    func toggleSaved(_ insightID: String) {
        var value = feedback(for: insightID)
        value.isSaved.toggle()
        save(value)
        AnalyticsDiagnosticsRecorder.shared.recordInteraction(.saveFinding, area: .discovery)
    }

    func dismiss(_ insightID: String, days: Int = 30) {
        var value = feedback(for: insightID)
        value.dismissedUntil = Calendar.current.date(byAdding: .day, value: days, to: Date())
        save(value)
        AnalyticsDiagnosticsRecorder.shared.recordInteraction(.dismissFinding, area: .discovery)
    }

    func addHypothesis(title: String, factorID: String, outcomeID: String, notes: String, reviewDays: Int) {
        guard factorID != outcomeID, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = try? AdvancedInsightRepo().saveHypothesis(SavedHypothesis(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), factorMetricID: factorID,
            outcomeMetricID: outcomeID, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            reviewIntervalDays: reviewDays
        ))
        reloadAdvancedPersistence()
        AnalyticsDiagnosticsRecorder.shared.recordInteraction(.createHypothesis, area: .discovery)
    }

    func deleteHypothesis(_ hypothesis: SavedHypothesis) {
        guard let id = hypothesis.id else { return }
        try? AdvancedInsightRepo().deleteHypothesis(id: id)
        reloadAdvancedPersistence()
    }

    func markReviewed(_ hypothesis: SavedHypothesis) {
        guard let id = hypothesis.id else { return }
        try? AdvancedInsightRepo().markHypothesisReviewed(id: id, at: Date())
        reloadAdvancedPersistence()
        AnalyticsDiagnosticsRecorder.shared.recordInteraction(.reviewHypothesis, area: .discovery)
    }

    private func save(_ feedback: InsightFeedback) {
        guard let stored = try? AdvancedInsightRepo().saveFeedback(feedback) else { return }
        insightFeedback[stored.insightID] = stored
    }

    private func reloadAdvancedPersistence() {
        let records = (try? AdvancedInsightRepo().fetchFeedback()) ?? []
        insightFeedback = Dictionary(uniqueKeysWithValues: records.map { ($0.insightID, $0) })
        hypotheses = (try? AdvancedInsightRepo().fetchHypotheses()) ?? []
    }
}

struct InsightsView: View {
    @State private var viewModel = InsightsHomeViewModel()
    @AppStorage(Constants.INSIGHTS_OVERVIEW_DASHBOARD) private var overviewDashboard = true
    @AppStorage(Constants.INSIGHTS_SMART_INSIGHTS) private var smartInsights = true
    @AppStorage(Constants.INSIGHTS_METRIC_CHARTS) private var metricCharts = true
    @AppStorage(Constants.INSIGHTS_CORRELATIONS) private var correlations = true
    @AppStorage(Constants.UNIFIED_ANALYTICS_ENABLED) private var unifiedAnalyticsEnabled = true
    @State private var showingCustomRange = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        if unifiedAnalyticsEnabled {
            insightsContent
        } else {
            NavigationStack {
                ContentUnavailableView {
                    Label("Insights Temporarily Disabled", systemImage: "chart.xyaxis.line")
                } description: {
                    Text("Your tracked records are unchanged. Re-enable the unified Insights experience when you’re ready.")
                } actions: {
                    Button("Enable Insights") { unifiedAnalyticsEnabled = true }
                        .buttonStyle(.borderedProminent).tint(Theme.shared.accent)
                }
                .navigationTitle("Insights")
            }
        }
    }

    private var insightsContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CloveSpacing.medium) {
                    compactRangePicker
                    switch viewModel.state {
                    case .idle, .loading:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 260)
                    case .failed(let message):
                        ContentUnavailableView("Unable to Load Insights", systemImage: "exclamationmark.triangle",
                            description: Text(message)).frame(minHeight: 260)
                    case .loaded:
                        dashboardGrid
                    }
                }
                .padding(CloveSpacing.large)
                .padding(.bottom, 80)
            }
            .background(CloveColors.background.ignoresSafeArea())
            .navigationTitle("Insights")
            .refreshable { await viewModel.load() }
            .task(id: viewModel.rangeLoadKey) { await viewModel.load() }
            .sheet(isPresented: $showingCustomRange) {
                CustomDateRangeSheet(initialRange: viewModel.customInterval) { interval in
                    viewModel.selectCustomRange(interval)
                }
            }
        }
    }

    private var compactRangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases) { period in
                        Button(period.shortDisplayName) { viewModel.selectPeriod(period) }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .tint(viewModel.customInterval == nil && viewModel.period == period ? Theme.shared.accent : CloveColors.card)
                            .foregroundStyle(viewModel.customInterval == nil && viewModel.period == period ? .white : CloveColors.primaryText)
                    }
                    Button { showingCustomRange = true } label: {
                        Label("Custom", systemImage: "calendar")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(viewModel.customInterval != nil ? Theme.shared.accent : CloveColors.card)
                    .foregroundStyle(viewModel.customInterval != nil ? .white : CloveColors.primaryText)
                }
            }
            if let interval = viewModel.customInterval {
                Label(customRangeText(interval), systemImage: "calendar.badge.checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.shared.accent)
            }
        }
    }

    private func customRangeText(_ interval: DateInterval) -> String {
        let inclusiveEnd = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(inclusiveEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private var dashboardGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if metricCharts {
                NavigationLink(destination: MetricExplorerDashboardView(viewModel: viewModel)) {
                    dashboardCard(title: "Metrics", value: "\(viewModel.providers.count)", caption: "with data",
                                  icon: "chart.xyaxis.line", color: Theme.shared.accent)
                }
            }
            if overviewDashboard {
                NavigationLink(destination: WellbeingSnapshotDetailView(snapshot: viewModel.snapshot)) {
                    dashboardCard(title: "Snapshot", value: "\(viewModel.snapshot?.availableComponents.count ?? 0)/5",
                                  caption: "available", icon: "heart.text.square.fill", color: .pink)
                }
            }
            NavigationLink(destination: MetricChangesDetailView(viewModel: viewModel)) {
                dashboardCard(title: "Changes", value: "\(viewModel.comparableChanges.count)", caption: "compared",
                              icon: "arrow.up.arrow.down", color: .blue)
            }
            if smartInsights {
                NavigationLink(destination: AdvancedDiscoveryView(viewModel: viewModel)
                    .onAppear { AnalyticsDiagnosticsRecorder.shared.recordInteraction(.openDiscover, area: .discovery) }) {
                    dashboardCard(title: "Discover", value: "\(viewModel.visibleDiscoveries.count)", caption: "new findings",
                                  icon: "sparkles", color: .orange)
                }
            }
            NavigationLink(destination: TrackingCoverageDetailView(coverage: viewModel.trackedCoverage)) {
                dashboardCard(title: "Coverage", value: viewModel.averageCoverage?.formatted(.percent.precision(.fractionLength(0))) ?? "—",
                              caption: "average", icon: "checkmark.circle.fill", color: .green)
            }
            if correlations {
                NavigationLink(destination: CrossReferenceView()) {
                    dashboardCard(title: "Compare", value: "\(viewModel.savedAnalyses.count)", caption: "saved",
                                  icon: "link", color: .purple)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func dashboardCard(title: String, value: String, caption: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.title3.bold()).foregroundStyle(color)
                    .frame(width: 34, height: 34).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CloveColors.secondaryText)
            }
            Spacer(minLength: 2)
            Text(value).font(.title2.bold()).foregroundStyle(CloveColors.primaryText).lineLimit(1)
            HStack(spacing: 4) {
                Text(title).font(.subheadline.bold()).foregroundStyle(CloveColors.primaryText)
                Text("· \(caption)").font(.caption).foregroundStyle(CloveColors.secondaryText).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CloveCorners.medium).fill(CloveColors.card)
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2))
        .contentShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
    }
}

private struct CustomDateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date
    let onApply: (DateInterval) -> Void

    init(initialRange: DateInterval?, onApply: @escaping (DateInterval) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let initialStart = initialRange?.start
            ?? calendar.date(byAdding: .day, value: -29, to: today)
            ?? today
        let initialEnd = initialRange.flatMap {
            calendar.date(byAdding: .day, value: -1, to: $0.end)
        } ?? today
        _startDate = State(initialValue: min(initialStart, today))
        _endDate = State(initialValue: min(initialEnd, today))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Start date",
                        selection: $startDate,
                        in: Date(timeIntervalSince1970: 0)...endDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "End date",
                        selection: $endDate,
                        in: startDate...Calendar.current.startOfDay(for: Date()),
                        displayedComponents: .date
                    )
                } header: {
                    Text("Date Range")
                } footer: {
                    Text("Both the start and end dates are included.")
                }

                Section("Selected Period") {
                    LabeledContent("Length", value: "\(selectedDayCount) days")
                    Text("\(startDate.formatted(date: .long, time: .omitted)) – \(endDate.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                }

                Section {
                    Text("Charts automatically switch between daily, weekly, and monthly summaries based on the length you choose.")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
            .navigationTitle("Custom Time Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var selectedDayCount: Int {
        max(1, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
    }

    private func apply() {
        guard let interval = AnalyticsDateRangeFactory().custom(start: startDate, inclusiveEnd: endDate) else { return }
        onApply(interval)
        dismiss()
    }
}

private struct MetricExplorerDashboardView: View {
    let viewModel: InsightsHomeViewModel
    @State private var selectedMetricID: String?
    @State private var showingPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CloveSpacing.medium) {
                Button { showingPicker = true } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(viewModel.provider(forRawID: selectedMetricID)?.displayName ?? "Choose Metric").bold()
                        Spacer()
                        Text("Browse All").font(.caption.bold())
                    }
                    .padding(CloveSpacing.medium)
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.shared.accent)

                if let provider = viewModel.provider(forRawID: selectedMetricID) {
                    AnalyticsMetricDetailView(metric: provider).id(provider.id)
                } else {
                    ContentUnavailableView("No Metrics Yet", systemImage: "chart.xyaxis.line")
                        .frame(minHeight: 300)
                }
            }
            .padding(CloveSpacing.large)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Metric Explorer")
        .sheet(isPresented: $showingPicker) {
            MetricExplorer { selectedMetricID = $0 }.presentationDragIndicator(.visible)
        }
    }
}

private struct WellbeingSnapshotDetailView: View {
    let snapshot: WellbeingSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot, !snapshot.availableComponents.isEmpty {
                    summaryCard(snapshot)

                    Text("Area by area")
                        .font(.title3.bold())
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        ForEach(snapshot.availableComponents) { component in
                            componentRow(component)
                            if component.id != snapshot.availableComponents.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))

                    DisclosureGroup("How this is calculated") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clove compares the average for each area in the selected period with the immediately preceding period of the same length.")
                            Text("Higher mood, energy, and medication adherence are treated as positive. Lower pain and symptom burden are treated as positive.")
                            Text("Symptoms combines the symptom ratings you recorded. Missing days are left out rather than counted as zero.")
                            ForEach(snapshot.limitations, id: \.self) { Text("• \($0)") }
                        }
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.secondaryText)
                        .padding(.top, 10)
                    }
                    .padding(16)
                    .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
                } else {
                    ContentUnavailableView("No Snapshot Yet", systemImage: "heart.text.square",
                        description: Text("Record mood, pain, energy, symptoms, or medication adherence."))
                }
            }
            .padding(CloveSpacing.large)
            .padding(.bottom, 80)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Wellbeing Snapshot")
    }

    private func summaryCard(_ snapshot: WellbeingSnapshot) -> some View {
        let comparable = snapshot.availableComponents.filter { $0.change != nil }
        let improved = comparable.filter { effectiveFavorability($0) == .favorable }.count
        let attention = comparable.filter { effectiveFavorability($0) == .unfavorable }.count
        let steady = comparable.count - improved - attention

        return VStack(alignment: .leading, spacing: 14) {
            Label("Your recent wellbeing at a glance", systemImage: "heart.text.square.fill")
                .font(.headline)
                .foregroundStyle(.accent)

            Text(summaryHeadline(improved: improved, attention: attention, comparable: comparable.count))
                .font(.title2.bold())
                .foregroundStyle(CloveColors.primaryText)

            Text(comparisonDescription(snapshot))
                .font(.subheadline)
                .foregroundStyle(CloveColors.secondaryText)

            if !comparable.isEmpty {
                HStack(spacing: 8) {
                    summaryPill("\(improved) improved", systemImage: "arrow.up.right", color: .green)
                    summaryPill("\(attention) attention", systemImage: "exclamationmark", color: .orange)
                    if steady > 0 {
                        summaryPill("\(steady) steady", systemImage: "minus", color: CloveColors.secondaryText)
                    }
                }
            }

            Text("This is a comparison of what you recorded—not a medical score.")
                .font(.caption)
                .foregroundStyle(CloveColors.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }

    private func componentRow(_ component: WellbeingSnapshotComponent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: component.kind))
                .font(.body.bold())
                .foregroundStyle(statusColor(component))
                .frame(width: 34, height: 34)
                .background(statusColor(component).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(component.kind.rawValue).font(.headline)
                    Spacer()
                    statusLabel(component)
                }

                if let value = component.currentValue {
                    Text(valueDescription(value, for: component.kind))
                        .font(.subheadline)
                        .foregroundStyle(CloveColors.primaryText)
                }

                if let change = component.change {
                    Text(changeDescription(change, for: component.kind))
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                } else {
                    Text("No previous period available for comparison")
                        .font(.caption)
                        .foregroundStyle(CloveColors.secondaryText)
                }

                if component.observedDayCount < component.possibleDayCount {
                    Text("Based on \(component.observedDayCount) of \(component.possibleDayCount) days")
                        .font(.caption2)
                        .foregroundStyle(CloveColors.secondaryText)
                }
            }
        }
        .padding(.vertical, 14)
    }

    private func statusLabel(_ component: WellbeingSnapshotComponent) -> some View {
        Text(statusText(component))
            .font(.caption.bold())
            .foregroundStyle(statusColor(component))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(statusColor(component).opacity(0.12), in: Capsule())
    }

    private func summaryPill(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func summaryHeadline(improved: Int, attention: Int, comparable: Int) -> String {
        guard comparable > 0 else { return "Your recent averages" }
        if improved > attention { return "More areas improved than worsened" }
        if attention > improved { return "Some areas may need your attention" }
        if improved == 0 { return "Your wellbeing was mostly steady" }
        return "Your results were mixed"
    }

    private func comparisonDescription(_ snapshot: WellbeingSnapshot) -> String {
        let days = max(1, Calendar.current.dateComponents([.day], from: snapshot.interval.start, to: snapshot.interval.end).day ?? 1)
        guard snapshot.previousInterval != nil else {
            return "A summary of the last \(days) days based on your recorded data."
        }
        return "The last \(days) days compared with the previous \(days) days."
    }

    private func valueDescription(_ value: Double, for kind: WellbeingComponentKind) -> String {
        let formatted = value.formatted(.number.precision(.fractionLength(0...1)))
        switch kind {
        case .adherence: return "Medication taken \(formatted)% of the time"
        case .symptoms: return "Average symptom burden: \(formatted) out of 10"
        case .mood, .pain, .energy: return "Average: \(formatted) out of 10"
        }
    }

    private func changeDescription(_ change: Double, for kind: WellbeingComponentKind) -> String {
        if abs(change) < 0.05 { return "About the same as the previous period" }
        let amount = abs(change).formatted(.number.precision(.fractionLength(0...1)))
        let direction = change > 0 ? "higher" : "lower"
        let unit = kind == .adherence ? "percentage points" : abs(change) == 1 ? "point" : "points"
        return "\(amount) \(unit) \(direction) than the previous period"
    }

    private func statusText(_ component: WellbeingSnapshotComponent) -> String {
        guard component.change != nil else { return "Current" }
        return switch effectiveFavorability(component) {
        case .favorable: "Improved"
        case .unfavorable: "Needs attention"
        case .neutral: "Steady"
        }
    }

    private func statusColor(_ component: WellbeingSnapshotComponent) -> Color {
        guard component.change != nil else { return Theme.shared.accent }
        return switch effectiveFavorability(component) {
        case .favorable: .green
        case .unfavorable: .orange
        case .neutral: CloveColors.secondaryText
        }
    }

    private func effectiveFavorability(_ component: WellbeingSnapshotComponent) -> MetricChangeFavorability {
        guard let change = component.change, abs(change) >= 0.05 else { return .neutral }
        return component.favorability
    }

    private func icon(for kind: WellbeingComponentKind) -> String {
        switch kind {
        case .mood: "face.smiling"
        case .pain: "bolt.heart"
        case .energy: "bolt.fill"
        case .adherence: "pills.fill"
        case .symptoms: "cross.case.fill"
        }
    }
}

private struct MetricChangesDetailView: View {
    let viewModel: InsightsHomeViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.comparableChanges.isEmpty {
                    ContentUnavailableView("Not Enough Comparable Data", systemImage: "arrow.up.arrow.down")
                } else {
                    ForEach(viewModel.comparableChanges, id: \.0.id) { definition, comparison in
                        NavigationLink(destination: AnalyticsMetricDetailScreen(definition: definition)) {
                            row(definition, comparison)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }.padding(CloveSpacing.large)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("What Changed")
    }

    private func row(_ definition: MetricDefinition, _ comparison: MetricPeriodComparison) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.displayName).bold()
                Text("\(comparison.currentCoverage.sourceDayCount) current · \(comparison.previousCoverage.sourceDayCount) prior days")
                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
            }
            Spacer()
            if let change = comparison.absoluteChange {
                Text("\(change >= 0 ? "+" : "")\(change.formatted(.number.precision(.fractionLength(0...1))))").bold()
                    .foregroundStyle(comparison.favorability == .favorable ? .green : comparison.favorability == .unfavorable ? .orange : CloveColors.primaryText)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(CloveColors.secondaryText)
        }
        .padding(CloveSpacing.medium)
        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
    }
}

private struct AnalyticsMetricDetailScreen: View {
    let definition: MetricDefinition

    var body: some View {
        ScrollView {
            AnalyticsMetricDetailView(definition: definition)
                .padding(.horizontal, CloveSpacing.large)
                .padding(.top, CloveSpacing.small)
                .padding(.bottom, 110)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle(definition.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PatternsDetailView: View {
    let insights: [HealthInsight]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if insights.isEmpty {
                    ContentUnavailableView("No Patterns Yet", systemImage: "sparkles",
                        description: Text("More consistent tracking may reveal a repeated pattern."))
                } else {
                    ForEach(insights) { insight in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: insight.typeIcon).foregroundStyle(Theme.shared.accent)
                                Text(insight.title).font(.headline)
                                Spacer()
                                Text(insight.evidence?.quality.rawValue ?? "").font(.caption2).foregroundStyle(CloveColors.secondaryText)
                            }
                            Text(insight.description).font(.subheadline).foregroundStyle(CloveColors.secondaryText)
                            if let evidence = insight.evidence {
                                DisclosureGroup("Evidence") {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(evidence.whyText)
                                        ForEach(evidence.limitations, id: \.self) { Text("• \($0)") }
                                    }.font(.caption).foregroundStyle(CloveColors.secondaryText).padding(.top, 6)
                                }.font(.caption.bold())
                            }
                        }
                        .padding(CloveSpacing.medium)
                        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
                    }
                }
            }.padding(CloveSpacing.large)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Patterns")
    }
}

private struct TrackingCoverageDetailView: View {
    let coverage: [(MetricDefinition, MetricCoverage)]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if coverage.isEmpty {
                    ContentUnavailableView("No Recorded Metrics", systemImage: "checkmark.circle")
                } else {
                    ForEach(coverage, id: \.0.id) { definition, value in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(definition.displayName).bold()
                                Spacer()
                                Text(value.observedDayFraction.formatted(.percent.precision(.fractionLength(0)))).bold()
                            }
                            ProgressView(value: value.observedDayFraction)
                                .tint(value.observedDayFraction < 0.5 ? .orange : Theme.shared.accent)
                            Text("\(value.sourceDayCount) of \(value.possibleDayCount) days")
                                .font(.caption).foregroundStyle(CloveColors.secondaryText)
                        }
                        .padding(CloveSpacing.medium)
                        .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
                    }
                }
            }.padding(CloveSpacing.large)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Tracking Coverage")
    }
}
