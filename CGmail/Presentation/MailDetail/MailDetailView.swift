import SwiftUI

enum ComposeMode {
    case new
    case reply(to: Mail?)
    case replyAll(to: Mail?)
    case forward(mail: Mail?)
}

struct MailDetailView: View {
    let accountId: String
    let mailId: String
    @EnvironmentObject var container: AppDependencyContainer
    @State private var viewModel: MailDetailViewModel?
    @State private var showCompose = false
    @State private var composeMode: ComposeMode = .new

    var body: some View {
        Group {
            if let vm = viewModel {
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerSection(vm: vm)
                            Divider()
                            HTMLBodyView(html: vm.body)
                                .frame(minHeight: 400)
                        }
                        .padding()
                    }
                    .toolbar {
                        ToolbarItem {
                            Button {
                                Task { await vm.archive(accountId: accountId, mailId: mailId) }
                            } label: {
                                SwiftUI.Label("Archive", systemImage: "archivebox")
                            }
                        }
                        ToolbarItem {
                            Button {
                                Task { await vm.trash(accountId: accountId, mailId: mailId) }
                            } label: {
                                SwiftUI.Label("Trash", systemImage: "trash")
                            }
                        }
                        ToolbarItem {
                            Button {
                                let mail = vm.mail
                                if let mail {
                                    Task { await vm.toggleStar(accountId: accountId, mail: mail) }
                                }
                            } label: {
                                SwiftUI.Label("Star", systemImage: vm.mail?.isStarred == true ? "star.fill" : "star")
                                    .foregroundStyle(vm.mail?.isStarred == true ? Color.yellow : Color.primary)
                            }
                        }
                        ToolbarItem {
                            Button {
                                composeMode = .reply(to: vm.mail)
                                showCompose = true
                            } label: {
                                SwiftUI.Label("Reply", systemImage: "arrowshape.turn.up.left")
                            }
                        }
                        ToolbarItem {
                            Button {
                                composeMode = .forward(mail: vm.mail)
                                showCompose = true
                            } label: {
                                SwiftUI.Label("Forward", systemImage: "arrowshape.turn.up.right")
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeView(accountId: accountId, mode: composeMode)
        }
        .task(id: mailId) {
            let repo = container.makeMailRepository()
            let vm = MailDetailViewModel(mailRepository: repo)
            viewModel = vm
            await vm.load(accountId: accountId, mailId: mailId)
        }
    }

    @ViewBuilder
    private func headerSection(vm: MailDetailViewModel) -> some View {
        if let mail = vm.mail {
            VStack(alignment: .leading, spacing: 8) {
                Text(mail.subject).font(.title3.bold())
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(mail.from.displayName.prefix(1)))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mail.from.displayName).font(.subheadline.bold())
                        Text(mail.from.email).font(.caption).foregroundStyle(.secondary)
                        Text(mail.date.formatted(date: .long, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
