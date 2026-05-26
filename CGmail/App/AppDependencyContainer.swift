import Foundation
import GRDB

@MainActor
final class AppDependencyContainer: ObservableObject {
    static let shared = AppDependencyContainer()

    let db: DatabasePool
    let accountRepo: AccountRepositoryImpl
    private var apiClients: [String: GmailAPIClient] = [:]

    private init() {
        db = LocalDatabase.shared.dbPool
        accountRepo = AccountRepositoryImpl(db: db)
    }

    func makeAPIClient(accountId: String) -> GmailAPIClient? {
        apiClients[accountId]
    }

    func registerAPIClient(_ client: GmailAPIClient, for accountId: String) {
        apiClients[accountId] = client
    }

    func makeFetchMailsUseCase() -> FetchMailsUseCase {
        FetchMailsUseCase(mailRepository: makeMailRepository())
    }

    func makeSearchMailsUseCase() -> SearchMailsUseCase {
        SearchMailsUseCase(mailRepository: makeMailRepository())
    }

    func makeSendMailUseCase() -> SendMailUseCase {
        SendMailUseCase(mailRepository: makeMailRepository())
    }

    func makeSyncAccountUseCase() -> SyncAccountUseCase {
        SyncAccountUseCase(mailRepository: makeMailRepository())
    }

    func makeMailRepository() -> MailRepositoryImpl {
        let clients = apiClients
        return MailRepositoryImpl(db: db, makeAPIClient: { accountId in
            clients[accountId]
        })
    }

    func refreshDockBadge() {
        Task {
            await DockBadgeManager.shared.updateBadge()
        }
    }
}
