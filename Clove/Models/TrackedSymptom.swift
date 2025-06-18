import Foundation
import GRDB

struct TrackedSymptom: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var order: Int
}