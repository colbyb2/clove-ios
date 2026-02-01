import Foundation
import GRDB

/// Flow level categories for period tracking
enum FlowLevel: String, Codable, CaseIterable, Identifiable {
    case spotting
    case light
    case medium
    case heavy
    case veryHeavy
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }
    
    var numericValue: Int {
        switch self {
        case .spotting: return 1
        case .light: return 2
        case .medium: return 3
        case .heavy: return 4
        case .veryHeavy: return 5
        }
    }
}

/// A cycle entry representing a single day of period tracking
struct Cycle: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var date: Date
    var flow: FlowLevel
    var isStartOfCycle: Bool
    var hasCramps: Bool
    
    init(
        id: Int64? = nil,
        date: Date = Date(),
        flow: FlowLevel,
        isStartOfCycle: Bool = false,
        hasCramps: Bool = false
    ) {
        self.id = id
        self.date = date
        self.flow = flow
        self.isStartOfCycle = isStartOfCycle
        self.hasCramps = hasCramps
    }
    
    // MARK: - GRDB Configuration
    
    static var databaseTableName: String { "cycle" }
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let date = Column(CodingKeys.date)
        static let flow = Column(CodingKeys.flow)
        static let isStartOfCycle = Column(CodingKeys.isStartOfCycle)
        static let hasCramps = Column(CodingKeys.hasCramps)
    }
}
