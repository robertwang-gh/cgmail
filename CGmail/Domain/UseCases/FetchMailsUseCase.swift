import Foundation

struct FetchMailsUseCase {
    private let mailRepository: any MailRepositoryProtocol
    init(mailRepository: any MailRepositoryProtocol) { self.mailRepository = mailRepository }

    func execute(accountId: String, labelId: String) -> AsyncStream<[Mail]> {
        mailRepository.mailStream(accountId: accountId, labelId: labelId)
    }
}
