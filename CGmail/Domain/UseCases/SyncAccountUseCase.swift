import Foundation

struct SyncAccountUseCase {
    private let mailRepository: any MailRepositoryProtocol
    init(mailRepository: any MailRepositoryProtocol) { self.mailRepository = mailRepository }

    func execute(accountId: String) async throws {
        try await mailRepository.syncAccount(accountId: accountId)
    }
}
