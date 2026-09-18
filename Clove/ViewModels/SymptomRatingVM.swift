import Foundation

struct SymptomRatingVM: Identifiable, Equatable {
    let id = UUID()
    var symptomId: Int64
    var symptomName: String
    /// Nil is unanswered. A value of zero is an explicit numeric zero or binary No.
    var ratingDouble: Double?
    var isBinary: Bool = false

    init(symptomId: Int64, symptomName: String, ratingDouble: Double? = nil, isBinary: Bool = false) {
        self.symptomId = symptomId
        self.symptomName = symptomName
        self.ratingDouble = ratingDouble
        self.isBinary = isBinary
    }

    func toModel() -> SymptomRating? {
        guard let ratingDouble, ratingDouble.isFinite else { return nil }
        let rating = Int(ratingDouble.rounded())
        return SymptomRating(
            symptomId: symptomId,
            symptomName: symptomName,
            rating: min(10, max(0, rating)),
            isBinary: isBinary
        )
    }
}
