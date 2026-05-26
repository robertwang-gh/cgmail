import Foundation

protocol MailRepositoryProtocol: Sendable {
    func mailStream(accountId: String, labelId: String) -> AsyncStream<[Mail]>
    func fetchMailBody(accountId: String, mailId: String) async throws -> String
    func searchMails(accountId: String, query: String) async throws -> [Mail]
    func markAsRead(accountId: String, mailId: String) async throws
    func star(accountId: String, mailId: String) async throws
    func unstar(accountId: String, mailId: String) async throws
    func archive(accountId: String, mailId: String) async throws
    func trash(accountId: String, mailId: String) async throws
    func syncAccount(accountId: String) async throws
    func sendMessage(accountId: String, rawBase64: String) async throws
}
