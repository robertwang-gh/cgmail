import Foundation

struct SendMailUseCase {
    private let mailRepository: any MailRepositoryProtocol
    init(mailRepository: any MailRepositoryProtocol) { self.mailRepository = mailRepository }

    struct Request {
        let accountId: String
        let to: [EmailAddress]
        let subject: String
        let body: String
        let replyToMailId: String?
        let isForward: Bool
    }

    func execute(_ request: Request) async throws {
        let toField = request.to.map { addr -> String in
            if let name = addr.name { return "\(name) <\(addr.email)>" }
            return addr.email
        }.joined(separator: ", ")
        let messageBody = "To: \(toField)\r\nSubject: \(request.subject)\r\nContent-Type: text/html; charset=utf-8\r\n\r\n\(request.body)"
        let base64 = Data(messageBody.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        try await mailRepository.sendMessage(accountId: request.accountId, rawBase64: base64)
    }
}
