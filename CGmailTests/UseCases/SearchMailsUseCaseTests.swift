import XCTest
@testable import CGmail

final class SearchMailsUseCaseTests: XCTestCase {
    func test_emptyQuery_returnsEmpty() async throws {
        let mock = MockMailRepository()
        let useCase = SearchMailsUseCase(mailRepository: mock)
        let result = try await useCase.execute(accountId: "acc1", query: "  ")
        XCTAssertTrue(result.isEmpty)
    }
}
