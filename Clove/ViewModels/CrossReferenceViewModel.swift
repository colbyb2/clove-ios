import Foundation
import SwiftUI

@MainActor
@Observable
final class CrossReferenceViewModel {
    private let metricRegistry: MetricRegistryProtocol
    private let timePeriodManager: TimePeriodManaging
    private let savedRepo: any SavedAnalysisRepository

    var primaryMetric: (any MetricProvider)?
    var secondaryMetric: (any MetricProvider)?
    var currentAnalysis: CorrelationAnalysis?
    var isCalculating = false
    var savedAnalyses: [SavedAnalysis] = []
    var suggestedPairs: [MetricPair] = []
    var availableMetrics: [any MetricProvider] = []
    var errorMessage: String?
    var calculationStep: String?
    var currentCalculationStepIndex = 0
    var selectedLagDays = 0

    // Compatibility for older view components while the comparison screen is migrated.
    var savedCorrelations: [MetricPair] { [] }

    convenience init() {
        self.init(metricRegistry: MetricRegistry.shared, timePeriodManager: TimePeriodManager.shared, savedRepo: SavedAnalysisRepo())
    }

    init(metricRegistry: MetricRegistryProtocol, timePeriodManager: TimePeriodManaging,
         savedRepo: any SavedAnalysisRepository = SavedAnalysisRepo()) {
        self.metricRegistry = metricRegistry
        self.timePeriodManager = timePeriodManager
        self.savedRepo = savedRepo
        Task { await bootstrap() }
    }

    static func preview() -> CrossReferenceViewModel {
        CrossReferenceViewModel(metricRegistry: MockMetricRegistry(), timePeriodManager: MockTimePeriodManager())
    }

