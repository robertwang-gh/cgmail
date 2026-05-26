import Foundation

struct LabelListDTO: Decodable {
    let labels: [LabelDTO]
}

struct LabelDTO: Decodable {
    let id: String
    let name: String
    let type: String?
    let messagesUnread: Int?
    let messagesTotal: Int?
    let color: LabelColorDTO?
}

struct LabelColorDTO: Decodable {
    let backgroundColor: String
    let textColor: String
}
