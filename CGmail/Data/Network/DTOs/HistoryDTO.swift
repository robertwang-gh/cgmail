import Foundation

struct HistoryListDTO: Decodable {
    let history: [HistoryDTO]?
    let historyId: String?
    let nextPageToken: String?
}

struct HistoryDTO: Decodable {
    let id: String?
    let messagesAdded: [HistoryMessageDTO]?
    let messagesDeleted: [HistoryMessageDTO]?
    let labelsAdded: [HistoryLabelDTO]?
    let labelsRemoved: [HistoryLabelDTO]?
}

struct HistoryMessageDTO: Decodable {
    let message: MessageRefDTO
}

struct HistoryLabelDTO: Decodable {
    let message: MessageRefDTO
    let labelIds: [String]
}