    func calculateCorrelation(primary: any MetricProvider, secondary: any MetricProvider) {
        guard primary.id != secondary.id else {
            errorMessage = "Choose two different metrics to compare."
            return
        }
        isCalculating = true
        errorMessage = nil
        calculationStep = "Loading recorded days…"
        Task {
            do {
                let analysis = try await performAnalysis(primary: primary, secondary: secondary)
                currentAnalysis = analysis
                primaryMetric = primary
                secondaryMetric = secondary
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isCalculating = false
            calculationStep = nil
        }
    }

    func selectMetric(id: String, isPrimary: Bool) async {
        guard let metric = await metricRegistry.getMetric(id: id) else {
            errorMessage = "That metric is no longer available. Choose another metric or remove the saved analysis."
            return
        }
        if isPrimary { primaryMetric = metric } else { secondaryMetric = metric }
        if let primaryMetric, let secondaryMetric { calculateCorrelation(primary: primaryMetric, secondary: secondaryMetric) }
    }

    func saveCorrelation(_ analysis: CorrelationAnalysis) {
        do {
            let title = "\(analysis.primaryMetric.displayName) → \(analysis.secondaryMetric.displayName)"
            let saved = SavedAnalysis(
                title: title,
                factorMetricID: analysis.factorDefinition.id.rawValue,
                outcomeMetricID: analysis.outcomeDefinition.id.rawValue,
                rangePolicy: savedRangePolicy,
                method: analysis.estimate?.method.rawValue,
                lagDays: selectedLagDays,
                displayOrder: savedAnalyses.count
            )
            _ = try savedRepo.save(saved)
            loadSavedAnalyses()
        } catch { errorMessage = "Could not save this analysis: \(error.localizedDescription)" }
    }

    func removeSavedAnalysis(_ saved: SavedAnalysis) {
        guard let id = saved.id else { return }
        do { try savedRepo.delete(id: id); loadSavedAnalyses() }
        catch { errorMessage = "Could not delete the saved analysis." }
    }

    func renameSavedAnalysis(_ saved: SavedAnalysis, title: String) {
        guard let id = saved.id, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do { try savedRepo.rename(id: id, title: title); loadSavedAnalyses() }
        catch { errorMessage = "Could not rename the saved analysis." }
    }

    func loadSavedAnalysis(_ saved: SavedAnalysis) {
        Task {
            restoreRangePolicy(saved.rangePolicy)
            let factor = await resolveProvider(saved.factorMetricID)
            let outcome = await resolveProvider(saved.outcomeMetricID)
            guard let factor, let outcome else {
                errorMessage = "One of these metrics is unavailable. You can keep, rename, or delete this saved analysis."
                return
            }
            selectedLagDays = saved.lagDays
            calculateCorrelation(primary: factor, secondary: outcome)
        }
    }

    // Legacy callbacks retained for components still compiled elsewhere.
    func removeSavedCorrelation(_ pair: MetricPair) {}
    func loadSavedCorrelation(_ pair: MetricPair) { calculateCorrelation(primary: pair.primary, secondary: pair.secondary) }

    private func bootstrap() async {
        availableMetrics = await metricRegistry.getAllAvailableMetrics()
        await loadSuggestedCorrelations()
        loadSavedAnalyses()
    }

    private func performAnalysis(primary: any MetricProvider, secondary: any MetricProvider) async throws -> CorrelationAnalysis {
        let interval = timePeriodManager.currentDateRange
            ?? AnalyticsDateRangeFactory().interval(for: timePeriodManager.selectedPeriod)
        let granularity = AnalyticsChartPipeline().granularity(for: interval)
        let dataset = try await AnalyticsRepositoryContainer.shared.load(
            AnalyticsRequest(interval: interval, includeRawEvents: true), granularity: granularity
        )
        guard let factor = resolveDefinition(providerID: primary.id, dataset: dataset),
              let outcome = resolveDefinition(providerID: secondary.id, dataset: dataset) else {
            throw CorrelationError.calculationError
        }

        calculationStep = "Aligning recorded days without filling gaps…"
        let alignment = PairAlignmentEngine().align(factor: factor, outcome: outcome, dataset: dataset, lagDays: selectedLagDays)
        let estimate: RelationshipEstimate?
        let lagProfile: LagRelationshipProfile?
        let eventOutcomes: [EventOutcomeResult]
        if factor.measurementLevel == .event {
            estimate = nil
            lagProfile = nil
            eventOutcomes = [0, 1].map { EventOutcomeEngine().analyze(event: factor, outcome: outcome, dataset: dataset, outcomeOffsetDays: $0) }
            guard eventOutcomes.contains(where: { $0.exposedCount > 0 && $0.controlCount > 0 }) else { throw CorrelationError.insufficientData }
        } else {
            estimate = RelationshipStatisticsEngine().estimate(alignment: alignment, factor: factor, outcome: outcome)
            lagProfile = LaggedRelationshipEngine().analyze(factor: factor, outcome: outcome, dataset: dataset)
            eventOutcomes = []
        }

        let effect = estimate?.effect ?? eventOutcomes.first?.meanDifference ?? 0
        let numericPoints = alignment.pairs.compactMap { pair -> (Date, Double, Double)? in
            guard let lhs = pair.factor.numeric, let rhs = pair.outcome.numeric else { return nil }
            return (pair.factorDay, lhs, rhs)
        }
        let pValue = estimate?.pValue ?? 1
        let intervalDates = alignment.pairs.map(\.factorDay)
        let insights = explanation(factor: factor, outcome: outcome, estimate: estimate, eventOutcomes: eventOutcomes)
        return CorrelationAnalysis(
            primaryMetric: primary, secondaryMetric: secondary,
            factorDefinition: factor, outcomeDefinition: outcome,
            alignment: alignment, estimate: estimate, lagProfile: lagProfile, eventOutcomes: eventOutcomes,
            coefficient: effect, significance: 1 - pValue, pValue: pValue, dataPoints: numericPoints,
            timeRange: DateInterval(start: intervalDates.min() ?? interval.start, end: intervalDates.max() ?? interval.end),
            strengthDescription: estimate?.strength ?? "Event comparison", insights: insights
        )
    }

    private func explanation(factor: MetricDefinition, outcome: MetricDefinition, estimate: RelationshipEstimate?,
                             eventOutcomes: [EventOutcomeResult]) -> [String] {
        if let estimate, let effect = estimate.effect {
            let direction = estimate.method.signed ? (effect >= 0 ? "move in the same direction" : "move in opposite directions") : "vary together"
            return ["On matching recorded days, \(factor.displayName) and \(outcome.displayName) tend to \(direction).",
                    "This pattern is an association and does not show that one metric causes the other."]
        }
        if let event = eventOutcomes.first, let difference = event.meanDifference {
            return ["On event days, \(outcome.displayName) averaged \(String(format: "%.1f", abs(difference))) \(difference >= 0 ? "higher" : "lower") than eligible control days.",
                    "This event comparison describes an association, not causation."]
        }
        return ["More matching recorded days are needed before estimating this relationship."]
    }

    private func resolveDefinition(providerID: String, dataset: AnalyticsDataset) -> MetricDefinition? {
        let id = MetricID(rawValue: providerID)
        if let exact = dataset.definitions.first(where: { $0.id == id }) { return exact }
        if let aliases = dataset.metricAliases[providerID], aliases.count == 1, let canonical = aliases.first {
            return dataset.definitions.first { $0.id == canonical }
        }
        return dataset.definitions.first { $0.displayName.caseInsensitiveCompare(providerID.replacingOccurrences(of: "_", with: " ")) == .orderedSame }
    }

    private var savedRangePolicy: String {
        guard timePeriodManager.isUsingCustomRange, let range = timePeriodManager.currentDateRange else {
            return timePeriodManager.selectedPeriod.rawValue
        }
        return [
            "custom",
            String(range.start.timeIntervalSinceReferenceDate),
            String(range.end.timeIntervalSinceReferenceDate)
        ].joined(separator: "|")
    }

    private func restoreRangePolicy(_ policy: String) {
        if let period = TimePeriod(rawValue: policy) {
            timePeriodManager.selectedPeriod = period
            return
        }
        let parts = policy.split(separator: "|")
        guard parts.count == 3, parts[0] == "custom",
              let start = Double(parts[1]), let end = Double(parts[2]), start < end else { return }
        timePeriodManager.setCustomRange(DateInterval(
            start: Date(timeIntervalSinceReferenceDate: start),
            end: Date(timeIntervalSinceReferenceDate: end)
        ))
    }

    private func resolveProvider(_ persistedID: String) async -> (any MetricProvider)? {
        if let exact = await metricRegistry.getMetric(id: persistedID) { return exact }
        if let canonicalProvider = availableMetrics.first(where: { $0.catalogMetricDefinition?.id.rawValue == persistedID }) {
            return canonicalProvider
        }
        let interval = timePeriodManager.currentDateRange
            ?? AnalyticsDateRangeFactory().interval(for: timePeriodManager.selectedPeriod)
        let granularity = AnalyticsChartPipeline().granularity(for: interval)
        guard let dataset = try? await AnalyticsRepositoryContainer.shared.load(
            AnalyticsRequest(interval: interval, includeRawEvents: false), granularity: granularity
        ), let aliases = dataset.metricAliases[persistedID], aliases.count == 1, let canonicalID = aliases.first else { return nil }
        return availableMetrics.first { $0.catalogMetricDefinition?.id == canonicalID }
    }

    private func loadSavedAnalyses() {
        do { savedAnalyses = try savedRepo.fetchAll() }
        catch { savedAnalyses = [] }
    }

    private func loadSuggestedCorrelations() async {
        let ids = [("mood", "pain_level"), ("energy_level", "mood"), ("pain_level", "energy_level")]
        var pairs: [MetricPair] = []
        for ids in ids {
            if let factor = await metricRegistry.getMetric(id: ids.0), let outcome = await metricRegistry.getMetric(id: ids.1) {
                pairs.append(MetricPair(primary: factor, secondary: outcome, correlationStrength: 0, lastAnalyzed: Date()))
            }
        }
        suggestedPairs = pairs
    }
}
