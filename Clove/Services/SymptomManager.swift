import Foundation
import SwiftUI
import CryptoKit

class SymptomManager {
    static let shared = SymptomManager()
    
    func fetchSymptoms() -> [TrackedSymptom] {
        return SymptomsRepo.shared.getTrackedSymptoms()
    }
    
    /// Determines if a symptom is a one-time symptom by comparing its ID with the hash of its name
    /// One-time symptoms use hash-based IDs, while tracked symptoms use database auto-increment IDs
    func isOneTimeSymptom(id: Int64, name: String) -> Bool {
        let computedId = hashSymptomName(name)
        return computedId == id
    }
    
    /// Generates a consistent Int64 hash from a symptom name
    private func hashSymptomName(_ name: String) -> Int64 {
        let hash = SHA256.hash(data: Data(name.utf8))
        let hashBytes = Array(hash.prefix(8)) // Take first 8 bytes for Int64
        
        // Convert bytes to Int64
        var value: Int64 = 0
        for byte in hashBytes {
            value = value << 8
            value = value | Int64(byte)
        }
        
        return value
    }
    
    func isSymptomBinary(id: Int64) async -> Bool {
        // First check if symptom is in current tracked symptoms
        let trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
        if let trackedSymptom = trackedSymptoms.first(where: { $0.id == id }) {
            return trackedSymptom.isBinary
        }

        // If not found in tracked symptoms, check historical logs
        // Get all logs and find the most recent one containing this symptom
        let allLogs = await OptimizedDataLoader.shared.getLogsForPeriod(TimePeriodManager.shared.selectedPeriod)

        // Sort logs by date descending to get most recent first
        let sortedLogs = allLogs.sorted { $0.date > $1.date }

        // Find the first log that contains this symptom
        for log in sortedLogs {
            if let symptomRating = log.symptomRatings.first(where: { $0.symptomId == id }) {
                return symptomRating.isBinary
            }
        }

        // Default to false if symptom not found anywhere
        return false
    }
    
    func addSymptom(name: String, isBinary: Bool = false, onSuccess: @escaping () -> Void = {}) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Check if symptom already exists
        if SymptomsRepo.shared.getTrackedSymptoms().contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            ToastManager.shared.showToast(message: "Symptom already exists", color: CloveColors.error, icon: Image(systemName: "exclamationmark.triangle"))
            return
        }
        
        let symptom = TrackedSymptom(name: trimmedName, isBinary: isBinary)
        let success = SymptomsRepo.shared.saveSymptom(symptom)
        
        if success {
            onSuccess()
            ToastManager.shared.showToast(message: "Symptom added successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
        } else {
            ToastManager.shared.showToast(message: "Failed to add symptom", color: CloveColors.error)
        }
    }
    
    func updateSymptom(id: Int64, newName: String, isBinary: Bool, onSuccess: @escaping () -> Void = {}) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Check if another symptom already has this name
        if SymptomsRepo.shared.getTrackedSymptoms().contains(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.id != id }) {
            ToastManager.shared.showToast(message: "Symptom name already exists", color: CloveColors.error, icon: Image(systemName: "exclamationmark.triangle"))
            return
        }
        
        let success = SymptomsRepo.shared.updateSymptom(id: id, name: trimmedName, isBinary: isBinary)
        
        if success {
            onSuccess()
            ToastManager.shared.showToast(message: "Symptom updated successfully", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
        } else {
            ToastManager.shared.showToast(message: "Failed to update symptom", color: CloveColors.error)
        }
    }
    
    func deleteSymptom(id: Int64, onSuccess: @escaping () -> Void) {
        let success = SymptomsRepo.shared.deleteSymptom(id: id)
        
        if success {
            onSuccess()
            ToastManager.shared.showToast(message: "Symptom deleted", color: CloveColors.success, icon: Image(systemName: "checkmark.circle"))
        } else {
            ToastManager.shared.showToast(message: "Failed to delete symptom", color: CloveColors.error)
        }
    }
}
