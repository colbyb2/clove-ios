import Foundation

struct SearchResult: Identifiable {
    let id: UUID
    let log: DailyLog
    let matchedCategory: SearchCategory
    let matchedText: String
    let contextSnippet: String
    let matchRange: Range<String.Index>
    let bowelMovement: BowelMovement?

    init(
        id: UUID = UUID(),
        log: DailyLog,
        matchedCategory: SearchCategory,
        matchedText: String,
        contextSnippet: String,
        matchRange: Range<String.Index>,
        bowelMovement: BowelMovement? = nil
    ) {
        self.id = id
        self.log = log
        self.matchedCategory = matchedCategory
        self.matchedText = matchedText
        self.contextSnippet = contextSnippet
        self.matchRange = matchRange
        self.bowelMovement = bowelMovement
    }
}
