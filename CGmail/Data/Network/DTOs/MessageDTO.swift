import Foundation

struct MessageDTO: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let internalDate: String?
    let payload: PayloadDTO?
    let historyId: String?
}

struct PayloadDTO: Decodable {
    let headers: [HeaderDTO]?
    let body: BodyDTO?
    let parts: [PayloadDTO]?
    let mimeType: String?
}

struct HeaderDTO: Decodable {
    let name: String
    let value: String
}

struct BodyDTO: Decodable {
    let data: String?
    let size: Int?
}
