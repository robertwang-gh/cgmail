import Foundation

enum LabelType: String, Codable, Sendable {
    case system
    case user
}

struct LabelColor: Codable, Hashable, Sendable {
    let backgroundColor: String
    let textColor: String
}

struct Label: Identifiable, Hashable, Sendable {
    let id: String
    let accountId: String
    let name: String
    let type: LabelType
    let unreadCount: Int
    let totalCount: Int
    let color: LabelColor?

    static let systemOrder = ["INBOX", "STARRED", "SENT", "DRAFTS", "TRASH"]
}
