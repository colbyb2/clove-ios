import Foundation
import GRDB

class SearchRepo {
    static let shared = SearchRepo(
        databaseManager: DatabaseManager.shared,
        logsRepository: LogsRepo.shared,
        bowelMovementRepository: BowelMovementRepo.shared
    )

    private let databaseManager: DatabaseManaging
    private let logsRepository: LogsRepositoryProtocol
    private let bowelMovementRepository: BowelMovementRepositoryProtocol

    init(
        databaseManager: DatabaseManaging,
        logsRepository: LogsRepositoryProtocol,
        bowelMovementRepository: BowelMovementRepositoryProtocol
    ) {
        self.databaseManager = databaseManager
        self.logsRepository = logsRepository
        self.bowelMovementRepository = bowelMovementRepository
    }

    // MARK: - Main Search Method

    func searchLogs(query: String, filters: SearchCategoryFilters) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var results: [SearchResult] = []

        if filters.notes {
            results.append(contentsOf: searchNotes(query: trimmedQuery))
        }
        if filters.symptoms {
            results.append(contentsOf: searchSymptoms(query: trimmedQuery))
        }
        if filters.meals {
            results.append(contentsOf: searchMeals(query: trimmedQuery))
        }
        if filters.activities {
            results.append(contentsOf: searchActivities(query: trimmedQuery))
        }
        if filters.medications {
            results.append(contentsOf: searchMedications(query: trimmedQuery))
        }
        if filters.bowelMovements {
            results.append(contentsOf: searchBowelMovements(query: trimmedQuery))
        }

        // Sort by date descending (newest first)
        results.sort { $0.log.date > $1.log.date }

        return results
    }

    // MARK: - Category-Specific Search Methods

    func searchNotes(query: String) -> [SearchResult] {
        let logs = logsRepository.getLogs()

        return logs.compactMap { log in
            guard let notes = log.notes,
                  let range = notes.range(of: query, options: .caseInsensitive) else {
                return nil
            }

            let snippet = extractContextSnippet(from: notes, matchRange: range, query: query)

            return SearchResult(
                log: log,
                matchedCategory: .notes,
                matchedText: String(notes[range]),
                contextSnippet: snippet,
                matchRange: range
            )
        }
    }

    func searchSymptoms(query: String) -> [SearchResult] {
        let logs = logsRepository.getLogs()

        return logs.flatMap { log -> [SearchResult] in
            log.symptomRatings.compactMap { symptom in
                guard symptom.symptomName.range(of: query, options: .caseInsensitive) != nil else {
                    return nil
                }

                let contextSnippet = "\(symptom.symptomName): \(symptom.rating)/10"
                let fullRange = symptom.symptomName.startIndex..<symptom.symptomName.endIndex

                return SearchResult(
                    log: log,
                    matchedCategory: .symptoms,
                    matchedText: symptom.symptomName,
                    contextSnippet: contextSnippet,
                    matchRange: fullRange
                )
            }
        }
    }

    func searchMeals(query: String) -> [SearchResult] {
        let logs = logsRepository.getLogs()

        return logs.flatMap { log -> [SearchResult] in
            log.meals.compactMap { meal in
                guard meal.range(of: query, options: .caseInsensitive) != nil else {
                    return nil
                }

                let contextSnippet = meal
                let fullRange = meal.startIndex..<meal.endIndex

                return SearchResult(
                    log: log,
                    matchedCategory: .meals,
                    matchedText: meal,
                    contextSnippet: contextSnippet,
                    matchRange: fullRange
                )
            }
        }
    }

    func searchActivities(query: String) -> [SearchResult] {
        let logs = logsRepository.getLogs()

        return logs.flatMap { log -> [SearchResult] in
            log.activities.compactMap { activity in
                guard activity.range(of: query, options: .caseInsensitive) != nil else {
                    return nil
                }

                let contextSnippet = activity
                let fullRange = activity.startIndex..<activity.endIndex

                return SearchResult(
                    log: log,
                    matchedCategory: .activities,
                    matchedText: activity,
                    contextSnippet: contextSnippet,
                    matchRange: fullRange
                )
            }
        }
    }

    func searchMedications(query: String) -> [SearchResult] {
        let logs = logsRepository.getLogs()

        return logs.flatMap { log -> [SearchResult] in
            log.medicationAdherence.compactMap { medication in
                guard medication.medicationName.range(of: query, options: .caseInsensitive) != nil else {
                    return nil
                }

                let status = medication.wasTaken ? "Taken" : "Not taken"
                let contextSnippet = "\(medication.medicationName) - \(status)"
                let fullRange = medication.medicationName.startIndex..<medication.medicationName.endIndex

                return SearchResult(
                    log: log,
                    matchedCategory: .medications,
                    matchedText: medication.medicationName,
                    contextSnippet: contextSnippet,
                    matchRange: fullRange
                )
            }
        }
    }

    func searchBowelMovements(query: String) -> [SearchResult] {
        let movements = bowelMovementRepository.getAllBowelMovements()

        return movements.compactMap { movement in
            let typeNumber = Int(movement.type)
            let typeDescription = movement.bristolStoolType.description
            let consistency = movement.bristolStoolType.consistency
            let contextSnippet = "Type \(typeNumber) - \(typeDescription)"

            // Create searchable text from notes and type description
            var searchableTexts: [(String, String)] = [] // (text, context)

            if let notes = movement.notes, !notes.isEmpty {
                searchableTexts.append((notes, notes))
            }

            // Add type number searches (e.g., "2" or "Type 2")
            let typeString = "\(typeNumber)"
            searchableTexts.append((typeString, contextSnippet))

            let typeWithLabel = "Type \(typeNumber)"
            searchableTexts.append((typeWithLabel, contextSnippet))

            // Add description and consistency
            searchableTexts.append((typeDescription, contextSnippet))
            searchableTexts.append((consistency, contextSnippet))

            // Search in all texts
            for (searchText, context) in searchableTexts {
                if let range = searchText.range(of: query, options: .caseInsensitive) {
                    // Get corresponding DailyLog for this date
                    let log = logsRepository.getLogForDate(movement.date) ?? DailyLog(date: movement.date)

                    return SearchResult(
                        log: log,
                        matchedCategory: .bowelMovements,
                        matchedText: String(searchText[range]),
                        contextSnippet: context,
                        matchRange: range,
                        bowelMovement: movement
                    )
                }
            }

            return nil
        }
    }

    // MARK: - Helper Methods

    private func extractContextSnippet(from text: String, matchRange: Range<String.Index>, query: String, contextChars: Int = 50) -> String {
        let startIndex = text.index(matchRange.lowerBound, offsetBy: -contextChars, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(matchRange.upperBound, offsetBy: contextChars, limitedBy: text.endIndex) ?? text.endIndex

        var snippet = String(text[startIndex..<endIndex])

        // Add ellipsis if we're not at the boundaries
        if startIndex != text.startIndex {
            snippet = "..." + snippet
        }
        if endIndex != text.endIndex {
            snippet = snippet + "..."
        }

        return snippet
    }
}

// MARK: - Protocol Conformance
extension SearchRepo: SearchRepositoryProtocol {}
