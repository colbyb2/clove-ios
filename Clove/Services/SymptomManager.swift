import Foundation
import SwiftUI

class SymptomManager {
   static let shared = SymptomManager()
   
   func fetchSymptoms() -> [TrackedSymptom] {
      return SymptomsRepo.shared.getTrackedSymptoms()
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
