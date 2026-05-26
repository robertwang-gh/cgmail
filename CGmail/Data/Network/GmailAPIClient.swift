import Foundation

actor GmailAPIClient {
    private let baseURL = "https://gmail.googleapis.com"
    private var accessToken: String
    private let session: URLSession

    init(accessToken: String, session: URLSession = .shared) {
        self.accessToken = accessToken
        self.session = session
    }

    func updateAccessToken(_ token: String) {
        self.accessToken = token
    }

    func buildRequest(path: String, method: String, queryItems: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    func listMessages(labelIds: [String] = ["INBOX"], maxResults: Int = 50, pageToken: String? = nil) async throws -> MessageListDTO {
        var items = [URLQueryItem(name: "maxResults", value: "\(maxResults)")]
        labelIds.forEach { items.append(URLQueryItem(name: "labelIds", value: $0)) }
        if let token = pageToken { items.append(URLQueryItem(name: "pageToken", value: token)) }
        let request = try buildRequest(path: "/gmail/v1/users/me/messages", method: "GET", queryItems: items)
        return try await perform(request)
    }

    func getMessage(id: String, format: String = "metadata") async throws -> MessageDTO {
        let request = try buildRequest(
            path: "/gmail/v1/users/me/messages/\(id)",
            method: "GET",
            queryItems: [URLQueryItem(name: "format", value: format)]
        )
        return try await perform(request)
    }

    func getMessageFull(id: String) async throws -> MessageDTO {
        try await getMessage(id: id, format: "full")
    }

    func listLabels() async throws -> LabelListDTO {
        let request = try buildRequest(path: "/gmail/v1/users/me/labels", method: "GET")
        return try await perform(request)
    }

    func listHistory(startHistoryId: String, historyTypes: [String] = ["messageAdded","messageDeleted","labelAdded","labelRemoved"]) async throws -> HistoryListDTO {
        var items = [URLQueryItem(name: "startHistoryId", value: startHistoryId)]
        historyTypes.forEach { items.append(URLQueryItem(name: "historyTypes", value: $0)) }
        let request = try buildRequest(path: "/gmail/v1/users/me/history", method: "GET", queryItems: items)
        return try await perform(request)
    }

    func modifyMessage(id: String, addLabelIds: [String] = [], removeLabelIds: [String] = []) async throws {
        let body = try JSONEncoder().encode(["addLabelIds": addLabelIds, "removeLabelIds": removeLabelIds])
        let request = try buildRequest(path: "/gmail/v1/users/me/messages/\(id)/modify", method: "POST", body: body)
        let _: MessageDTO = try await perform(request)
    }

    func sendMessage(rawBase64: String) async throws {
        let body = try JSONEncoder().encode(["raw": rawBase64])
        let request = try buildRequest(path: "/gmail/v1/users/me/messages/send", method: "POST", body: body)
        let _: MessageDTO = try await perform(request)
    }

    func searchMessages(query: String, maxResults: Int = 50) async throws -> MessageListDTO {
        let request = try buildRequest(
            path: "/gmail/v1/users/me/messages",
            method: "GET",
            queryItems: [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: "\(maxResults)")]
        )
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CGmailError.networkUnavailable
        }
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw CGmailError.authExpired
        case 429:
            let retryAfter = Double(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw CGmailError.rateLimited(retryAfter: retryAfter)
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CGmailError.apiError(code: httpResponse.statusCode, message: msg)
        }
    }
}
