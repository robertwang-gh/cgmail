import Foundation

struct MessageListDTO: Decodable {
    let messages: [MessageRefDTO]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct MessageRefDTO: Decodable {
    let id: String
    let threadId: String
}
