import Foundation
import GRDB

enum CustomMetricKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case number, count, yesNo, rating, duration
    var id: String { rawValue }
    var title: String {
        switch self { case .number: "Number"; case .count: "Count"; case .yesNo: "Yes / No"; case .rating: "Rating"; case .duration: "Duration" }
    }
    var icon: String {
        switch self { case .number: "number"; case .count: "plus.forwardslash.minus"; case .yesNo: "checkmark.circle"; case .rating: "slider.horizontal.3"; case .duration: "clock" }
    }
    var detail: String {
        switch self {
        case .number: "A measurement, with an optional unit"
        case .count: "A daily total, such as steps or repetitions"
        case .yesNo: "An explicit yes or no for the day"
        case .rating: "Your own scale, such as 1–5 or 0–10"
        case .duration: "A daily total in hours and minutes"
        }
    }
}

struct CustomMetricDefinition: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    var id: String = UUID().uuidString.lowercased()
    var name: String = ""
    var kind: CustomMetricKind = .number
    var unit: String = ""
    var precision: Int = 0
    var ratingMin: Int = 0
    var ratingMax: Int = 10
    var icon: String = "number"
    var colorHex: String = "8b7cf8"
    var displayOrder: Int = 0
    var isEnabled: Bool = true
    var hasRecordedValues: Bool = false
    var archivedAt: Date?
    var createdAt: Date = Date()
    static let databaseTableName = "customMetricDefinition"
    var metricID: MetricID { MetricID(rawValue: "custom:\(id)") }
    var isActive: Bool { isEnabled && archivedAt == nil }
    var configurationLabel: String {
        switch kind {
        case .number, .count: unit.isEmpty ? kind.title : "\(kind.title) · \(unit)"
        case .rating: "Rating · \(ratingMin)–\(ratingMax)"
        case .duration: "Hours & minutes"
        case .yesNo: "Yes / No"
        }
    }
    func validate() throws {
        guard UUID(uuidString: id) != nil, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 60, unit.count <= 20, (0...3).contains(precision),
              ratingMin >= 0, ratingMin < ratingMax, ratingMax <= 100 else {
            throw CustomMetricError.invalidDefinition
        }
    }
    func sameMeasurement(as other: Self) -> Bool {
        kind == other.kind && unit == other.unit && precision == other.precision && ratingMin == other.ratingMin && ratingMax == other.ratingMax
    }
    func format(_ value: CustomDailyValue) -> String {
        if kind == .yesNo { return value.booleanValue == true ? "Yes" : "No" }
        if kind == .duration {
            let minutes = value.durationMinutes ?? 0
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        let number = (value.numberValue ?? 0).formatted(.number.precision(.fractionLength(0...precision)))
        if kind == .rating { return "\(number) / \(ratingMax)" }
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

struct CustomDailyValue: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var metricID: String
    var dayKey: String
    var numberValue: Double?
    var booleanValue: Bool?
    var durationMinutes: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    static let databaseTableName = "customDailyValue"
    var numericValue: Double? { numberValue ?? booleanValue.map { $0 ? 1 : 0 } ?? durationMinutes.map(Double.init) }
    func validate(for definition: CustomMetricDefinition) throws {
        guard metricID == definition.id,
              let date = LocalDayKey.date(from: dayKey), LocalDayKey.make(for: date) == dayKey,
              [numberValue != nil, booleanValue != nil, durationMinutes != nil].filter({ $0 }).count == 1 else {
            throw CustomMetricError.invalidValue
        }
        switch definition.kind {
        case .number, .count, .rating:
            guard let numberValue, numberValue.isFinite, abs(numberValue) <= 1_000_000_000_000 else { throw CustomMetricError.invalidValue }
            guard var decimal = Decimal(string: String(numberValue), locale: Locale(identifier: "en_US_POSIX")) else { throw CustomMetricError.invalidValue }
            var rounded = Decimal()
            NSDecimalRound(&rounded, &decimal, definition.kind == .number ? definition.precision : 0, .plain)
            guard decimal == rounded else { throw CustomMetricError.invalidValue }
            if definition.kind == .count, numberValue < 0 { throw CustomMetricError.invalidValue }
            if definition.kind == .rating, !(Double(definition.ratingMin)...Double(definition.ratingMax)).contains(numberValue) { throw CustomMetricError.invalidValue }
        case .yesNo:
            guard booleanValue != nil else { throw CustomMetricError.invalidValue }
        case .duration:
            guard let durationMinutes, (0...525_600).contains(durationMinutes) else { throw CustomMetricError.invalidValue }
        }
    }
}

enum CustomMetricError: LocalizedError {
    case invalidDefinition, invalidValue, measurementLocked, missingDefinition
    var errorDescription: String? {
        switch self {
        case .invalidDefinition: "Enter a name (up to 60 characters), a unit (up to 20), and a valid rating range between 0 and 100."
        case .invalidValue: "Enter a valid value using this metric’s unit, range, and decimal precision."
        case .measurementLocked: "This metric has history. Create a new metric to change its input type, unit, precision, or rating range."
        case .missingDefinition: "This metric is no longer available. Your other entries have not been changed."
        }
    }
}

struct CustomMetricRecord: Identifiable, Equatable {
    var id: String { definition.id }
    let definition: CustomMetricDefinition
    let value: CustomDailyValue
}

enum CustomMetricInput {
    /// Parse the whole input; NumberFormatter alone can accept a valid prefix followed by junk.
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let decimal = locale.decimalSeparator ?? "."
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: decimal, with: ".")
        guard normalized.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
