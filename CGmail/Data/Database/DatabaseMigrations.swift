import Foundation
import GRDB

enum DatabaseMigrations {
    static func migrate(_ writer: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "accounts") { t in
                t.primaryKey("id", .text)
                t.column("email", .text).notNull()
                t.column("displayName", .text).notNull()
            }

            try db.create(table: "labels") { t in
                t.primaryKey("id", .text)
                t.column("accountId", .text).notNull().references("accounts", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("unreadCount", .integer).notNull().defaults(to: 0)
                t.column("totalCount", .integer).notNull().defaults(to: 0)
                t.column("colorBackground", .text)
                t.column("colorText", .text)
            }

            try db.create(table: "mails") { t in
                t.primaryKey("id", .text)
                t.column("accountId", .text).notNull().references("accounts", onDelete: .cascade)
                t.column("threadId", .text).notNull()
                t.column("fromEmail", .text).notNull()
                t.column("fromName", .text)
                t.column("toJson", .text).notNull()
                t.column("subject", .text).notNull()
                t.column("snippet", .text).notNull()
                t.column("date", .datetime).notNull()
                t.column("labelIds", .text).notNull()
                t.column("isRead", .boolean).notNull().defaults(to: false)
                t.column("isStarred", .boolean).notNull().defaults(to: false)
                t.column("hasAttachment", .boolean).notNull().defaults(to: false)
            }
            try db.create(indexOn: "mails", columns: ["accountId", "date"])

            try db.create(table: "mail_bodies") { t in
                t.primaryKey("mailId", .text).references("mails", onDelete: .cascade)
                t.column("body", .text).notNull()
            }

            try db.create(table: "sync_state") { t in
                t.primaryKey("accountId", .text).references("accounts", onDelete: .cascade)
                t.column("historyId", .text)
            }
        }

        try migrator.migrate(writer)
    }
}
