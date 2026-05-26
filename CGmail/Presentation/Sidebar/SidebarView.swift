import SwiftUI

struct SidebarView: View {
    @Binding var selectedAccountId: String?
    @Binding var selectedLabelId: String
    @EnvironmentObject var container: AppDependencyContainer
    @State private var viewModel: SidebarViewModel?
    @State private var showAddAccount = false

    private let systemLabelIcons: [String: String] = [
        "INBOX": "tray", "STARRED": "star", "SENT": "paperplane",
        "DRAFTS": "doc", "TRASH": "trash", "SPAM": "exclamationmark.shield"
    ]

    var body: some View {
        List {
            ForEach(viewModel?.accounts ?? [], id: \.id) { account in
                Section {
                    accountLabels(account: account)
                } header: {
                    accountHeader(account: account)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button(action: { showAddAccount = true }) {
                SwiftUI.Label("Add Account", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .task {
            let vm = SidebarViewModel(accountRepo: container.accountRepo, db: container.db)
            viewModel = vm
            await vm.load()
            if selectedAccountId == nil {
                selectedAccountId = viewModel?.accounts.first?.id
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView()
                .onDisappear {
                    Task { await viewModel?.load() }
                }
        }
    }

    @ViewBuilder
    private func accountHeader(account: Account) -> some View {
        HStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 22, height: 22)
                .overlay(Text(account.initials).font(.caption2).foregroundStyle(.white))
            Text(account.email).font(.caption).lineLimit(1)
        }
    }

    @ViewBuilder
    private func accountLabels(account: Account) -> some View {
        let labels = viewModel?.labels[account.id] ?? []
        ForEach(labels, id: \.id) { mailLabel in
            SwiftUI.Label {
                HStack {
                    Text(mailLabel.name)
                    Spacer()
                    if mailLabel.unreadCount > 0 {
                        Text("\(mailLabel.unreadCount)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } icon: {
                if let icon = systemLabelIcons[mailLabel.id] {
                    Image(systemName: icon)
                } else {
                    Circle()
                        .fill(Color(hex: mailLabel.color?.backgroundColor ?? "#4285F4"))
                        .frame(width: 8, height: 8)
                        .padding(4)
                }
            }
            .onTapGesture {
                selectedAccountId = account.id
                selectedLabelId = mailLabel.id
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
