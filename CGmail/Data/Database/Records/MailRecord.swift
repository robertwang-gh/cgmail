import Foundation
import GRDB

struct MailRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "mails"

    var id: String
    var accountId: String
    var threadId: String
    var fromEmail: String
    var fromName: String?
    var toJson: String
    var subject: String
    var snippet: String
    var date: Date
    var labelIds: String
    var isRead: Bool
    var isStarred: Bool
    var hasAttachment: Bool

    func toDomain() throws -> Mail {
        let decoder = JSONDecoder()
        let to = try decoder.decode([EmailAddress].self, from: Data(toJson.utf8))
        let labels = try decoder.decode([String].self, from: Data(labelIds.utf8))
        return Mail(
            id: id, threadId: threadId, accountId: accountId,
            from: EmailAddress(name: fromName, email: fromEmail),
            to: to, subject: subject, snippet: snippet, body: nil,
            date: date, labelIds: labels,
            isRead: isRead, isStarred: isStarred, hasAttachment: hasAttachment
        )
    }

    static func from(_ mail: Mail) throws -> MailRecord {
        let encoder = JSONEncoder()
        let toJson = String(data: try encoder.encode(mail.to), encoding: .utf8)!
        let labelsJson = String(data: try encoder.encode(mail.labelIds), encoding: .utf8)!
        return MailRecord(
            id: mail.id, accountId: mail.accountId, threadId: mail.threadId,
            fromEmail: mail.from.email, fromName: mail.from.name,
            toJson: toJson, subject: mail.subject, snippet: mail.snippet,
            date: mail.date, labelIds: labelsJson,
            isRead: mail.isRead, isStarred: mail.isStarred, hasAttachment: mail.hasAttachment
        )
    }
}
