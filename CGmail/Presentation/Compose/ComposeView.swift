import SwiftUI

struct ComposeView: View {
    let accountId: String
    let mode: ComposeMode
    @EnvironmentObject var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ComposeViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                composeForm(vm: vm)
                    .onChange(of: vm.didSend) { _, sent in if sent { dismiss() } }
            } else {
                ProgressView()
            }
        }
        .task {
            let vm = ComposeViewModel(accountId: accountId, sendUseCase: container.makeSendMailUseCase())
            switch mode {
            case .reply(let mail):
                if let mail { vm.prefillReply(to: mail) }
            case .replyAll(let mail):
                if let mail { vm.prefillReply(to: mail) }
            case .forward(let mail):
                if let mail { vm.prefillForward(mail: mail) }
            case .new:
                break
            }
            viewModel = vm
        }
    }

    @ViewBuilder
    private func composeForm(vm: ComposeViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.plain)
                Spacer()
                Text(composeTitle).font(.headline)
                Spacer()
                Button {
                    Task { await vm.send() }
                } label: {
                    if vm.isSending {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        SwiftUI.Label("Send", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isSending)
            }
            .padding()
            Divider()
            VStack(spacing: 0) {
                composeField(label: "To", value: Binding(get: { vm.toField }, set: { vm.toField = $0 }))
                Divider()
                composeField(label: "Subject", value: Binding(get: { vm.subject }, set: { vm.subject = $0 }))
                Divider()
                TextEditor(text: Binding(get: { vm.body }, set: { vm.body = $0 }))
                    .font(.body)
                    .padding(8)
                    .frame(minHeight: 300)
            }
            if let error = vm.sendError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
            }
        }
        .frame(width: 600, height: 500)
    }

    @ViewBuilder
    private func composeField(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
            TextField("", text: value).textFieldStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var composeTitle: String {
        switch mode {
        case .new: "New Message"
        case .reply: "Reply"
        case .replyAll: "Reply All"
        case .forward: "Forward"
        }
    }
}
