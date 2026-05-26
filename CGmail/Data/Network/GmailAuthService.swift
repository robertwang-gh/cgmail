import Foundation
import GoogleSignIn
import AppKit

@MainActor
final class GmailAuthService {
    static let shared = GmailAuthService()
    private let accountRepo: AccountRepositoryImpl

    init(accountRepo: AccountRepositoryImpl = AccountRepositoryImpl()) {
        self.accountRepo = accountRepo
    }

    func signIn(presentingWindow: NSWindow) async throws -> Account {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingWindow,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/gmail.modify"]
        )
        let user = result.user
        guard let profile = user.profile else {
            throw CGmailError.authExpired
        }
        let account = Account(
            id: user.userID ?? UUID().uuidString,
            email: profile.email,
            displayName: profile.name
        )
        let tokens = AccountTokens(
            accessToken: user.accessToken.tokenString,
            refreshToken: user.refreshToken.tokenString,
            expiryDate: user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
        )
        try await accountRepo.addAccount(account, tokens: tokens)
        return account
    }

    func refreshTokenIfNeeded(accountId: String) async throws -> String {
        let tokens = try await accountRepo.getTokens(accountId: accountId)
        if !tokens.isExpired { return tokens.accessToken }
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw CGmailError.authExpired
        }
        try await user.refreshTokensIfNeeded()
        let newToken = user.accessToken.tokenString
        let newExpiry = user.accessToken.expirationDate ?? Date().addingTimeInterval(3600)
        let newTokens = AccountTokens(accessToken: newToken, refreshToken: tokens.refreshToken, expiryDate: newExpiry)
        try await accountRepo.updateTokens(accountId: accountId, tokens: newTokens)
        return newToken
    }

    func restorePreviousSignIn() async {
        try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }
}
