import Foundation

protocol AccountRepositoryProtocol: Sendable {
    func fetchAccounts() async throws -> [Account]
    func addAccount(_ account: Account, tokens: AccountTokens) async throws
    func removeAccount(id: String) async throws
    func getTokens(accountId: String) async throws -> AccountTokens
    func updateTokens(accountId: String, tokens: AccountTokens) async throws
}
