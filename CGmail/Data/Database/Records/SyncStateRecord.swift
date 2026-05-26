import GRDB

struct SyncStateRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sync_state"
    var accountId: String
    var historyId: String?
}
