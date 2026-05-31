import Foundation
import AppKit

@MainActor
final class GmailAuthService {
    static let shared = GmailAuthService()
    private let accountRepo: AccountRepositoryImpl

    init(accountRepo: AccountRepositoryImpl = AccountRepositoryImpl()) {
        self.accountRepo = accountRepo
    }

    /// Run `otter login google-workspace` to open the browser OAuth flow,
    /// then `otter gws-token` to get the access token.
    func signIn() async throws -> Account {
        // Step 1: Login (opens browser — user completes OAuth consent)
        try await runOtterLogin()

        // Step 2: Get token
        let token = try await getOtterToken()

        // Step 3: Fetch user profile from Gmail API
        let profile = try await fetchUserProfile(accessToken: token)

        let account = Account(
            id: profile.emailAddress,
            email: profile.emailAddress,
            displayName: profile.emailAddress
        )
        let tokens = AccountTokens(
            accessToken: token,
            refreshToken: "",  // otter handles refresh internally
            expiryDate: Date().addingTimeInterval(3500)  // ~1 hour
        )
        try await accountRepo.addAccount(account, tokens: tokens)
        return account
    }

    /// Get a fresh access token (otter handles refresh internally).
    func refreshTokenIfNeeded(accountId: String) async throws -> String {
        return try await getOtterToken()
    }

    func getOtterToken() async throws -> String {
        let result = try await runCommand("/usr/local/bin/otter", arguments: ["gws-token"])
        let token = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw CGmailError.authExpired
        }
        return token
    }

    private func runOtterLogin() async throws {
        // otter login opens a browser — it returns when complete or times out
        _ = try? await runCommand("/usr/local/bin/otter", arguments: ["login", "google-workspace"])
    }

    private func runCommand(_ path: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                // Try common otter locations
                let otterPaths = ["/usr/local/bin/otter", "/opt/homebrew/bin/otter",
                                  "/usr/bin/otter", (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/.local/bin/otter"]

                var execPath = path
                if !FileManager.default.fileExists(atPath: path) {
                    execPath = otterPaths.first { FileManager.default.fileExists(atPath: $0) } ?? path
                }

                process.executableURL = URL(fileURLWithPath: execPath)
                process.arguments = arguments

                // Pass through PATH so otter can find its dependencies
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: CGmailError.authExpired)
                    }
                } catch {
                    continuation.resume(throwing: CGmailError.networkUnavailable)
                }
            }
        }
    }

    private struct GmailProfile: Decodable {
        let emailAddress: String
        let messagesTotal: Int?
        let threadsTotal: Int?
        let historyId: String?
    }

    private func fetchUserProfile(accessToken: String) async throws -> GmailProfile {
        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CGmailError.authExpired
        }
        return try JSONDecoder().decode(GmailProfile.self, from: data)
    }
}
