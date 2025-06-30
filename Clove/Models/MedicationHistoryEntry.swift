import Foundation
import GRDB

struct MedicationHistoryEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var medicationId: Int64
    var medicationName: String
    var changeType: String // "added", "removed", "dosage_changed", "instructions_changed"
    var changeDate: Date
    var oldValue: String?
    var newValue: String?
    var notes: String?
    
    init(medicationId: Int64, medicationName: String, changeType: String, changeDate: Date = Date(), oldValue: String? = nil, newValue: String? = nil, notes: String? = nil) {
        self.medicationId = medicationId
        self.medicationName = medicationName
        self.changeType = changeType
        self.changeDate = changeDate
        self.oldValue = oldValue
        self.newValue = newValue
        self.notes = notes
    }
}