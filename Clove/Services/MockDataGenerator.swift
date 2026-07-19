import Foundation

/// Utility class for generating mock health tracking data for development and testing
class MockDataGenerator {

    private static let hydrationServingSize = 8

    /// A small deterministic generator makes screenshots and analytics previews repeatable.
    /// The data is intentionally not perfectly clean: real-looking noise keeps charts believable
    /// while the underlying signals remain strong enough for relationship analysis.
    private struct SeededRandomNumberGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return state
        }
    }
    
    /// Generates mock daily logs for a specified number of days starting from a given date
    /// - Parameters:
    ///   - startDate: The starting date for mock data generation
    ///   - numberOfDays: Number of days to generate mock logs for
    /// - Returns: Array of DailyLog objects with deterministic scenario data
    static func createMockLogs(
        startingFrom startDate: Date = Date(),
        numberOfDays: Int,
        seed: UInt64 = 0xC10FE
    ) -> [DailyLog] {
        guard numberOfDays > 0 else { return [] }

        var mockLogs: [DailyLog] = []
        let calendar = Calendar.current
        var rng = SeededRandomNumberGenerator(state: seed)
        
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

            // Work in chronological order even though the returned logs are newest first.
            let chronologicalDay = numberOfDays - dayOffset - 1
            let progress = numberOfDays == 1
                ? 1.0
                : Double(chronologicalDay) / Double(numberOfDays - 1)
            let weeklyWave = sin(Double(chronologicalDay) * 2.0 * .pi / 7.0)
            let noise = Int.random(in: -1...1, using: &rng)

            // Use the same weather scale as MetricCatalog. Harsh weather deliberately raises
            // pain, making Weather ↔ Pain a useful screenshot relationship.
            let weather: String
            let weatherScore: Int
            switch (chronologicalDay * 5 + 2) % 18 {
            case 0...2: weather = "Stormy"; weatherScore = 1
            case 3...5: weather = "Rainy"; weatherScore = 2
            case 6...8: weather = "Gloomy"; weatherScore = 3
            case 9...12: weather = "Cloudy"; weatherScore = 4
            case 13...14: weather = "Snow"; weatherScore = 5
            default: weather = "Sunny"; weatherScore = 6
            }

            // A visible recovery arc: mood and energy improve while pain gradually decreases.
            // Weekly variation and small noise prevent the chart from looking synthetic.
            let adherenceProbability = 0.58 + (0.30 * progress) + (weeklyWave * 0.04)
            let adherenceWasTaken = Double.random(in: 0...1, using: &rng) < adherenceProbability
            let adherenceBoost = adherenceWasTaken ? 1 : 0
            let weatherPainEffect = max(0, 5 - weatherScore) / 2

            let mood = clamped(
                4 + Int((3.0 * progress).rounded()) + Int((weeklyWave * 0.7).rounded())
                    + adherenceBoost + noise,
                to: 1...10
            )
            let energyLevel = clamped(
                4 + Int((3.0 * progress).rounded()) + Int((weeklyWave * 0.8).rounded())
                    + adherenceBoost + noise,
                to: 1...10
            )
            let painLevel = clamped(
                7 - Int((3.0 * progress).rounded()) + weatherPainEffect
                    - adherenceBoost + noise,
                to: 0...10
            )
            let waterIntake = clamped(
                5 + Int((4.0 * progress).rounded()) + Int((weeklyWave * 1.2).rounded())
                    + Int.random(in: -1...1, using: &rng),
                to: 3...12
            ) * hydrationServingSize

            // Keep the contextual data varied, but let healthier periods contain more routine,
            // meals, and activities so the dashboard feels lived-in.
            let mealIndex = (chronologicalDay + Int.random(in: 0...2, using: &rng)) % sampleMeals.count
            let activityIndex = (chronologicalDay * 2 + Int.random(in: 0...2, using: &rng)) % sampleActivities.count
            let meals = sampleMeals[mealIndex]
            let activities = sampleActivities[activityIndex]
            let medications = adherenceWasTaken ? ["Vitamin D", "Magnesium"] : []

            // Symptoms intentionally follow the same latent factors as the core metrics.
            let symptomRatings = sampleSymptoms.map { symptom in
                var rating = symptom
                switch symptom.symptomName {
                case "Headache":
                    rating.rating = clamped(painLevel + weatherPainEffect + noise, to: 0...10)
                case "Joint Pain":
                    rating.rating = clamped(painLevel + Int.random(in: -1...1, using: &rng), to: 0...10)
                case "Fatigue":
                    rating.rating = clamped(10 - energyLevel + (adherenceWasTaken ? 0 : 1)
                        + Int.random(in: -1...1, using: &rng), to: 0...10)
                case "Stress":
                    rating.rating = clamped(10 - mood + Int((weeklyWave * -1.0).rounded())
                        + Int.random(in: -1...1, using: &rng), to: 0...10)
                default:
                    rating.rating = Int.random(in: 0...4, using: &rng)
                }
                return rating
            }

            let medicationAdherence = sampleMedicationAdherence.map { med in
                var adherence = med
                adherence.wasTaken = med.isAsNeeded
                    ? Double.random(in: 0...1, using: &rng) > 0.45
                    : adherenceWasTaken
                return adherence
            }

            let notes: String?
            if painLevel >= 7 {
                notes = weatherScore <= 3
                    ? "More uncomfortable today; the weather may have contributed."
                    : "A higher-pain day; taking it slower and keeping notes."
            } else if energyLevel >= 7 {
                notes = "Good energy today; the routine felt manageable."
            } else if chronologicalDay % 4 == 0 {
                notes = "Keeping track of the small details today."
            } else {
                notes = nil
            }

            // Flare days are uncommon but occur more often during high-pain periods.
            let isFlareDay = painLevel >= 7
                && Double.random(in: 0...1, using: &rng) < (weatherScore <= 2 ? 0.55 : 0.25)
            
            let mockLog = DailyLog(
                date: logDate,
                mood: mood,
                painLevel: painLevel,
                energyLevel: energyLevel,
                waterIntake: waterIntake,
                meals: meals,
                activities: activities,
                medicationsTaken: medications,
                medicationAdherence: medicationAdherence,
                notes: notes,
                isFlareDay: isFlareDay,
                weather: weather,
                symptomRatings: symptomRatings
            )
            
            mockLogs.append(mockLog)
        }
        
        return mockLogs
    }

    private static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Generates zero, one, or two realistic bowel-movement records per day.
    /// Bowel movements are stored separately from `DailyLog`, so callers that
    /// want a complete mock history should use `generateAndSaveMockLogs`.
    static func createMockBowelMovements(
        startingFrom startDate: Date = Date(),
        numberOfDays: Int
    ) -> [BowelMovement] {
        guard numberOfDays > 0 else { return [] }

        let calendar = Calendar.current
        var bowelMovements: [BowelMovement] = []

        for dayOffset in 0..<numberOfDays {
            guard Double.random(in: 0...1) < 0.78,
                  let day = calendar.date(byAdding: .day, value: -dayOffset, to: startDate) else {
                continue
            }

            let movementCount = Double.random(in: 0...1) < 0.16 ? 2 : 1
            for movementIndex in 0..<movementCount {
                let hour = movementIndex == 0 ? Int.random(in: 7...12) : Int.random(in: 15...21)
                let minute = Int.random(in: 0...59)
                let date = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: day
                ) ?? day

                bowelMovements.append(
                    BowelMovement(
                        type: Double(generateRealisticBristolType()),
                        date: date
                    )
                )
            }
        }

        return bowelMovements
    }
    
    /// Produces Bristol types weighted toward the typical 3–5 range.
    private static func generateRealisticBristolType() -> Int {
        let weights = [0.05, 0.10, 0.20, 0.35, 0.17, 0.09, 0.04]
        return weightedRandomSelection(weights: weights) + 1
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

    /// Saves generated bowel movements to their dedicated table.
    /// - Returns: Number of records saved, or zero if the batch failed.
    @discardableResult
    static func saveMockBowelMovementsToDatabase(_ bowelMovements: [BowelMovement]) -> Int {
        guard !bowelMovements.isEmpty else { return 0 }

        let saved = BowelMovementRepo.shared.save(bowelMovements)
        let savedCount = saved ? bowelMovements.count : 0
        print("Successfully saved \(savedCount) out of \(bowelMovements.count) mock bowel movements to database")
        return savedCount
    }
    
    /// Convenience method to generate and save mock logs in one call
    /// - Parameters:
    ///   - startDate: Starting date for mock data
    ///   - numberOfDays: Number of days to generate
    /// - Returns: Number of successfully saved logs
    @discardableResult
    static func generateAndSaveMockLogs(startingFrom startDate: Date = Date(), numberOfDays: Int) -> Int {
        guard numberOfDays > 0 else {
            print("Mock data generation skipped because numberOfDays must be greater than zero")
            return 0
        }

        let mockLogs = createMockLogs(startingFrom: startDate, numberOfDays: numberOfDays)
        let bowelMovements = createMockBowelMovements(
            startingFrom: startDate,
            numberOfDays: numberOfDays
        )
        let savedLogCount = saveMockLogsToDatabase(mockLogs)
        _ = saveMockBowelMovementsToDatabase(bowelMovements)
        return savedLogCount
    }
}
