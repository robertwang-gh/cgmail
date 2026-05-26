import Foundation

struct AccountTokens: Sendable, Codable {
    let accessToken: String
    let refreshToken: String
    let expiryDate: Date

    var isExpired: Bool { expiryDate < Date() }
}
