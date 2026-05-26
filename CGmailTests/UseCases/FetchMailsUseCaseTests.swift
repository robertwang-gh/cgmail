import XCTest
@testable import CGmail

final class FetchMailsUseCaseTests: XCTestCase {
    func test_execute_returnsMailsForLabel() async throws {
        let mock = MockMailRepository()
        mock.stubbedMails = [
            Mail(id: "1", threadId: "t1", accountId: "acc1",
                 from: EmailAddress(name: "Alice", email: "alice@example.com"),
                 to: [], subject: "Hello", snippet: "Hi",
                 body: nil, date: Date(), labelIds: ["INBOX"],
                 isRead: false, isStarred: false, hasAttachment: false)
        ]
        let useCase = FetchMailsUseCase(mailRepository: mock)
        var result: [[Mail]] = []
        for await mails in useCase.execute(accountId: "acc1", labelId: "INBOX").prefix(1) {
            result.append(mails)
        }
        XCTAssertEqual(result.first?.count, 1)
        XCTAssertEqual(result.first?.first?.subject, "Hello")
    }
}
