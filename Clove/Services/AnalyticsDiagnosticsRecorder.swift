import Foundation

enum AnalyticsDiagnosticArea: String, CaseIterable, Codable, Sendable {
    case insightsHome
    case metricDetail
    case discovery
    case comparison
    case migration
}

enum AnalyticsDiagnosticOutcome: String, CaseIterable, Codable, Sendable {
    case success
    case failure
    case cancelled
}

enum AnalyticsDiagnosticInteraction: String, CaseIterable, Codable, Sendable {
    case openDiscover
    case changeRange
    case rateFinding
    case saveFinding
    case dismissFinding
    case createHypothesis
    case reviewHypothesis
}

enum AnalyticsPerformanceBucket: String, CaseIterable, Codable, Sendable {
    case under100ms
    case under250ms
    case under500ms
    case under1s
    case oneToTwoSeconds
    case overTwoSeconds

    init(duration: TimeInterval) {
        switch duration {
        case ..<0.1: self = .under100ms
        case ..<0.25: self = .under250ms
        case ..<0.5: self = .under500ms
        case ..<1: self = .under1s
        case ..<2: self = .oneToTwoSeconds
        default: self = .overTwoSeconds
        }
    }
}

struct AnalyticsDiagnosticCounter: Codable, Equatable, Sendable {
    let area: AnalyticsDiagnosticArea?
    let outcome: AnalyticsDiagnosticOutcome?
    let interaction: AnalyticsDiagnosticInteraction?
    let performance: AnalyticsPerformanceBucket?
    var count: Int
}

enum AnalyticsDiagnosticSchema {
    static let prohibitedPayloadFields: Set<String> = [
        "metric", "metricName", "metricID", "value", "notes", "date", "insight", "insightText",
        "medication", "food", "symptom", "identifier", "recordID", "userID"
    ]

    static func isAllowed(_ counter: AnalyticsDiagnosticCounter) -> Bool {
        counter.count >= 0 && (counter.area != nil || counter.interaction != nil)
    }
}

final class AnalyticsDiagnosticsRecorder {
    static let shared = AnalyticsDiagnosticsRecorder()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let storageKey = "analyticsDiagnosticCounters.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Constants.LOCAL_ANALYTICS_DIAGNOSTICS: true])
    }

    var isEnabled: Bool {
        get { defaults.object(forKey: Constants.LOCAL_ANALYTICS_DIAGNOSTICS) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Constants.LOCAL_ANALYTICS_DIAGNOSTICS)
            if !newValue { clear() }
        }
    }

    func recordLoad(_ area: AnalyticsDiagnosticArea, outcome: AnalyticsDiagnosticOutcome, duration: TimeInterval) {
        record(AnalyticsDiagnosticCounter(area: area, outcome: outcome, interaction: nil,
            performance: AnalyticsPerformanceBucket(duration: duration), count: 1))
    }

    func recordInteraction(_ interaction: AnalyticsDiagnosticInteraction, area: AnalyticsDiagnosticArea) {
        record(AnalyticsDiagnosticCounter(area: area, outcome: nil, interaction: interaction,
            performance: nil, count: 1))
    }

    func counters() -> [AnalyticsDiagnosticCounter] {
        lock.withLock { read() }
    }

    func clear() {
        lock.withLock { defaults.removeObject(forKey: storageKey) }
    }

    private func record(_ counter: AnalyticsDiagnosticCounter) {
        guard isEnabled, AnalyticsDiagnosticSchema.isAllowed(counter) else { return }
        lock.withLock {
            var values = read()
            if let index = values.firstIndex(where: {
                $0.area == counter.area && $0.outcome == counter.outcome
                    && $0.interaction == counter.interaction && $0.performance == counter.performance
            }) { values[index].count += counter.count }
            else { values.append(counter) }
            if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: storageKey) }
        }
    }

    private func read() -> [AnalyticsDiagnosticCounter] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsDiagnosticCounter].self, from: data)) ?? []
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock(); defer { unlock() }
        return operation()
    }
}
