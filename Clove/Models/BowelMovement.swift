import GRDB
import Foundation

struct BowelMovement: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var type: Double
    var date: Date
    var notes: String?
    
    init(type: Double, date: Date, notes: String? = nil) {
        self.type = type
        self.date = date
        self.notes = notes
    }
}

extension BowelMovement {
    var bristolStoolType: BristolStoolType {
        return BristolStoolType(rawValue: Int(type)) ?? .type4
    }
    
    var isValidType: Bool {
        return type >= 1.0 && type <= 7.0
    }
}

enum BristolStoolType: Int, CaseIterable {
    case type1 = 1
    case type2 = 2
    case type3 = 3
    case type4 = 4
    case type5 = 5
    case type6 = 6
    case type7 = 7
    
    var description: String {
        switch self {
        case .type1:
            return "Separate hard lumps"
        case .type2:
            return "Lumpy and sausage like"
        case .type3:
            return "A sausage shape with cracks in the surface"
        case .type4:
            return "Like a smooth, soft sausage or snake"
        case .type5:
            return "Soft blobs with clear-cut edges"
        case .type6:
            return "Mushy consistency with ragged edges"
        case .type7:
            return "Liquid consistency with no solid pieces"
        }
    }
    
    var consistency: String {
        switch self {
        case .type1, .type2:
            return "Hard"
        case .type3, .type4:
            return "Normal"
        case .type5, .type6, .type7:
            return "Loose"
        }
    }
}