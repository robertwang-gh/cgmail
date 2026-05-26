import Foundation

enum CGmailError: Error, Sendable {
    case networkUnavailable
    case authExpired
    case rateLimited(retryAfter: TimeInterval)
    case apiError(code: Int, message: String)
    case databaseError(underlying: Error)
    case sendFailed(underlying: Error)
}
