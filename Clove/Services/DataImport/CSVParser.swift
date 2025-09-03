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
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard lines.count >= 2 else {
            throw ImportError.invalidCSVStructure
        }
        
        // Parse headers
        let headers = parseCSVLine(lines[0])
        guard !headers.isEmpty else {
            throw ImportError.invalidCSVStructure
        }
        
        // Create column mapping
        var columnMap: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            columnMap[header] = index
        }
        
        // Parse data rows
        var rows: [[String]] = []
        for i in 1..<lines.count {
            let row = parseCSVLine(lines[i])
            if row.count == headers.count {
                rows.append(row)
            }
            // Skip rows with incorrect column count (might be empty or malformed)
        }
        
        return ParsedCSVData(
            headers: headers,
            rows: rows,
            columnMap: columnMap
        )
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if inQuotes {
                    // Check if next character is also a quote (escaped quote)
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentField += "\""
                        i = line.index(after: nextIndex)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last field
        fields.append(currentField)
        
        return fields
    }
}