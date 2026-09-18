import Foundation

enum RepositoryOperation: String {
    case read
    case write
}

struct RepositoryError: LocalizedError {
    let operation: RepositoryOperation
    let resource: String
    let diagnostic: String
    let occurredAt: Date

    init(
        operation: RepositoryOperation,
        resource: String,
        underlyingError: Error,
        occurredAt: Date = Date()
    ) {
        self.operation = operation
        self.resource = resource
        self.diagnostic = String(reflecting: underlyingError)
        self.occurredAt = occurredAt
    }

    init(
        operation: RepositoryOperation,
        resource: String,
        diagnostic: String,
        occurredAt: Date = Date()
    ) {
        self.operation = operation
        self.resource = resource
        self.diagnostic = diagnostic
        self.occurredAt = occurredAt
    }

    var errorDescription: String? {
        switch operation {
        case .read:
            "Clove couldn't load your \(resource)."
        case .write:
            "Clove couldn't save your \(resource)."
        }
    }

    var recoverySuggestion: String? {
        "Your existing data has not been removed. Please try again."
    }

    var exportText: String {
        """
        Clove local diagnostic
        Time: \(occurredAt.formatted(.iso8601))
        Operation: \(operation.rawValue)
        Resource: \(resource)
        Detail: \(diagnostic)
        """
    }
}

