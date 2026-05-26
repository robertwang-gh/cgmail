import Foundation
import GRDB
import Observation

@Observable
@MainActor
final class SidebarViewModel {
    var accounts: [Account] = []
    var labels: [String: [Label]] = [:]
    var isLoading = false
    var errorMessage: String?

    private let accountRepo: AccountRepositoryImpl
    private let db: DatabasePool

    init(accountRepo: AccountRepositoryImpl, db: DatabasePool) {
        self.accountRepo = accountRepo
        self.db = db
    }

    func load() async {
        do {
            accounts = try await accountRepo.fetchAccounts()
            for account in accounts {
                labels[account.id] = try await fetchLabels(accountId: account.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchLabels(accountId: String) async throws -> [Label] {
        try await db.read { db in
            try LabelRecord
                .filter(Column("accountId") == accountId)
                .fetchAll(db)
                .map { $0.toDomain() }
                .sorted { a, b in
                    let orderA = Label.systemOrder.firstIndex(of: a.id) ?? 99
                    let orderB = Label.systemOrder.firstIndex(of: b.id) ?? 99
                    return orderA < orderB
                }
        }
    }
}
