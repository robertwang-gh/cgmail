import XCTest
@testable import CGmail

final class GmailAPIClientTests: XCTestCase {
    func test_buildRequest_includesAuthHeader() async throws {
        let client = GmailAPIClient(accessToken: "test-token")
        let request = try await client.buildRequest(
            path: "/gmail/v1/users/me/messages",
            method: "GET",
            queryItems: [URLQueryItem(name: "maxResults", value: "10")]
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertTrue(request.url?.absoluteString.contains("maxResults=10") == true)
    }

    func test_buildRequest_setsCorrectHTTPMethod() async throws {
        let client = GmailAPIClient(accessToken: "test-token")
        let request = try await client.buildRequest(path: "/gmail/v1/users/me/messages", method: "POST")
        XCTAssertEqual(request.httpMethod, "POST")
    }
}
