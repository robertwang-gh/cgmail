import GRDB

struct AccountRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "accounts"
    var id: String
    var email: String
    var displayName: String

    func toDomain() -> Account {
        Account(id: id, email: email, displayName: displayName)
    }

    static func from(_ account: Account) -> AccountRecord {
        AccountRecord(id: account.id, email: account.email, displayName: account.displayName)
    }
}
