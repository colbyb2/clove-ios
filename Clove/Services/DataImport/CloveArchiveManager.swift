import CryptoKit
import Foundation
import GRDB

/// A versioned, lossless Clove backup. CSV remains available for spreadsheets,
/// while this archive is the format intended for restoring the app itself.
struct CloveArchive: Codable {
    struct Manifest: Codable {
        let format: String
        let schemaVersion: Int
        let createdAt: Date
        let appVersion: String
    }

    struct Payload: Codable {
        let dailyLogs: [DailyLog]
        let trackedSymptoms: [TrackedSymptom]
        let userSettings: [UserSettings]
        let trackedMedications: [TrackedMedication]
        let medicationHistory: [MedicationHistoryEntry]
        let bowelMovements: [BowelMovement]
        let foodEntries: [FoodEntry]
        let activityCategories: [ActivityCategoryDefinition]?
        let activityEntries: [ActivityEntry]
        let cycles: [Cycle]
        let dynamicMetricIdentities: [DynamicMetricIdentity]
        let metricIdentityAliases: [MetricIdentityAlias]
        let savedAnalyses: [SavedAnalysis]
        let insightFeedback: [InsightFeedback]
        let savedHypotheses: [SavedHypothesis]
        let notifications: [ScheduledNotification]
        let preferences: CloveArchivePreferences
    }

    let manifest: Manifest
    let payload: Payload
    let checksum: String
}

struct CloveArchivePreferences: Codable {
    let selectedColor: String?
    let selectedTimePeriod: String?
    let hydrationGoalOunces: Int?
    let hydrationGoalEnabled: Bool?
    let hydrationUnit: String?
    let hydrationQuickAmountsOunces: [Int]?
    let hydrationQuickAmountsMilliliters: [Int]?
    let useSliderInput: Bool?
    let overviewDashboard: Bool?
    let smartInsights: Bool?
    let metricCharts: Bool?
    let correlations: Bool?
    let unifiedAnalyticsEnabled: Bool?
    let localAnalyticsDiagnostics: Bool?
    let hideInactiveMetrics: Bool?
    let recentMetrics: [String]?
    let dashboardWidgets: Data?
    let mealSuggestions: [String]?
    let activitySuggestions: [String]?
    let medicationSuggestions: [String]?

    static func capture(from defaults: UserDefaults) -> Self {
        Self(
            selectedColor: defaults.string(forKey: Constants.SELECTED_COLOR),
            selectedTimePeriod: defaults.string(forKey: Constants.TIMEPERIOD),
            hydrationGoalOunces: defaults.object(forKey: Constants.HYDRATION_GOAL_OUNCES) as? Int,
            hydrationGoalEnabled: defaults.object(forKey: Constants.HYDRATION_GOAL_ENABLED) as? Bool,
            hydrationUnit: defaults.string(forKey: Constants.HYDRATION_UNIT),
            hydrationQuickAmountsOunces: defaults.array(forKey: Constants.HYDRATION_QUICK_AMOUNTS_OUNCES) as? [Int],
            hydrationQuickAmountsMilliliters: defaults.array(forKey: Constants.HYDRATION_QUICK_AMOUNTS_MILLILITERS) as? [Int],
            useSliderInput: defaults.object(forKey: Constants.USE_SLIDER_INPUT) as? Bool,
            overviewDashboard: defaults.object(forKey: Constants.INSIGHTS_OVERVIEW_DASHBOARD) as? Bool,
            smartInsights: defaults.object(forKey: Constants.INSIGHTS_SMART_INSIGHTS) as? Bool,
            metricCharts: defaults.object(forKey: Constants.INSIGHTS_METRIC_CHARTS) as? Bool,
            correlations: defaults.object(forKey: Constants.INSIGHTS_CORRELATIONS) as? Bool,
            unifiedAnalyticsEnabled: defaults.object(forKey: Constants.UNIFIED_ANALYTICS_ENABLED) as? Bool,
            localAnalyticsDiagnostics: defaults.object(forKey: Constants.LOCAL_ANALYTICS_DIAGNOSTICS) as? Bool,
            hideInactiveMetrics: defaults.object(forKey: Constants.HIDE_INACTIVE_METRICS) as? Bool,
            recentMetrics: defaults.stringArray(forKey: Constants.RECENT_METRICS),
            dashboardWidgets: defaults.data(forKey: "dashboardWidgets"),
            mealSuggestions: defaults.stringArray(forKey: "meals_suggestions"),
            activitySuggestions: defaults.stringArray(forKey: "activities_suggestions"),
            medicationSuggestions: defaults.stringArray(forKey: "medications_suggestions")
        )
    }

