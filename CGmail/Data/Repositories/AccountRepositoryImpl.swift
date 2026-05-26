import Foundation
import GRDB

actor AccountRepositoryImpl: AccountRepositoryProtocol {
    private let db: DatabasePool
    private let keychain: KeychainHelper

    init(db: DatabasePool = LocalDatabase.shared.dbPool,
         keychain: KeychainHelper = KeychainHelper()) {
        self.db = db
        self.keychain = keychain
    }

    func fetchAccounts() async throws -> [Account] {
        try await db.read { db in
            try AccountRecord.fetchAll(db).map { $0.toDomain() }
        }
    }

    func addAccount(_ account: Account, tokens: AccountTokens) async throws {
        try await db.write { db in
            try AccountRecord.from(account).upsert(db)
            try SyncStateRecord(accountId: account.id, historyId: nil).upsert(db)
        }
        try saveTokens(accountId: account.id, tokens: tokens)
    }

    func removeAccount(id: String) async throws {
        try await db.write { db in
            try AccountRecord.deleteOne(db, key: id)
        }
        try? keychain.delete(account: tokenKey(id))
    }

    func getTokens(accountId: String) async throws -> AccountTokens {
        let data = try keychain.load(account: tokenKey(accountId))
        return try JSONDecoder().decode(AccountTokens.self, from: data)
    }

    func updateTokens(accountId: String, tokens: AccountTokens) async throws {
        try saveTokens(accountId: accountId, tokens: tokens)
    }

    private func saveTokens(accountId: String, tokens: AccountTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try keychain.save(data: data, account: tokenKey(accountId))
    }

    private func tokenKey(_ accountId: String) -> String { "tokens-\(accountId)" }
}
