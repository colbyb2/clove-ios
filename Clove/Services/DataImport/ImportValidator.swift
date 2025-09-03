import Foundation

class ImportValidator {
    
    // Expected column order based on DataManager export format
    static let expectedColumns: [String] = [
        "Date", "Mood", "Pain Level", "Energy Level", "Flare Day", 
        "Weather", "Bowel Movements", "Medications", "Meals", "Activities", "Notes"
    ]
    
    static func validateHeaders(_ headers: [String]) throws {
        // Check for required Date column
        guard headers.contains("Date") else {
            throw ImportError.missingRequiredColumns(["Date"])
        }
        
        // Check for unexpected columns
        let expectedSet = Set(expectedColumns)
        let actualSet = Set(headers)
        let unexpectedColumns = actualSet.subtracting(expectedSet)
        
        if !unexpectedColumns.isEmpty {
            throw ImportError.unexpectedColumns(Array(unexpectedColumns))
        }
    }
    
    static func validateRowData(_ row: [String], headers: [String], rowNumber: Int) throws {
        guard row.count == headers.count else {
            throw ImportError.invalidCSVStructure
        }
        
        for (index, value) in row.enumerated() {
            let column = headers[index]
            try validateCellValue(value, for: column, at: rowNumber)
        }
    }
    
    private static func validateCellValue(_ value: String, for column: String, at row: Int) throws {
        // Skip validation for empty values (they're optional)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        switch column {
        case "Date":
            if !isValidDate(value) {
                throw ImportError.invalidDateFormat(value)
            }
            
        case "Mood", "Pain Level", "Energy Level":
            if let intValue = Int(value), intValue >= 1 && intValue <= 10 {
                // Valid
            } else {
                throw ImportError.invalidDataValue(column: column, value: value, row: row)
            }
            
        case "Flare Day":
            if !["Yes", "No", "true", "false", "1", "0"].contains(value) {
                throw ImportError.invalidDataValue(column: column, value: value, row: row)
            }
            
        case "Bowel Movements":
            // Validate bowel movement format: "Type X (time); Type Y (time)"
            if !value.isEmpty {
                try validateBowelMovementFormat(value, at: row)
            }
            
        case "Weather":
            // Weather is free text, any value is acceptable
            break
            
        case "Medications", "Meals", "Activities", "Notes":
            // These are free text fields, any value is acceptable
            break
            
        default:
            // Might be a symptom column, validate as numeric rating
            if let intValue = Int(value), intValue >= 0 && intValue <= 10 {
                // Valid symptom rating
            } else {
                throw ImportError.invalidDataValue(column: column, value: value, row: row)
            }
        }
    }
    
    private static func isValidDate(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.date(from: dateString) != nil
    }
    
    private static func validateBowelMovementFormat(_ value: String, at row: Int) throws {
        // Expected format: "Type 3 (2:30 PM); Type 4 (5:45 PM)"
        let movements = value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for movement in movements {
            guard movement.hasPrefix("Type ") else {
                throw ImportError.invalidDataValue(column: "Bowel Movements", value: value, row: row)
            }
            
            // Extract type number
            let typeString = movement.dropFirst(5) // Remove "Type "
            if let parenIndex = typeString.firstIndex(of: "(") {
                let typeNumber = String(typeString[..<parenIndex]).trimmingCharacters(in: .whitespaces)
                guard let type = Int(typeNumber), type >= 1 && type <= 7 else {
                    throw ImportError.invalidDataValue(column: "Bowel Movements", value: value, row: row)
                }
            }
        }
    }
    
    static func extractSymptomColumns(from headers: [String]) -> [String] {
        return headers.filter { header in
            !expectedColumns.contains(header)
        }
    }
}