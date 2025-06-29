import SwiftUI


@Observable
class LogData {
   var mood: Double = 5
   var painLevel: Double = 5
   var energyLevel: Double = 5
   var isFlareDay: Bool = false
   var weather: String? = nil
   var symptomRatings: [SymptomRatingVM] = []
   
   init() {}
   
   init(from log: DailyLog) {
      if let logMood = log.mood {
         self.mood = Double(logMood)
      }
      if let logPain = log.painLevel {
         self.painLevel = Double(logPain)
      }
      if let logEnergy = log.energyLevel {
         self.energyLevel = Double(logEnergy)
      }
      self.isFlareDay = log.isFlareDay
      self.weather = log.weather
      self.symptomRatings = log.symptomRatings.map({ s in
         return SymptomRatingVM(symptomId: s.symptomId, symptomName: s.symptomName, ratingDouble: Double(s.rating))
      })
//      log.symptomRatings.forEach({symptom in
//         if var s = symptomRatings.first(where: { vm in
//            vm.symptomId == symptom.symptomId
//         }) {
//            s.ratingDouble = Double(symptom.rating)
//         } else {
//            self.symptomRatings.append(SymptomRatingVM(symptomId: symptom.symptomId, symptomName: symptom.symptomName, ratingDouble: Double(symptom.rating)))
//         }
//      })
   }
}
