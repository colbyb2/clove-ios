import Foundation

struct ParsedCSVData {
    let headers: [String]
    let rows: [[String]]
    let columnMap: [String: Int]
}

class CSVParser {
    
    static func parseCSV(from url: URL) throws -> ParsedCSVData {
        guard url.pathExtension.lowercased() == "csv" else {
            throw ImportError.invalidFileFormat
        }
        
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ImportError.fileReadError
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.noDataToImport
        }
        
        return try parseCSVContent(content)
    }
    
    private static func parseCSVContent(_ content: String) throws -> ParsedCSVData {
        let records = parseRecords(content)

        guard records.count >= 2 else {
            throw ImportError.invalidCSVStructure
        }

        let headers = records[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !headers.isEmpty else {
            throw ImportError.invalidCSVStructure
        }

        var columnMap: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            columnMap[header] = index
        }

        // Rows with an incorrect column count (empty or malformed) are skipped.
        let rows = records.dropFirst().filter { $0.count == headers.count }

        return ParsedCSVData(headers: headers, rows: Array(rows), columnMap: columnMap)
    }

    /// Splits CSV text into records of fields. Line breaks inside quoted
    /// fields belong to the field, so this scans the whole text rather than
    /// splitting into lines first. Blank records are dropped.
    private static func parseRecords(_ content: String) -> [[String]] {
        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false

        func endRecord() {
            fields.append(field)
            let blank = fields.count == 1
                && fields[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !blank { records.append(fields) }
            fields = []
            field = ""
        }

        var i = content.startIndex
        while i < content.endIndex {
            let char = content[i]
            if inQuotes {
                if char == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
                        field.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == "," {
                fields.append(field)
                field = ""
            } else if char.isNewline {
                endRecord()
            } else {
                field.append(char)
            }
            i = content.index(after: i)
        }
        endRecord()
        return records
    }
}
