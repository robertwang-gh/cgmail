import Foundation
import Observation

@Observable
@MainActor
final class MailListViewModel {
    var mails: [Mail] = []
    var searchQuery: String = ""
    var isLoading = false

    private let fetchUseCase: FetchMailsUseCase
    private let searchUseCase: SearchMailsUseCase
    let accountId: String
    var labelId: String

    init(accountId: String, labelId: String,
         fetchUseCase: FetchMailsUseCase, searchUseCase: SearchMailsUseCase) {
        self.accountId = accountId
        self.labelId = labelId
        self.fetchUseCase = fetchUseCase
        self.searchUseCase = searchUseCase
    }

    func loadMails() async {
        isLoading = true
        for await mails in fetchUseCase.execute(accountId: accountId, labelId: labelId) {
            self.mails = mails
            isLoading = false
        }
        isLoading = false
    }

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            await loadMails()
            return
        }
        isLoading = true
        do {
            mails = try await searchUseCase.execute(accountId: accountId, query: searchQuery)
        } catch {
            print("Search error: \(error)")
        }
        isLoading = false
    }
}
