import Foundation
import GRDB

/// Protocol defining database operations for dependency injection
protocol DatabaseManaging {
    /// Sets up the database connection and applies migrations
    /// - Throws: Error if database setup fails
    func setupDatabase() throws

    /// Resets the database by deleting and recreating it
    /// - Throws: Error if the reset operation fails
    func resetDatabase() throws

    /// Executes a read operation on the database
    /// - Parameter block: The block to execute with database access
    /// - Returns: The result of the block
    /// - Throws: Error if the operation fails
    func read<T>(_ block: (Database) throws -> T) throws -> T

    /// Executes a write operation on the database
    /// - Parameter block: The block to execute with database access
    /// - Throws: Error if the operation fails
    func write(_ block: (Database) throws -> Void) throws

    /// Executes a write operation on the database and returns a value
    /// - Parameter block: The block to execute with database access
    /// - Returns: The result of the block
    /// - Throws: Error if the operation fails
    func writeReturning<T>(_ block: (Database) throws -> T) throws -> T
}

/// Conform DatabaseManager to the protocol
extension DatabaseManager: DatabaseManaging {}
