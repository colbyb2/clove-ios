import Foundation
import GRDB

struct TrackedSymptom: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var isBinary: Bool = false
    var displayOrder: Int = 0

    init(id: Int64? = nil, name: String, isBinary: Bool = false, displayOrder: Int = 0) {
        self.id = id
        self.name = name
        self.isBinary = isBinary
        self.displayOrder = displayOrder
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isBinary, displayOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isBinary = try container.decodeIfPresent(Bool.self, forKey: .isBinary) ?? false
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isBinary, forKey: .isBinary)
        // Omitting the legacy default keeps pre-order backup checksums compatible.
        if displayOrder != 0 {
            try container.encode(displayOrder, forKey: .displayOrder)
        }
    }
}
