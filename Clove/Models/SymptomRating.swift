import Foundation

struct SymptomRating: Codable {
   var symptomId: Int64
   var symptomName: String
   var rating: Int
   
   init(symptomId: Int64, symptomName: String, rating: Int) {
       self.symptomId = symptomId
       self.symptomName = symptomName
       self.rating = rating
   }
}
