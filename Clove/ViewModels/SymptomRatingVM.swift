import Foundation

struct SymptomRatingVM: Identifiable {
    let id = UUID()
    var symptomId: Int64
    var symptomName: String
    var ratingDouble: Double // bound to slider
    
    init(symptomId: Int64, symptomName: String, ratingDouble: Double = 5) {
        self.symptomId = symptomId
        self.symptomName = symptomName
        self.ratingDouble = ratingDouble
    }

    func toModel() -> SymptomRating {
        SymptomRating(symptomId: symptomId, symptomName: symptomName, rating: Int(ratingDouble))
    }
}
