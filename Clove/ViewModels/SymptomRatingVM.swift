import Foundation

struct SymptomRatingVM: Identifiable {
    let id = UUID()
    var symptomName: String
    var ratingDouble: Double // bound to slider

    func toModel() -> SymptomRating {
        SymptomRating(symptomName: symptomName, rating: Int(ratingDouble))
    }
}
