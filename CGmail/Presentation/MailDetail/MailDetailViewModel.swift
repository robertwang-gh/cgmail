import Foundation
import GRDB
import Observation

@Observable
@MainActor
final class MailDetailViewModel {
    var mail: Mail?
    var body: String = ""
    var isLoading = false

    private let mailRepository: MailRepositoryImpl

    init(mailRepository: MailRepositoryImpl) {
        self.mailRepository = mailRepository
    }

    func load(accountId: String, mailId: String) async {
        isLoading = true
        do {
            body = try await mailRepository.fetchMailBody(accountId: accountId, mailId: mailId)
            if !body.contains("<") {
                body = body.replacingOccurrences(of: "\n", with: "<br>")
            }
            try await mailRepository.markAsRead(accountId: accountId, mailId: mailId)
            mail = await loadMailMeta(accountId: accountId, mailId: mailId)
        } catch {
            body = "<p>Failed to load message: \(error.localizedDescription)</p>"
        }
        isLoading = false
    }

    func archive(accountId: String, mailId: String) async {
        try? await mailRepository.archive(accountId: accountId, mailId: mailId)
    }

    func trash(accountId: String, mailId: String) async {
        try? await mailRepository.trash(accountId: accountId, mailId: mailId)
    }

    func toggleStar(accountId: String, mail: Mail) async {
        if mail.isStarred {
            try? await mailRepository.unstar(accountId: accountId, mailId: mail.id)
        } else {
            try? await mailRepository.star(accountId: accountId, mailId: mail.id)
        }
        self.mail = await loadMailMeta(accountId: accountId, mailId: mail.id)
    }

    private func loadMailMeta(accountId: String, mailId: String) async -> Mail? {
        let db = LocalDatabase.shared.dbPool
        return try? await db.read { db in
            try MailRecord.fetchOne(db, key: mailId).flatMap { try? $0.toDomain() }
        }
    }
}
