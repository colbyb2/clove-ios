import Foundation

enum CustomMetricsCSV {
    static let headers = ["Date", "Metric ID", "Metric Name", "Input Type", "Unit", "Value"]
    static func content(definitions: [CustomMetricDefinition], values: [CustomDailyValue]) -> String {
        let byID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        let rows = values.sorted { ($0.dayKey, $0.metricID) < ($1.dayKey, $1.metricID) }.compactMap { value -> String? in
            guard let definition = byID[value.metricID] else { return nil }
            let raw: String
            if let boolean = value.booleanValue { raw = boolean ? "Yes" : "No" }
            else if let duration = value.durationMinutes { raw = String(duration) }
            else if let number = value.numberValue { raw = String(number) }
            else { return nil }
            return [value.dayKey, definition.id, definition.name, definition.kind.rawValue,
                    definition.kind == .duration ? "minutes" : definition.unit, raw].map(escape).joined(separator: ",")
        }
        return ([headers.joined(separator: ",")] + rows).joined(separator: "\n")
    }
    static func export(repository: any CustomMetricsRepositoryProtocol = CustomMetricsRepo.shared) throws -> URL {
        let values = try repository.allValues()
        guard !values.isEmpty else { throw DataExportError.noData }
        let csv = content(definitions: try repository.definitions(), values: values)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Clove-Custom-Metrics-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    private static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }
}
