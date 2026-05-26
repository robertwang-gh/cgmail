import XCTest
import GRDB
@testable import CGmail

final class AccountRepositoryTests: XCTestCase {
    var repo: AccountRepositoryImpl!

    override func setUp() async throws {
        let db = try LocalDatabase.makeInMemory()
        repo = AccountRepositoryImpl(db: db, keychain: KeychainHelper(service: "com.cgmail.test.\(UUID().uuidString)"))
    }

    func test_addAndFetch_returnsAccount() async throws {
        let account = Account(id: "acc1", email: "test@gmail.com", displayName: "Test User")
        let tokens = AccountTokens(accessToken: "at", refreshToken: "rt", expiryDate: Date().addingTimeInterval(3600))
        try await repo.addAccount(account, tokens: tokens)
        let accounts = try await repo.fetchAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].email, "test@gmail.com")
    }

    func test_removeAccount_deletesIt() async throws {
        let account = Account(id: "acc1", email: "test@gmail.com", displayName: "Test")
        let tokens = AccountTokens(accessToken: "at", refreshToken: "rt", expiryDate: Date().addingTimeInterval(3600))
        try await repo.addAccount(account, tokens: tokens)
        try await repo.removeAccount(id: "acc1")
        let accounts = try await repo.fetchAccounts()
        XCTAssertTrue(accounts.isEmpty)
    }

    func test_getTokens_returnsStoredTokens() async throws {
        let account = Account(id: "acc1", email: "test@gmail.com", displayName: "Test")
        let tokens = AccountTokens(accessToken: "my-access-token", refreshToken: "my-refresh-token",
                                   expiryDate: Date().addingTimeInterval(3600))
        try await repo.addAccount(account, tokens: tokens)
        let loaded = try await repo.getTokens(accountId: "acc1")
        XCTAssertEqual(loaded.accessToken, "my-access-token")
        XCTAssertEqual(loaded.refreshToken, "my-refresh-token")
    }
}
