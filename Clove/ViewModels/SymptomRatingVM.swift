import Foundation

struct SymptomRatingVM: Identifiable, Equatable {
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
        let rating = ratingDouble.isFinite ? Int(ratingDouble.rounded()) : 0
        return SymptomRating(
            symptomId: symptomId,
            symptomName: symptomName,
            rating: min(10, max(0, rating)),
            isBinary: isBinary
        )
    }
}
