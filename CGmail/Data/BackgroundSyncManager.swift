import Foundation
import AppKit

@MainActor
final class BackgroundSyncManager: ObservableObject {
    static let shared = BackgroundSyncManager()

    private var timer: Timer?
    private weak var container: AppDependencyContainer?

    private init() {}

    func configure(container: AppDependencyContainer) {
        self.container = container
    }

    func startForegroundSync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
            }
        }
    }

    func stopForegroundSync() {
        timer?.invalidate()
        timer = nil
    }

    func syncAll() async {
        guard let container else { return }
        let accounts = (try? await container.accountRepo.fetchAccounts()) ?? []
        let syncUseCase = container.makeSyncAccountUseCase()
        for account in accounts {
            try? await syncUseCase.execute(accountId: account.id)
        }
        container.refreshDockBadge()
    }
}
