import XCTest
@testable import CGmail

final class KeychainHelperTests: XCTestCase {
    let helper = KeychainHelper(service: "com.cgmail.test")

    override func tearDown() async throws {
        try? helper.delete(account: "testAccount")
    }

    func test_saveAndLoad_roundtrips() throws {
        let data = "secret-value".data(using: .utf8)!
        try helper.save(data: data, account: "testAccount")
        let loaded = try helper.load(account: "testAccount")
        XCTAssertEqual(loaded, data)
    }

    func test_delete_removesItem() throws {
        let data = "value".data(using: .utf8)!
        try helper.save(data: data, account: "testAccount")
        try helper.delete(account: "testAccount")
        XCTAssertThrowsError(try helper.load(account: "testAccount"))
    }

    func test_save_overwritesExisting() throws {
        let data1 = "first".data(using: .utf8)!
        let data2 = "second".data(using: .utf8)!
        try helper.save(data: data1, account: "testAccount")
        try helper.save(data: data2, account: "testAccount")
        let loaded = try helper.load(account: "testAccount")
        XCTAssertEqual(loaded, data2)
    }
}
