import AppKit
import GRDB

@MainActor
final class DockBadgeManager {
    static let shared = DockBadgeManager()
    private var db: DatabasePool { LocalDatabase.shared.dbPool }

    private init() {}

    func updateBadge() async {
        let count = (try? await fetchTotalUnread()) ?? 0
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    private func fetchTotalUnread() async throws -> Int {
        try await db.read { db in
            try MailRecord
                .filter(Column("isRead") == false)
                .fetchAll(db)
                .filter { record in
                    record.labelIds.contains("INBOX")
                }
                .count
        }
    }
}
