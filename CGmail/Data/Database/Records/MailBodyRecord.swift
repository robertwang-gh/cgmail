import GRDB

struct MailBodyRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "mail_bodies"
    var mailId: String
    var body: String
}
