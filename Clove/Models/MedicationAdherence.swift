import Foundation

struct MedicationAdherence: Codable {
    var medicationId: Int64
    var medicationName: String
    var wasTaken: Bool
    var isAsNeeded: Bool
    var notes: String?
    
    init(medicationId: Int64, medicationName: String, wasTaken: Bool = false, isAsNeeded: Bool = false, notes: String? = nil) {
        self.medicationId = medicationId
        self.medicationName = medicationName
        self.wasTaken = wasTaken
        self.isAsNeeded = isAsNeeded
        self.notes = notes
    }
}