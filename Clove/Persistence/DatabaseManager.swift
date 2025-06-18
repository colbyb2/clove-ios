import Foundation
import GRDB

/// DatabaseManager provides a centralized access point for database operations
/// using GRDB and SQLite.
class DatabaseManager {
    // MARK: - Singleton
    
    /// The shared instance of DatabaseManager
    static let shared = DatabaseManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Properties
    
    /// The database queue for serialized access to the database
    private var dbQueue: DatabaseQueue?
    
    /// Path to the SQLite database file
    private let dbPath: String = {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("clove.sqlite").path
    }()
    
    // MARK: - Database Setup
    
    /// Convenience method to setup the database with app's migrations
    func setupDatabase() throws {
        try setup(migrations: Migrations.all)
        print("Database setup complete")
    }
    
    /// Sets up the database connection and schema
    /// - Parameter migrations: Optional array of migrations to apply
    /// - Throws: Error if database setup fails
    func setup(migrations: [Migration] = []) throws {
        // Create database queue with standard SQLite configuration
        let configuration = Configuration()
        dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
        
        // Apply migrations
        guard let queue = dbQueue else {
            throw DatabaseError.notSetup
        }
        
        // Create a migration manager
        var migrator = DatabaseMigrator()
        
        // Register all migrations
        for migration in migrations {
            migrator.registerMigration(migration.identifier) { db in
                try migration.migrate(db)
            }
        }
        
        // Apply migrations to the database
        try migrator.migrate(queue)
    }
    
    // MARK: - Database Access
    
    /// Executes a read operation on the database
    /// - Parameter block: The block to execute
    /// - Returns: The result of the block
    /// - Throws: Error if the operation fails
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notSetup
        }
        
        return try dbQueue.read(block)
    }
    
    /// Executes a write operation on the database
    /// - Parameter block: The block to execute
    /// - Throws: Error if the operation fails
    func write(_ block: (Database) throws -> Void) throws {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notSetup
        }
        
        try dbQueue.write(block)
    }
    
    /// Executes a write operation on the database and returns a value
    /// - Parameter block: The block to execute
    /// - Returns: The result of the block
    /// - Throws: Error if the operation fails
    func writeReturning<T>(_ block: (Database) throws -> T) throws -> T {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notSetup
        }
        
        return try dbQueue.write(block)
    }
}

// MARK: - Supporting Types

/// Protocol for database migrations
protocol Migration {
    var identifier: String { get }
    func migrate(_ db: Database) throws
}

/// Database-related errors
enum DatabaseError: Error {
    case notSetup
}
