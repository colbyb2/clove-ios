import Foundation
import GRDB

// MARK: - Optimized Data Loader

/// Efficient data loader that batches database queries and implements smart caching
actor OptimizedDataLoader {
    static let shared = OptimizedDataLoader()
    
    // MARK: - Cache Properties
    
    private var cachedLogs: [TimePeriod: [DailyLog]] = [:]
    private var cacheTimestamps: [TimePeriod: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Shared logs cache for current session
    private var sessionLogs: [DailyLog]?
    private var sessionLogsTimestamp: Date = .distantPast
    private let sessionCacheTimeout: TimeInterval = 60 // 1 minute
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get logs for a specific time period with caching
    func getLogsForPeriod(_ period: TimePeriod) async -> [DailyLog] {
        // Check cache first
        if let cachedData = getCachedLogs(for: period) {
            return cachedData
        }
        
        // Load from database
        let logs = await loadLogsFromDatabase(for: period)
        setCachedLogs(logs, for: period)
        return logs
    }
    
    /// Get all logs with session-level caching (for multiple metrics accessing same data)
    func getAllLogsForSession() async -> [DailyLog] {
        // Check session cache
        if let sessionLogs = sessionLogs,
           Date().timeIntervalSince(sessionLogsTimestamp) < sessionCacheTimeout {
            return sessionLogs
        }
        
        // Load all logs from database
        let logs = await loadAllLogsFromDatabase()
        sessionLogs = logs
        sessionLogsTimestamp = Date()
        return logs
    }
    
    /// Filter logs by period from session cache (more efficient when accessing multiple metrics)
    func filterSessionLogs(for period: TimePeriod) async -> [DailyLog] {
        let allLogs = await getAllLogsForSession()
        
        guard period != .allTime, let dateRange = period.dateRange else {
            return allLogs.sorted { $0.date < $1.date }
        }
        
        return allLogs.filter { log in
            dateRange.contains(log.date)
        }.sorted { $0.date < $1.date }
    }
    
    /// Get data point count for a specific condition (optimized query)
    func getDataPointCount(where condition: @escaping (DailyLog) -> Bool) async -> Int {
        let logs = await getAllLogsForSession()
        return logs.filter(condition).count
    }
    
    /// Get data point count for a time period with condition
    func getDataPointCount(for period: TimePeriod, where condition: @escaping (DailyLog) -> Bool) async -> Int {
        let logs = await filterSessionLogs(for: period)
        return logs.filter(condition).count
    }
    
    /// Clear all caches
    func clearCache() {
        cachedLogs.removeAll()
        cacheTimestamps.removeAll()
        sessionLogs = nil
        sessionLogsTimestamp = .distantPast
    }
    
    /// Clear only session cache (lighter invalidation)
    func clearSessionCache() {
        sessionLogs = nil
        sessionLogsTimestamp = .distantPast
    }
    
    // MARK: - Private Methods
    
    private func getCachedLogs(for period: TimePeriod) -> [DailyLog]? {
        guard let timestamp = cacheTimestamps[period],
              Date().timeIntervalSince(timestamp) < cacheTimeout,
              let logs = cachedLogs[period] else {
            return nil
        }
        return logs
    }
    
    private func setCachedLogs(_ logs: [DailyLog], for period: TimePeriod) {
        cachedLogs[period] = logs
        cacheTimestamps[period] = Date()
    }
    
    private func loadLogsFromDatabase(for period: TimePeriod) async -> [DailyLog] {
        return await withCheckedContinuation { continuation in
            let logs = LogsRepo.shared.getLogs()
            
            guard period != .allTime, let dateRange = period.dateRange else {
                continuation.resume(returning: logs.sorted { $0.date < $1.date })
                return
            }
            
            let filteredLogs = logs.filter { log in
                dateRange.contains(log.date)
            }.sorted { $0.date < $1.date }
            
            continuation.resume(returning: filteredLogs)
        }
    }
    
    private func loadAllLogsFromDatabase() async -> [DailyLog] {
        return await withCheckedContinuation { continuation in
            let logs = LogsRepo.shared.getLogs().sorted { $0.date < $1.date }
            continuation.resume(returning: logs)
        }
    }
}

// MARK: - Batch Operations

extension OptimizedDataLoader {
    /// Batch operation for multiple metrics to share the same data load
    func performBatchOperation<T>(
        for period: TimePeriod,
        operations: [(String, ([DailyLog]) -> T)]
    ) async -> [String: T] {
        let logs = await filterSessionLogs(for: period)
        var results: [String: T] = [:]
        
        for (key, operation) in operations {
            results[key] = operation(logs)
        }
        
        return results
    }
    
    /// Optimized batch count operations
    func getBatchDataPointCounts(
        for period: TimePeriod,
        conditions: [String: (DailyLog) -> Bool]
    ) async -> [String: Int] {
        let logs = await filterSessionLogs(for: period)
        var counts: [String: Int] = [:]
        
        for (key, condition) in conditions {
            counts[key] = logs.filter(condition).count
        }
        
        return counts
    }
}

// MARK: - Specialized Query Methods

extension OptimizedDataLoader {
    /// Get available symptoms across all logs (cached), returns [Symptom name : isBinary]
    func getAvailableSymptoms() async -> [String: Bool] {
        let logs = await getAllLogsForSession().sorted { $0.date > $1.date }
        var symptoms: [String:Bool] = [:]

        for log in logs {
            for symptomRating in log.symptomRatings {
                if symptoms[symptomRating.symptomName] == nil {
                    symptoms[symptomRating.symptomName] = symptomRating.isBinary
                }
            }
        }

        return symptoms
    }
    
    /// Get available medications across all logs (cached)
    func getAvailableMedications() async -> Set<String> {
        let logs = await getAllLogsForSession()
        var medications = Set<String>()
        
        for log in logs {
            for medication in log.medicationsTaken {
                let cleanName = medication.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanName.isEmpty {
                    medications.insert(cleanName)
                }
            }
        }
        
        return medications
    }
    
    /// Get available activities across all logs (cached)
    func getAvailableActivities() async -> Set<String> {
        // Get unique activity names from the new ActivityEntry table
        let activityRepo = ActivityEntryRepo.shared
        let allEntries = activityRepo.getAllEntries()

        var activities = Set<String>()
        for entry in allEntries {
            let cleanName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty {
                activities.insert(cleanName)
            }
        }

        return activities
    }

    /// Get available meals across all logs (cached)
    func getAvailableMeals() async -> Set<String> {
        // Get unique food names from the new FoodEntry table
        let foodRepo = FoodEntryRepo.shared
        let allEntries = foodRepo.getAllEntries()

        var meals = Set<String>()
        for entry in allEntries {
            let cleanName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty {
                meals.insert(cleanName)
            }
        }

        return meals
    }
}
