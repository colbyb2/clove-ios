import Foundation
import GRDB

/// Flow level categories for period tracking
enum FlowLevel: String, Codable, CaseIterable, Identifiable {
    /// No flow observation was recorded. Analytics must omit this case.
    case notRecorded
    case noFlow
    case spotting
    case light
    case medium
    case heavy
    case veryHeavy
    
    var id: String { rawValue }
    var isBleeding: Bool { self != .noFlow && self != .notRecorded }
    static var selectableCases: [FlowLevel] { allCases.filter { $0 != .notRecorded } }
    
    var displayName: String {
        switch self {
        case .notRecorded: return "Flow not recorded"
        case .noFlow: return "No flow"
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }
    
    var numericValue: Double {
        switch self {
        case .notRecorded, .noFlow: return 0.0
        case .spotting: return 1.0
        case .light: return 2.0
        case .medium: return 3.0
        case .heavy: return 4.0
        case .veryHeavy: return 5.0
        }
    }
}

/// A cycle entry representing a single day of period tracking
struct Cycle: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var date: Date
    var flow: FlowLevel
    var isStartOfCycle: Bool
    var isEndOfCycle: Bool?
    var hasCramps: Bool
    var fertilitySigns: Bool?
    var ovulation: Bool?

    var summary: String {
        var parts = flow == .notRecorded ? [] : [flow.displayName]
        if fertilitySigns == true { parts.append("Fertility signs") }
        if ovulation == true { parts.append("Suspected ovulation") }
        return parts.isEmpty ? "Cycle details" : parts.joined(separator: " · ")
    }
    
    init(
        id: Int64? = nil,
        date: Date = Date(),
        flow: FlowLevel,
        isStartOfCycle: Bool = false,
        isEndOfCycle: Bool = false,
        hasCramps: Bool = false,
        fertilitySigns: Bool? = nil,
        ovulation: Bool? = nil
    ) {
        self.id = id
        self.date = date
        self.flow = flow
        self.isStartOfCycle = isStartOfCycle
        self.isEndOfCycle = isEndOfCycle
        self.hasCramps = hasCramps
        self.fertilitySigns = fertilitySigns
        self.ovulation = ovulation
    }
    
    // MARK: - GRDB Configuration
    
    static var databaseTableName: String { "cycle" }
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let date = Column(CodingKeys.date)
        static let flow = Column(CodingKeys.flow)
        static let isStartOfCycle = Column(CodingKeys.isStartOfCycle)
        static let isEndOfCycle = Column(CodingKeys.isEndOfCycle)
        static let hasCramps = Column(CodingKeys.hasCramps)
        static let fertilitySigns = Column(CodingKeys.fertilitySigns)
        static let ovulation = Column(CodingKeys.ovulation)
    }
}
