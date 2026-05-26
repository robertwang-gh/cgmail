import Foundation
import GRDB

final class LocalDatabase: Sendable {
    static let shared = LocalDatabase()
    let dbPool: DatabasePool

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CGmail", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dbURL = appSupport.appendingPathComponent("cgmail.db")
        dbPool = try! DatabasePool(path: dbURL.path)
        try! DatabaseMigrations.migrate(dbPool)
    }

    static func makeInMemory() throws -> DatabasePool {
        // DatabasePool requires WAL mode which is incompatible with pure in-memory
        // SQLite. Use a unique temp file that is deleted after creation so the pool
        // gets a fresh, empty database on every call.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cgmail-test-\(UUID().uuidString).db")
        let pool = try DatabasePool(path: url.path)
        try DatabaseMigrations.migrate(pool)
        return pool
    }
}
