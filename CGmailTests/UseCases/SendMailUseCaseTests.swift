import XCTest
@testable import CGmail

final class SendMailUseCaseTests: XCTestCase {
    func test_send_callsRepository() async throws {
        let mock = MockMailRepository()
        let useCase = SendMailUseCase(mailRepository: mock)
        let request = SendMailUseCase.Request(
            accountId: "acc1",
            to: [EmailAddress(name: "Bob", email: "bob@example.com")],
            subject: "Test", body: "<p>Hello</p>",
            replyToMailId: nil, isForward: false
        )
        try await useCase.execute(request)
        XCTAssertTrue(mock.sendCalled)
    }
}
