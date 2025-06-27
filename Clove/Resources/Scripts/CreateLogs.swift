import Foundation

class DEVCreateLogs {
   static func execute() {
      // Get tracked symptoms first to use in our logs
      let trackedSymptoms = SymptomsRepo.shared.getTrackedSymptoms()
      
      // Create logs for the next 10 days
      for dayOffset in 1...10 {
         let logDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
         
         // Generate random ratings
         let randomMood = Int.random(in: 1...5)
         let randomPain = Int.random(in: 0...10)
         let randomEnergy = Int.random(in: 0...10)
         let randomIsFlare = Bool.random()
         
         // Create random symptom ratings for existing tracked symptoms
         var symptomRatings: [SymptomRating] = []
         for symptom in trackedSymptoms {
            let rating = Int.random(in: 0...10)
            symptomRatings.append(SymptomRating(symptomName: symptom.name, rating: rating))
         }
         
         // Generate some sample data for other fields
         let meals = ["Breakfast", "Lunch", "Dinner"].filter { _ in Bool.random() }
         let activities = ["Walking", "Reading", "Resting", "Working", "Exercise"].filter { _ in Bool.random() }
         let medications = ["Ibuprofen", "Vitamin D", "Multivitamin", "Prescription"].filter { _ in Bool.random() }
         
         // Create a note with some probability
         let notes: String? = Bool.random() ? "Random note for day \(dayOffset)" : nil
         
         // Create the log
         let log = DailyLog(
            date: logDate,
            mood: randomMood,
            painLevel: randomPain,
            energyLevel: randomEnergy,
            meals: meals,
            activities: activities,
            medicationsTaken: medications,
            notes: notes,
            isFlareDay: randomIsFlare,
            symptomRatings: symptomRatings
         )
         
         // Save the log
         let _ = LogsRepo.shared.saveLog(log)
         print("Created log for \(logDate.formatted(date: .abbreviated, time: .omitted))")
      }
      
      print("Successfully created 10 random logs")
   }
}
