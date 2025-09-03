import Foundation

enum ImportError: LocalizedError {
    case fileReadError
    case invalidFileFormat
    case invalidCSVStructure
    case missingRequiredColumns([String])
    case unexpectedColumns([String])
    case invalidDateFormat(String)
    case invalidDataValue(column: String, value: String, row: Int)
    case databaseError(String)
    case noDataToImport
    case importCancelled
    
    var errorDescription: String? {
        switch self {
        case .fileReadError:
            return "Unable to read the selected file"
        case .invalidFileFormat:
            return "Invalid file format. Please select a CSV file"
        case .invalidCSVStructure:
            return "Invalid CSV structure. File appears to be corrupted"
        case .missingRequiredColumns(let columns):
            return "Missing required columns: \(columns.joined(separator: ", "))"
        case .unexpectedColumns(let columns):
            return "Unexpected columns found: \(columns.joined(separator: ", "))"
        case .invalidDateFormat(let date):
            return "Invalid date format in row: \(date)"
        case .invalidDataValue(let column, let value, let row):
            return "Invalid value '\(value)' in column '\(column)' at row \(row)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .noDataToImport:
            return "No valid data found to import"
        case .importCancelled:
            return "Import was cancelled"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileReadError:
            return "Please check file permissions and try again"
        case .invalidFileFormat:
            return "Export your data from Clove to see the expected CSV format"
        case .invalidCSVStructure:
            return "Try re-saving the file as CSV in a spreadsheet application"
        case .missingRequiredColumns:
            return "Ensure your CSV was exported from Clove or includes all required columns"
        case .unexpectedColumns:
            return "Remove any extra columns not supported by Clove"
        case .invalidDateFormat:
            return "Dates should be in MM/dd/yyyy format"
        case .invalidDataValue:
            return "Check that all values are within expected ranges"
        case .databaseError:
            return "Try restarting the app and importing again"
        case .noDataToImport:
            return "Ensure your CSV file contains data rows"
        case .importCancelled:
            return "You can retry the import at any time"
        }
    }
}

struct ImportResult {
    let success: Bool
    let importedLogsCount: Int
    let createdSymptomsCount: Int
    let createdBowelMovementsCount: Int
    let skippedRowsCount: Int
    let errors: [ImportError]
    let warnings: [String]
    
    static let empty = ImportResult(
        success: false,
        importedLogsCount: 0,
        createdSymptomsCount: 0,
        createdBowelMovementsCount: 0,
        skippedRowsCount: 0,
        errors: [],
        warnings: []
    )
}