import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var container: AppDependencyContainer
    @State private var selectedAccountId: String?
    @State private var selectedLabelId: String = "INBOX"
    @State private var selectedMailId: String?
    @State private var showCompose = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedAccountId: $selectedAccountId,
                selectedLabelId: $selectedLabelId
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } content: {
            if let accountId = selectedAccountId {
                MailListView(
                    accountId: accountId,
                    labelId: selectedLabelId,
                    selectedMailId: $selectedMailId
                )
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            } else {
                ContentUnavailableView("No Account", systemImage: "envelope",
                                       description: Text("Add a Gmail account to get started"))
            }
        } detail: {
            if let mailId = selectedMailId, let accountId = selectedAccountId {
                MailDetailView(accountId: accountId, mailId: mailId)
            } else {
                ContentUnavailableView("Select a message", systemImage: "envelope.open")
            }
        }
        .sheet(isPresented: $showCompose) {
            if let accountId = selectedAccountId {
                ComposeView(accountId: accountId, mode: .new)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .composeNewMail)) { _ in
            showCompose = true
        }
        .task {
            container.refreshDockBadge()
            for await _ in NotificationCenter.default.notifications(named: .unreadCountChanged).map({ _ in () }) {
                container.refreshDockBadge()
            }
        }
    }
}