    func restore(to defaults: UserDefaults) {
        set(selectedColor, forKey: Constants.SELECTED_COLOR, in: defaults)
        set(selectedTimePeriod, forKey: Constants.TIMEPERIOD, in: defaults)
        set(hydrationGoalOunces, forKey: Constants.HYDRATION_GOAL_OUNCES, in: defaults)
        set(hydrationGoalEnabled, forKey: Constants.HYDRATION_GOAL_ENABLED, in: defaults)
        set(hydrationUnit, forKey: Constants.HYDRATION_UNIT, in: defaults)
        set(hydrationQuickAmountsOunces, forKey: Constants.HYDRATION_QUICK_AMOUNTS_OUNCES, in: defaults)
        set(hydrationQuickAmountsMilliliters, forKey: Constants.HYDRATION_QUICK_AMOUNTS_MILLILITERS, in: defaults)
        set(useSliderInput, forKey: Constants.USE_SLIDER_INPUT, in: defaults)
        set(overviewDashboard, forKey: Constants.INSIGHTS_OVERVIEW_DASHBOARD, in: defaults)
        set(smartInsights, forKey: Constants.INSIGHTS_SMART_INSIGHTS, in: defaults)
        set(metricCharts, forKey: Constants.INSIGHTS_METRIC_CHARTS, in: defaults)
        set(correlations, forKey: Constants.INSIGHTS_CORRELATIONS, in: defaults)
        set(unifiedAnalyticsEnabled, forKey: Constants.UNIFIED_ANALYTICS_ENABLED, in: defaults)
        set(localAnalyticsDiagnostics, forKey: Constants.LOCAL_ANALYTICS_DIAGNOSTICS, in: defaults)
        set(hideInactiveMetrics, forKey: Constants.HIDE_INACTIVE_METRICS, in: defaults)
        set(recentMetrics, forKey: Constants.RECENT_METRICS, in: defaults)
        set(dashboardWidgets, forKey: "dashboardWidgets", in: defaults)
        set(mealSuggestions, forKey: "meals_suggestions", in: defaults)
        set(activitySuggestions, forKey: "activities_suggestions", in: defaults)
        set(medicationSuggestions, forKey: "medications_suggestions", in: defaults)
    }

    private func set(_ value: Any?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

struct CloveArchiveRestoreResult {
    let dailyLogCount: Int
    let symptomCount: Int
    let medicationCount: Int
    let reminderCount: Int
}

enum CloveArchiveError: LocalizedError {
    case unreadableFile
    case invalidFormat
    case unsupportedVersion(Int)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .unreadableFile: "The backup file could not be read."
        case .invalidFormat: "This is not a valid Clove backup."
        case .unsupportedVersion(let version): "This backup uses unsupported format version \(version)."
        case .checksumMismatch: "The backup appears damaged or incomplete. Nothing was restored."
        }
    }
}

final class CloveArchiveManager {
    static let shared = CloveArchiveManager(
        databaseManager: DatabaseManager.shared,
        analyticsRevisionSource: AnalyticsRevisionSource.shared,
        userDefaults: .standard
    )

    static let formatIdentifier = "com.clove.health-backup"
    static let currentSchemaVersion = 1

    private struct UnsignedArchive: Codable {
        let manifest: CloveArchive.Manifest
        let payload: CloveArchive.Payload
    }

