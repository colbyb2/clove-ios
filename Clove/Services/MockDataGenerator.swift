import Foundation

/// Utility class for generating mock health tracking data for development and testing
class MockDataGenerator {
    
    /// Generates mock daily logs for a specified number of days starting from a given date
    /// - Parameters:
    ///   - startDate: The starting date for mock data generation
    ///   - numberOfDays: Number of days to generate mock logs for
    /// - Returns: Array of DailyLog objects with randomized health data
    static func createMockLogs(startingFrom startDate: Date = Date(), numberOfDays: Int) -> [DailyLog] {
        var mockLogs: [DailyLog] = []
        let calendar = Calendar.current
        
        // Sample data arrays for randomization
        let sampleMeals = [
            ["Oatmeal", "Yogurt"],
            ["Salad", "Apple", "Tea"],
            ["Salmon", "Rice"],
            ["Smoothie", "Banana"],
            ["Quinoa", "Hummus"],
            ["Soup", "Bread"],
            ["Toast", "Juice"],
            ["Stir-fry", "Rice"]
        ]
        
        let sampleActivities = [
            ["Walking", "Stretching"],
            ["Yoga", "Meditation"],
            ["Swimming", "Weights"],
            ["Hiking", "Reading"],
            ["Cycling", "Gardening"],
            ["Dancing", "Cooking"],
            ["Tai Chi", "Journaling"],
            ["Pilates", "Photography"]
        ]
        
        let sampleMedications = [
            ["Vitamin D", "Multivitamin"],
            ["Omega-3", "Probiotics"],
            ["Magnesium", "B-Complex"],
            ["Turmeric", "Vitamin C"],
            ["Iron supplement", "Calcium"],
            ["Melatonin", "Zinc"],
            []  // Some days with no medications
        ]
        
        let weatherOptions = [
            "Sunny", "Cloudy", "Rainy", "Clear",
            "Overcast", "Foggy", "Windy", "Snowy"
        ]
        
        let notesSamples = [
            "Felt energetic today, good sleep last night",
            "Headache in the afternoon, possibly stress related",
            "Great workout session, feeling accomplished",
            "Busy day at work, need to focus on relaxation",
            "Spent time outdoors, fresh air helped mood",
            "Mild joint stiffness in the morning",
            "Had a social gathering, felt uplifted",
            "Productive day, maintained good routine",
            nil, nil  // Some days without notes
        ]
        
        // Sample symptom ratings (assuming some common tracked symptoms)
        let sampleSymptoms = [
            SymptomRating(symptomId: 1, symptomName: "Headache", rating: 0),
            SymptomRating(symptomId: 2, symptomName: "Joint Pain", rating: 0),
            SymptomRating(symptomId: 3, symptomName: "Fatigue", rating: 0),
            SymptomRating(symptomId: 4, symptomName: "Nausea", rating: 0),
            SymptomRating(symptomId: 5, symptomName: "Stress", rating: 0)
        ]
        
        // Sample medication adherence
        let sampleMedicationAdherence = [
            MedicationAdherence(medicationId: 1, medicationName: "Vitamin D", wasTaken: true),
            MedicationAdherence(medicationId: 2, medicationName: "Multivitamin", wasTaken: true),
            MedicationAdherence(medicationId: 3, medicationName: "Omega-3", wasTaken: false, isAsNeeded: true)
        ]
        
        for dayOffset in 0..<numberOfDays {
            guard let logDate = calendar.date(byAdding: .day, value: -dayOffset, to: startDate) else {
                continue
            }
            
            // Generate random but realistic health metrics
            let mood = Int.random(in: 1...10)
            let painLevel = generateRealisticPainLevel()
            let energyLevel = generateRealisticEnergyLevel(basedOnMood: mood)
            
            // Randomly select meals, activities, and medications
            let meals = sampleMeals.randomElement() ?? []
            let activities = sampleActivities.randomElement() ?? []
            let medications = sampleMedications.randomElement() ?? []
            
            // Generate symptom ratings with some correlation to pain/mood
            var symptomRatings = sampleSymptoms.map { symptom in
                var rating = symptom
                switch symptom.symptomName {
                case "Headache":
                    rating.rating = generateCorrelatedRating(basedOn: painLevel, variance: 2)
                case "Joint Pain":
                    rating.rating = generateCorrelatedRating(basedOn: painLevel, variance: 1)
                case "Fatigue":
                    rating.rating = 10 - generateCorrelatedRating(basedOn: energyLevel, variance: 2)
                case "Stress":
                    rating.rating = 10 - generateCorrelatedRating(basedOn: mood, variance: 3)
                default:
                    rating.rating = Int.random(in: 0...5)
                }
                return rating
            }
            
            // Generate medication adherence with some randomness
            var medicationAdherence = sampleMedicationAdherence.map { med in
                var adherence = med
                adherence.wasTaken = Bool.random() ? true : Double.random(in: 0...1) > 0.2 // 80% adherence rate
                return adherence
            }
            
            // Determine if it's a flare day (low probability, correlated with high pain/symptoms)
            let isFlareDay = painLevel != nil && painLevel! >= 7 && Bool.random() && Double.random(in: 0...1) < 0.15
            
            let mockLog = DailyLog(
                date: logDate,
                mood: mood,
                painLevel: painLevel,
                energyLevel: energyLevel,
                meals: meals,
                activities: activities,
                medicationsTaken: medications,
                medicationAdherence: medicationAdherence,
                notes: notesSamples.randomElement() ?? nil,
                isFlareDay: isFlareDay,
                weather: weatherOptions.randomElement(),
                symptomRatings: symptomRatings
            )
            
            mockLogs.append(mockLog)
        }
        
        return mockLogs
    }
    
