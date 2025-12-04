import Foundation

struct SymptomRatingVM: Identifiable {
    let id = UUID()
    var symptomId: Int64
    var symptomName: String
    var ratingDouble: Double // bound to slider
    var isBinary: Bool = false

    init(symptomId: Int64, symptomName: String, ratingDouble: Double = 5, isBinary: Bool = false) {
        self.symptomId = symptomId
        self.symptomName = symptomName
        self.ratingDouble = ratingDouble
        self.isBinary = isBinary
    }

    func toModel() -> SymptomRating {
        SymptomRating(symptomId: symptomId, symptomName: symptomName, rating: Int(ratingDouble), isBinary: isBinary)
    }
}
