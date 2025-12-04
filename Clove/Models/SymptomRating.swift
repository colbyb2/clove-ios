import Foundation

struct SymptomRating: Codable {
    var symptomId: Int64
    var symptomName: String
    var rating: Int
    var isBinary: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case symptomId, symptomName, rating, isBinary
    }
    
    init(symptomId: Int64, symptomName: String, rating: Int, isBinary: Bool = false) {
        self.symptomId = symptomId
        self.symptomName = symptomName
        self.rating = rating
        self.isBinary = isBinary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.symptomId = try container.decode(Int64.self, forKey: .symptomId)
        self.symptomName = try container.decode(String.self, forKey: .symptomName)
        self.rating = try container.decode(Int.self, forKey: .rating)
        
        self.isBinary = try container.decodeIfPresent(Bool.self, forKey: .isBinary) ?? false
    }
}
