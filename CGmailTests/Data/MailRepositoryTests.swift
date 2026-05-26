import XCTest
import GRDB
@testable import CGmail

final class MailRepositoryTests: XCTestCase {
    var db: DatabasePool!
    var repo: MailRepositoryImpl!

    override func setUp() async throws {
        db = try LocalDatabase.makeInMemory()
        repo = MailRepositoryImpl(db: db, makeAPIClient: { _ in nil })
    }

    func makeMail(id: String, accountId: String, labelIds: [String] = ["INBOX"], isRead: Bool = false) throws -> Mail {
        Mail(id: id, threadId: "t\(id)", accountId: accountId,
             from: EmailAddress(name: "Test", email: "test@example.com"),
             to: [], subject: "Hello \(id)", snippet: "World",
             body: nil, date: Date(), labelIds: labelIds,
             isRead: isRead, isStarred: false, hasAttachment: false)
    }

    func test_mailStream_emitsCachedMails() async throws {
        let mail = try makeMail(id: "m1", accountId: "acc1")
        // Need account record for FK constraint
        try await db.write { db in
            try AccountRecord(id: "acc1", email: "a@b.com", displayName: "A").insert(db)
            try MailRecord.from(mail).upsert(db)
        }
        var received: [[Mail]] = []
        for await mails in repo.mailStream(accountId: "acc1", labelId: "INBOX").prefix(1) {
            received.append(mails)
        }
        XCTAssertEqual(received.first?.count, 1)
        XCTAssertEqual(received.first?.first?.id, "m1")
    }

    func test_markAsRead_updatesLocalRecord() async throws {
        let mail = try makeMail(id: "m1", accountId: "acc1")
        try await db.write { db in
            try AccountRecord(id: "acc1", email: "a@b.com", displayName: "A").insert(db)
            try MailRecord.from(mail).upsert(db)
        }
        try await repo.markAsRead(accountId: "acc1", mailId: "m1")
        let updated = try await db.read { db in try MailRecord.fetchOne(db, key: "m1") }
        XCTAssertEqual(updated?.isRead, true)
    }

    func test_archive_removesInboxLabel() async throws {
        let mail = try makeMail(id: "m1", accountId: "acc1", labelIds: ["INBOX", "UNREAD"])
        try await db.write { db in
            try AccountRecord(id: "acc1", email: "a@b.com", displayName: "A").insert(db)
            try MailRecord.from(mail).upsert(db)
        }
        try await repo.archive(accountId: "acc1", mailId: "m1")
        let cached = try await fetchCachedDirect(accountId: "acc1", labelId: "INBOX")
        XCTAssertTrue(cached.isEmpty)
    }

    private func fetchCachedDirect(accountId: String, labelId: String) async throws -> [Mail] {
        try await db.read { db in
            let records = try MailRecord.filter(Column("accountId") == accountId).fetchAll(db)
            return try records.filter { record in
                if let labels = try? JSONDecoder().decode([String].self, from: Data(record.labelIds.utf8)) {
                    return labels.contains(labelId)
                }
                return false
            }.map { try $0.toDomain() }
        }
    }
}
