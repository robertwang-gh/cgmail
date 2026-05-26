import Foundation

struct SearchMailsUseCase {
    private let mailRepository: any MailRepositoryProtocol
    init(mailRepository: any MailRepositoryProtocol) { self.mailRepository = mailRepository }

    func execute(accountId: String, query: String) async throws -> [Mail] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await mailRepository.searchMails(accountId: accountId, query: query)
    }
}
