import Foundation
@testable import CGmail

final class MockAccountRepository: AccountRepositoryProtocol, @unchecked Sendable {
    var accounts: [Account] = []
    var tokens: [String: AccountTokens] = [:]

    func fetchAccounts() async throws -> [Account] { accounts }
    func addAccount(_ account: Account, tokens: AccountTokens) async throws {
        accounts.append(account)
        self.tokens[account.id] = tokens
    }
    func removeAccount(id: String) async throws { accounts.removeAll { $0.id == id } }
    func getTokens(accountId: String) async throws -> AccountTokens {
        guard let t = tokens[accountId] else { throw CGmailError.authExpired }
        return t
    }
    func updateTokens(accountId: String, tokens: AccountTokens) async throws {
        self.tokens[accountId] = tokens
    }
}
