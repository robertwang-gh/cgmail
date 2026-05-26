import GRDB

struct LabelRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "labels"
    var id: String
    var accountId: String
    var name: String
    var type: String
    var unreadCount: Int
    var totalCount: Int
    var colorBackground: String?
    var colorText: String?

    func toDomain() -> Label {
        let color: LabelColor? = colorBackground.map {
            LabelColor(backgroundColor: $0, textColor: colorText ?? "#000000")
        }
        return Label(id: id, accountId: accountId, name: name,
                     type: LabelType(rawValue: type) ?? .user,
                     unreadCount: unreadCount, totalCount: totalCount, color: color)
    }

    static func from(_ label: Label) -> LabelRecord {
        LabelRecord(id: label.id, accountId: label.accountId, name: label.name,
                    type: label.type.rawValue, unreadCount: label.unreadCount,
                    totalCount: label.totalCount,
                    colorBackground: label.color?.backgroundColor,
                    colorText: label.color?.textColor)
    }
}
