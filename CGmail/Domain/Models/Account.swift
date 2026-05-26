import Foundation

struct Account: Identifiable, Hashable, Sendable {
    let id: String
    let email: String
    let displayName: String

    var initials: String {
        let parts = displayName.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}
