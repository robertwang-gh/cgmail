import Foundation
import Observation

@Observable
@MainActor
final class ComposeViewModel {
    var toField: String = ""
    var subject: String = ""
    var body: String = ""
    var isSending = false
    var sendError: String?
    var didSend = false

    private let sendUseCase: SendMailUseCase
    let accountId: String

    init(accountId: String, sendUseCase: SendMailUseCase) {
        self.accountId = accountId
        self.sendUseCase = sendUseCase
    }

    func prefillReply(to mail: Mail) {
        toField = mail.from.email
        subject = mail.subject.hasPrefix("Re:") ? mail.subject : "Re: \(mail.subject)"
        body = "\n\n--- Original Message ---\n\(mail.snippet)"
    }

    func prefillForward(mail: Mail) {
        subject = "Fwd: \(mail.subject)"
        body = "\n\n--- Forwarded Message ---\n\(mail.snippet)"
    }

    func send() async {
        guard !toField.isEmpty, !subject.isEmpty else {
            sendError = "To and Subject fields are required."
            return
        }
        isSending = true
        sendError = nil
        let emails = toField.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { EmailAddress(name: nil, email: $0) }
        let request = SendMailUseCase.Request(
            accountId: accountId,
            to: emails,
            subject: subject,
            body: body.replacingOccurrences(of: "\n", with: "<br>"),
            replyToMailId: nil,
            isForward: false
        )
        do {
            try await sendUseCase.execute(request)
            didSend = true
        } catch {
            sendError = "Failed to send: \(error.localizedDescription)"
        }
        isSending = false
    }
}
