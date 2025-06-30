import Foundation
import GRDB

struct TrackedMedication: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var dosage: String
    var instructions: String
    var isAsNeeded: Bool
    
    init(name: String, dosage: String = "", instructions: String = "", isAsNeeded: Bool = false) {
        self.name = name
        self.dosage = dosage
        self.instructions = instructions
        self.isAsNeeded = isAsNeeded
    }
}