    /// Generates a realistic pain level with weighted distribution
    /// - Returns: Pain level (1-10) or nil for no pain days
    private static func generateRealisticPainLevel() -> Int? {
        let painProbability = Double.random(in: 0...1)
        
        // 30% chance of no pain
        if painProbability < 0.3 {
            return nil
        }
        
        // Weighted towards lower pain levels (more common)
        let weights = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.05, 0.03, 0.01, 0.01] // 1-10
        return weightedRandomSelection(weights: weights) + 1
    }
    
    /// Generates energy level correlated with mood
    /// - Parameter mood: Mood level (1-10)
    /// - Returns: Energy level (1-10)
    private static func generateRealisticEnergyLevel(basedOnMood mood: Int) -> Int {
        // Energy tends to correlate with mood, but with some variance
        let baseEnergy = mood + Int.random(in: -2...2)
        return max(1, min(10, baseEnergy))
    }
    
    /// Generates a rating correlated with a base value
    /// - Parameters:
    ///   - baseValue: The base value to correlate with
    ///   - variance: How much variance to allow
    /// - Returns: Correlated rating (0-10)
    private static func generateCorrelatedRating(basedOn baseValue: Int?, variance: Int) -> Int {
        guard let base = baseValue else { return Int.random(in: 0...3) }
        let correlated = base + Int.random(in: -variance...variance)
        return max(0, min(10, correlated))
    }
    
    /// Performs weighted random selection
    /// - Parameter weights: Array of weights for each option
    /// - Returns: Index of selected option
    private static func weightedRandomSelection(weights: [Double]) -> Int {
        let random = Double.random(in: 0...1)
        var cumulativeWeight = 0.0
        
        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            if random <= cumulativeWeight {
                return index
            }
        }
        
        return weights.count - 1 // Fallback to last option
    }
    
    /// Saves generated mock logs to the database
    /// - Parameter logs: Array of DailyLog objects to save
    /// - Returns: Number of successfully saved logs
    @discardableResult
    static func saveMockLogsToDatabase(_ logs: [DailyLog]) -> Int {
        let logsRepo = LogsRepo.shared
        var savedCount = 0
        
        for log in logs {
            if logsRepo.saveLog(log) {
                savedCount += 1
            }
        }
        
        print("Successfully saved \(savedCount) out of \(logs.count) mock logs to database")
        return savedCount
    }
    
    /// Convenience method to generate and save mock logs in one call
    /// - Parameters:
    ///   - startDate: Starting date for mock data
    ///   - numberOfDays: Number of days to generate
    /// - Returns: Number of successfully saved logs
    @discardableResult
    static func generateAndSaveMockLogs(startingFrom startDate: Date = Date(), numberOfDays: Int) -> Int {
        let mockLogs = createMockLogs(startingFrom: startDate, numberOfDays: numberOfDays)
        return saveMockLogsToDatabase(mockLogs)
    }
}