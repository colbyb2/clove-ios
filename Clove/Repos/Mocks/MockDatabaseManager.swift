import Foundation
import GRDB

/// Mock implementation of DatabaseManaging for testing and previews
final class MockDatabaseManager: DatabaseManaging {
    /// Controls whether operations succeed or fail
    var shouldSucceed: Bool = true

    /// Tracks setup calls
    var setupCallCount: Int = 0

    /// Tracks reset calls
    var resetCallCount: Int = 0

    func setupDatabase() throws {
        setupCallCount += 1
        if !shouldSucceed {
            throw DatabaseError.notSetup
        }
    }

    func resetDatabase() throws {
        resetCallCount += 1
        if !shouldSucceed {
            throw DatabaseError.notSetup
        }
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        if !shouldSucceed {
            throw DatabaseError.notSetup
        }
        // Note: This is a mock - in real tests you'd use an in-memory database
        // For now, we'll just throw an error since we can't create a real Database without setup
        throw DatabaseError.notSetup
    }

    func write(_ block: (Database) throws -> Void) throws {
        if !shouldSucceed {
            throw DatabaseError.notSetup
        }
        // Note: This is a mock - in real tests you'd use an in-memory database
        throw DatabaseError.notSetup
    }

    func writeReturning<T>(_ block: (Database) throws -> T) throws -> T {
        if !shouldSucceed {
            throw DatabaseError.notSetup
        }
        // Note: This is a mock - in real tests you'd use an in-memory database
        throw DatabaseError.notSetup
    }
}
