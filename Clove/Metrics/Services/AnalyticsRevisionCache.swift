import Foundation

enum AnalyticsRevisionReason: String, Sendable {
    case dailyLog
    case food
    case activity
    case bowelMovement
    case cycle
    case medication
    case symptomDefinition
    case analyticSettings
    case dataImport
}

protocol AnalyticsRevisionProviding: AnyObject {
    var currentRevision: UInt64 { get }
    @discardableResult func bump(reason: AnalyticsRevisionReason) -> UInt64
}

/// Process-lifetime monotonic revision for all inputs that can change an analytics result.
final class AnalyticsRevisionSource: AnalyticsRevisionProviding, @unchecked Sendable {
    static let shared = AnalyticsRevisionSource()

    private let lock = NSLock()
    private var value: UInt64 = 0

    var currentRevision: UInt64 {
        lock.withLock { value }
    }

    @discardableResult
    func bump(reason: AnalyticsRevisionReason) -> UInt64 {
        let revision = lock.withLock {
            value &+= 1
            return value
        }
        AnalyticsInvalidationBridge.invalidateLegacyCaches()
        return revision
    }
}

private enum AnalyticsInvalidationBridge {
    static func invalidateLegacyCaches() {
        Task { await OptimizedDataLoader.shared.clearCache() }
        Task { @MainActor in
            MetricRegistry.shared.invalidateCache()
        }
    }
}

enum AnalyticsGranularity: String, Sendable {
    case daily
    case weekly
    case monthly
}

struct AnalyticsCacheKey: Hashable, Sendable {
    let metricIDs: [String]?
    let intervalStart: TimeInterval
    let intervalEnd: TimeInterval
    let includeRawEvents: Bool
    let granularity: AnalyticsGranularity
    let policyVersion: Int
    let revision: UInt64
}

/// Actor isolation guarantees that identical concurrent requests perform at most one underlying
/// repository load and that cached results never cross a data revision.
actor CachedAnalyticsRepository {
    private let repository: any AnalyticsRepository
    private let revisionSource: any AnalyticsRevisionProviding
    private let policyVersion: Int
    private var cache: [AnalyticsCacheKey: AnalyticsDataset] = [:]

    init(
        repository: any AnalyticsRepository,
        revisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared,
        policyVersion: Int = 1
    ) {
        self.repository = repository
        self.revisionSource = revisionSource
        self.policyVersion = policyVersion
    }

    func load(
        _ request: AnalyticsRequest,
        granularity: AnalyticsGranularity = .daily
    ) throws -> AnalyticsDataset {
        try Task.checkCancellation()
        let key = cacheKey(for: request, granularity: granularity)
        if let cached = cache[key] { return cached }

        let result = try repository.load(request)
        try Task.checkCancellation()
        cache[key] = result
        prune(revision: key.revision)
        return result
    }

    func removeAll() {
        cache.removeAll()
    }

    var cachedResultCount: Int { cache.count }

    private func cacheKey(
        for request: AnalyticsRequest,
        granularity: AnalyticsGranularity
    ) -> AnalyticsCacheKey {
        AnalyticsCacheKey(
            metricIDs: request.metricIDs?.map(\.rawValue).sorted(),
            intervalStart: request.interval.start.timeIntervalSinceReferenceDate,
            intervalEnd: request.interval.end.timeIntervalSinceReferenceDate,
            includeRawEvents: request.includeRawEvents,
            granularity: granularity,
            policyVersion: policyVersion,
            revision: revisionSource.currentRevision
        )
    }

    private func prune(revision: UInt64) {
        cache = cache.filter { $0.key.revision == revision }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
