import SwiftUI

@MainActor
@Observable
final class InsightsHomeViewModel {
    enum State { case idle, loading, loaded, failed(String) }

    var state: State = .idle
    var period: TimePeriod = TimePeriodManager.shared.selectedPeriod
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

    func load() async {
        let started = Date()
        state = .loading
        TimePeriodManager.shared.selectedPeriod = period
        do {
            let factory = AnalyticsDateRangeFactory()
            let interval = factory.interval(for: period)
            let current = try await AnalyticsRepositoryContainer.shared.load(
                AnalyticsRequest(interval: interval, includeRawEvents: true),
                granularity: AnalyticsChartPipeline().granularity(for: interval)
            )
            let previous: AnalyticsDataset?
            if let previousInterval = factory.previous(equalTo: interval), period != .allTime {
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

    func provider(for id: MetricID) -> (any MetricProvider)? { provider(forRawID: id.rawValue) }

    func provider(forRawID id: String?) -> (any MetricProvider)? {
        guard let id else { return defaultProvider }
        return providers.values.first {
            $0.id == id || $0.catalogMetricDefinition?.id.rawValue == id
        } ?? defaultProvider
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
            .task(id: viewModel.period) { await viewModel.load() }
        }
    }

    private var compactRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimePeriod.allCases) { period in
                    Button(period.shortDisplayName) { viewModel.period = period }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(viewModel.period == period ? Theme.shared.accent : CloveColors.card)
                        .foregroundStyle(viewModel.period == period ? .white : CloveColors.primaryText)
                }
            }
        }
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
            VStack(spacing: 0) {
                if let snapshot, !snapshot.availableComponents.isEmpty {
                    ForEach(snapshot.components) { component in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(component.kind.rawValue).font(.headline)
                                Text("\(component.observedDayCount)/\(component.possibleDayCount) days · \(component.weight.formatted(.percent.precision(.fractionLength(0)))) weight")
                                    .font(.caption).foregroundStyle(CloveColors.secondaryText)
                            }
                            Spacer()
                            if let value = component.currentValue {
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(component.unitLabel)").bold()
                                    if let change = component.change {
                                        Text("\(change >= 0 ? "+" : "")\(change.formatted(.number.precision(.fractionLength(0...1)))) vs prior")
                                            .font(.caption).foregroundStyle(component.favorability == .favorable ? .green : component.favorability == .unfavorable ? .orange : CloveColors.secondaryText)
                                    }
                                }
                            } else {
                                Text("Not recorded").foregroundStyle(CloveColors.secondaryText)
                            }
                        }
                        .padding(.vertical, 14)
                        if component.id != snapshot.components.last?.id { Divider() }
                    }
                    DisclosureGroup("How this is calculated") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(snapshot.limitations, id: \.self) { Text("• \($0)") }
                        }.font(.caption).foregroundStyle(CloveColors.secondaryText).padding(.top, 8)
                    }
                    .padding(.top, 18)
                } else {
                    ContentUnavailableView("No Snapshot Yet", systemImage: "heart.text.square",
                        description: Text("Record mood, pain, energy, symptoms, or medication adherence."))
                }
            }
            .padding(CloveSpacing.large)
            .background(CloveColors.card, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
            .padding(CloveSpacing.large)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle("Wellbeing Snapshot")
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
                        Group {
                            if let provider = viewModel.provider(for: definition.id) {
                                NavigationLink(destination: AnalyticsMetricDetailScreen(metric: provider)) {
                                    row(definition, comparison)
                                }
                            } else { row(definition, comparison) }
                        }.buttonStyle(.plain)
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
    let metric: any MetricProvider

    var body: some View {
        ScrollView {
            AnalyticsMetricDetailView(metric: metric)
                .padding(.horizontal, CloveSpacing.large)
                .padding(.top, CloveSpacing.small)
                .padding(.bottom, 110)
        }
        .background(CloveColors.background.ignoresSafeArea())
        .navigationTitle(metric.displayName)
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
