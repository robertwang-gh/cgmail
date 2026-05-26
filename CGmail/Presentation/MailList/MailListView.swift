import SwiftUI

struct MailListView: View {
    let accountId: String
    let labelId: String
    @Binding var selectedMailId: String?
    @EnvironmentObject var container: AppDependencyContainer
    @State private var viewModel: MailListViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    searchBar(vm: vm)
                    Divider()
                    if vm.isLoading && vm.mails.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if vm.mails.isEmpty {
                        ContentUnavailableView("No Messages", systemImage: "tray")
                    } else {
                        List(vm.mails, id: \.id, selection: $selectedMailId) { mail in
                            MailRowView(mail: mail).tag(mail.id)
                        }
                        .listStyle(.plain)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: "\(accountId)-\(labelId)") {
            let vm = MailListViewModel(
                accountId: accountId, labelId: labelId,
                fetchUseCase: container.makeFetchMailsUseCase(),
                searchUseCase: container.makeSearchMailsUseCase()
            )
            viewModel = vm
            await vm.loadMails()
        }
    }

    @ViewBuilder
    private func searchBar(vm: MailListViewModel) -> some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search mail", text: Binding(
                get: { vm.searchQuery },
                set: { vm.searchQuery = $0 }
            ))
            .textFieldStyle(.plain)
            .onSubmit { Task { await vm.search() } }
            if !vm.searchQuery.isEmpty {
                Button(action: {
                    vm.searchQuery = ""
                    Task { await vm.loadMails() }
                }) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.regularMaterial)
    }
}

struct MailRowView: View {
    let mail: Mail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(mail.from.displayName)
                    .font(.subheadline)
                    .fontWeight(mail.isRead ? .regular : .semibold)
                    .lineLimit(1)
                Spacer()
                Text(mail.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if mail.isStarred {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                }
                if mail.hasAttachment {
                    Image(systemName: "paperclip").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(mail.subject)
                .font(.subheadline)
                .fontWeight(mail.isRead ? .regular : .medium)
                .lineLimit(1)
            Text(mail.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            if !mail.isRead {
                Circle().fill(.blue).frame(width: 8, height: 8).offset(x: -12)
            }
        }
    }
}
