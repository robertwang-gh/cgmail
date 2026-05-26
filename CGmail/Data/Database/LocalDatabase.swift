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
        let pool = try DatabasePool(path: ":memory:")
        try DatabaseMigrations.migrate(pool)
        return pool
    }
}