    private let databaseManager: DatabaseManaging
    private let analyticsRevisionSource: any AnalyticsRevisionProviding
    private let userDefaults: UserDefaults
    private let notificationProvider: () -> [ScheduledNotification]
    private let notificationRestorer: ([ScheduledNotification]) -> Void
    private(set) var latestRecoveryCheckpointURL: URL?

    init(
        databaseManager: DatabaseManaging,
        analyticsRevisionSource: any AnalyticsRevisionProviding = AnalyticsRevisionSource.shared,
        userDefaults: UserDefaults = .standard,
        notificationProvider: (() -> [ScheduledNotification])? = nil,
        notificationRestorer: (([ScheduledNotification]) -> Void)? = nil
    ) {
        self.databaseManager = databaseManager
        self.analyticsRevisionSource = analyticsRevisionSource
        self.userDefaults = userDefaults
        self.notificationProvider = notificationProvider ?? { NotificationStore.shared.notifications }
        self.notificationRestorer = notificationRestorer ?? Self.restoreNotifications
    }

    func createArchiveFile() throws -> URL {
        let archive = try makeArchive()
        let data = try Self.encoder(prettyPrinted: true).encode(archive)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clove-backup-\(formatter.string(from: archive.manifest.createdAt)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Creates and validates a durable snapshot before any replacement operation.
    /// If this fails, callers must not modify existing data.
    func createRecoveryCheckpoint() throws -> URL {
        let archive = try makeArchive()
        let data = try Self.encoder(prettyPrinted: true).encode(archive)
        _ = try Self.decodeAndValidate(data)

        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Clove/Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("clove-recovery-checkpoint.json")
        try data.write(to: url, options: .atomic)

        let writtenData = try Data(contentsOf: url)
        _ = try Self.decodeAndValidate(writtenData)
        latestRecoveryCheckpointURL = url
        return url
    }

    static func validateArchiveFile(at url: URL) throws {
        _ = try decodeAndValidate(Data(contentsOf: url))
    }

    func makeArchive() throws -> CloveArchive {
        let notifications = notificationProvider()
        let preferences = CloveArchivePreferences.capture(from: userDefaults)
        let payload = try databaseManager.read { db in
            CloveArchive.Payload(
                dailyLogs: try DailyLog.fetchAll(db),
                trackedSymptoms: try TrackedSymptom.fetchAll(db),
                userSettings: try UserSettings.fetchAll(db),
                trackedMedications: try TrackedMedication.fetchAll(db),
                medicationHistory: try MedicationHistoryEntry.fetchAll(db),
                bowelMovements: try BowelMovement.fetchAll(db),
                foodEntries: try FoodEntry.fetchAll(db),
                activityCategories: try ActivityCategoryDefinition.fetchAll(db),
                activityEntries: try ActivityEntry.fetchAll(db),
                cycles: try Cycle.fetchAll(db),
                dynamicMetricIdentities: try DynamicMetricIdentity.fetchAll(db),
                metricIdentityAliases: try MetricIdentityAlias.fetchAll(db),
                savedAnalyses: try SavedAnalysis.fetchAll(db),
                insightFeedback: try InsightFeedback.fetchAll(db),
                savedHypotheses: try SavedHypothesis.fetchAll(db),
                notifications: notifications,
                preferences: preferences
            )
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let manifest = CloveArchive.Manifest(
            format: Self.formatIdentifier,
            schemaVersion: Self.currentSchemaVersion,
            createdAt: Date(),
            appVersion: version
        )
        let unsigned = UnsignedArchive(manifest: manifest, payload: payload)
        return CloveArchive(manifest: manifest, payload: payload, checksum: try Self.checksum(for: unsigned))
    }

    func restoreArchive(from fileURL: URL) throws -> CloveArchiveRestoreResult {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: fileURL) else { throw CloveArchiveError.unreadableFile }
        return try restoreArchive(data: data)
    }

    func restoreArchive(data: Data) throws -> CloveArchiveRestoreResult {
        let archive = try Self.decodeAndValidate(data)
        _ = try createRecoveryCheckpoint()

        try databaseManager.writeReturning { db in
            try Self.clearRestorableTables(in: db)
            try Self.insert(archive.payload.dynamicMetricIdentities, into: db)
            try Self.insert(archive.payload.trackedSymptoms, into: db)
            try Self.insert(archive.payload.trackedMedications, into: db)
            try Self.insert(archive.payload.userSettings, into: db)
            for log in archive.payload.dailyLogs {
                try log.upsert(db)
            }
            try Self.insert(archive.payload.medicationHistory, into: db)
            try Self.insert(archive.payload.bowelMovements, into: db)
            try Self.insert(archive.payload.foodEntries, into: db)
            try Self.insert(archive.payload.activityCategories ?? ActivityCategoryDefinition.presets, into: db)
            try Self.insert(archive.payload.activityEntries, into: db)
            try Self.insert(archive.payload.cycles, into: db)
            try Self.insert(archive.payload.metricIdentityAliases, into: db)
            try Self.insert(archive.payload.savedAnalyses, into: db)
            try Self.insert(archive.payload.insightFeedback, into: db)
            try Self.insert(archive.payload.savedHypotheses, into: db)
        }

        archive.payload.preferences.restore(to: userDefaults)
        if let selectedColor = archive.payload.preferences.selectedColor,
           let restoredColor = selectedColor.toColor() {
            Theme.shared.accent = restoredColor
        }
        notificationRestorer(archive.payload.notifications)
        analyticsRevisionSource.bump(reason: .dataImport)

        return CloveArchiveRestoreResult(
            dailyLogCount: archive.payload.dailyLogs.count,
            symptomCount: archive.payload.trackedSymptoms.count,
            medicationCount: archive.payload.trackedMedications.count,
            reminderCount: archive.payload.notifications.count
        )
    }

    private static func restoreNotifications(_ notifications: [ScheduledNotification]) {
        NotificationManager.shared.cancelAllNotifications()
        NotificationStore.shared.notifications = notifications
        NotificationStore.shared.saveNotifications()
        for notification in notifications where notification.isEnabled {
            NotificationManager.shared.scheduleRepeatingNotification(
                id: notification.id,
                title: notification.title,
                body: notification.body,
                hour: notification.hour,
                minute: notification.minute,
                weekdays: notification.weekdays
            )
        }
    }

    private static func clearRestorableTables(in db: Database) throws {
        // Child/reference-bearing tables are removed before their identities.
        let tables = [
            "foodEntry", "activityEntry", "activityCategory", "metricIdentityAlias", "dynamicMetricIdentity",
            "dailyLog", "medicationHistoryEntry", "trackedMedication", "trackedSymptom",
            "bowelMovement", "cycle", "savedAnalysis", "insightFeedback", "savedHypothesis",
            "userSettings"
        ]
        for table in tables {
            try db.execute(sql: "DELETE FROM \(table)")
        }
    }

    private static func insert<Record: PersistableRecord>(_ records: [Record], into db: Database) throws {
        for record in records { try record.insert(db) }
    }

    private static func checksum(for archive: UnsignedArchive) throws -> String {
        let data = try encoder().encode(archive)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func decodeAndValidate(_ data: Data) throws -> CloveArchive {
        let archive: CloveArchive
        do {
            archive = try decoder().decode(CloveArchive.self, from: data)
        } catch {
            throw CloveArchiveError.invalidFormat
        }
        guard archive.manifest.format == formatIdentifier else { throw CloveArchiveError.invalidFormat }
        guard archive.manifest.schemaVersion == currentSchemaVersion else {
            throw CloveArchiveError.unsupportedVersion(archive.manifest.schemaVersion)
        }
        let unsigned = UnsignedArchive(manifest: archive.manifest, payload: archive.payload)
        guard try checksum(for: unsigned) == archive.checksum else {
            throw CloveArchiveError.checksumMismatch
        }
        return archive
    }

    private static func encoder(prettyPrinted: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
