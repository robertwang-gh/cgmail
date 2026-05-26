import Foundation

struct EmailAddress: Codable, Hashable, Sendable {
    let name: String?
    let email: String

    var displayName: String { name ?? email }
}

struct Mail: Identifiable, Hashable, Sendable {
    let id: String
    let threadId: String
    let accountId: String
    let from: EmailAddress
    let to: [EmailAddress]
    let subject: String
    let snippet: String
    let body: String?
    let date: Date
    let labelIds: [String]
    let isRead: Bool
    let isStarred: Bool
    let hasAttachment: Bool

    var isInbox: Bool { labelIds.contains("INBOX") }
}
