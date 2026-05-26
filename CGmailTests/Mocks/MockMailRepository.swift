import Foundation
@testable import CGmail

final class MockMailRepository: MailRepositoryProtocol, @unchecked Sendable {
    var stubbedMails: [Mail] = []
    var markAsReadCalled = false
    var starCalled = false
    var archiveCalled = false
    var sendCalled = false

    func mailStream(accountId: String, labelId: String) -> AsyncStream<[Mail]> {
        AsyncStream { continuation in
            continuation.yield(stubbedMails.filter { $0.labelIds.contains(labelId) })
            continuation.finish()
        }
    }

    func fetchMailBody(accountId: String, mailId: String) async throws -> String { "<p>body</p>" }
    func searchMails(accountId: String, query: String) async throws -> [Mail] {
        stubbedMails.filter { $0.subject.contains(query) }
    }
    func markAsRead(accountId: String, mailId: String) async throws { markAsReadCalled = true }
    func star(accountId: String, mailId: String) async throws { starCalled = true }
    func unstar(accountId: String, mailId: String) async throws {}
    func archive(accountId: String, mailId: String) async throws { archiveCalled = true }
    func trash(accountId: String, mailId: String) async throws {}
    func syncAccount(accountId: String) async throws {}
    func sendMessage(accountId: String, rawBase64: String) async throws { sendCalled = true }
}
