import Foundation
import GRDB

actor MailRepositoryImpl: MailRepositoryProtocol {
    private let db: DatabasePool
    private let makeAPIClient: @Sendable (String) -> GmailAPIClient?

    init(db: DatabasePool = LocalDatabase.shared.dbPool,
         makeAPIClient: @escaping @Sendable (String) -> GmailAPIClient?) {
        self.db = db
        self.makeAPIClient = makeAPIClient
    }

    nonisolated func mailStream(accountId: String, labelId: String) -> AsyncStream<[Mail]> {
        AsyncStream { continuation in
            Task {
                if let cached = try? await self.fetchCached(accountId: accountId, labelId: labelId) {
                    continuation.yield(cached)
                }
                try? await self.syncAccount(accountId: accountId)
                if let fresh = try? await self.fetchCached(accountId: accountId, labelId: labelId) {
                    continuation.yield(fresh)
                }
                continuation.finish()
            }
        }
    }

    private func fetchCached(accountId: String, labelId: String) async throws -> [Mail] {
        try await db.read { db in
            let records = try MailRecord
                .filter(Column("accountId") == accountId)
                .order(Column("date").desc)
                .fetchAll(db)
            return try records.filter { record in
                if let labels = try? JSONDecoder().decode([String].self, from: Data(record.labelIds.utf8)) {
                    return labels.contains(labelId)
                }
                return false
            }.map { try $0.toDomain() }
        }
    }

    func fetchMailBody(accountId: String, mailId: String) async throws -> String {
        if let cached = try await db.read({ db in try MailBodyRecord.fetchOne(db, key: mailId) }) {
            return cached.body
        }
        guard let client = makeAPIClient(accountId) else { throw CGmailError.authExpired }
        let dto = try await client.getMessageFull(id: mailId)
        let body = extractBody(from: dto.payload)
        try await db.write { db in
            try MailBodyRecord(mailId: mailId, body: body).upsert(db)
        }
        return body
    }

    func searchMails(accountId: String, query: String) async throws -> [Mail] {
        guard let client = makeAPIClient(accountId) else { throw CGmailError.authExpired }
        let list = try await client.searchMessages(query: query)
        let ids = list.messages?.map(\.id) ?? []
        return try await fetchMails(ids: ids, accountId: accountId, client: client)
    }

    func markAsRead(accountId: String, mailId: String) async throws {
        try await db.write { db in
            if var record = try MailRecord.fetchOne(db, key: mailId) {
                record.isRead = true
                try record.update(db)
            }
        }
        try? await makeAPIClient(accountId)?.modifyMessage(id: mailId, removeLabelIds: ["UNREAD"])
    }

    func star(accountId: String, mailId: String) async throws {
        try await updateFlag(mailId: mailId, isStarred: true)
        try? await makeAPIClient(accountId)?.modifyMessage(id: mailId, addLabelIds: ["STARRED"])
    }

    func unstar(accountId: String, mailId: String) async throws {
        try await updateFlag(mailId: mailId, isStarred: false)
        try? await makeAPIClient(accountId)?.modifyMessage(id: mailId, removeLabelIds: ["STARRED"])
    }

    func archive(accountId: String, mailId: String) async throws {
        try await removeLabel(mailId: mailId, labelId: "INBOX")
        try? await makeAPIClient(accountId)?.modifyMessage(id: mailId, removeLabelIds: ["INBOX"])
    }

    func trash(accountId: String, mailId: String) async throws {
        try await removeLabel(mailId: mailId, labelId: "INBOX")
        try? await makeAPIClient(accountId)?.modifyMessage(id: mailId, addLabelIds: ["TRASH"], removeLabelIds: ["INBOX"])
    }

    func sendMessage(accountId: String, rawBase64: String) async throws {
        guard let client = makeAPIClient(accountId) else { throw CGmailError.authExpired }
        try await client.sendMessage(rawBase64: rawBase64)
    }

    func syncAccount(accountId: String) async throws {
        guard let client = makeAPIClient(accountId) else { return }
        let syncState = try await db.read { db in try SyncStateRecord.fetchOne(db, key: accountId) }
        if let historyId = syncState?.historyId {
            try await incrementalSync(accountId: accountId, client: client, historyId: historyId)
        } else {
            try await fullSync(accountId: accountId, client: client)
        }
    }

    private func fullSync(accountId: String, client: GmailAPIClient) async throws {
        let labelList = try await client.listLabels()
        let labels = labelList.labels.map { dto -> Label in
            let type: LabelType = dto.type == "system" ? .system : .user
            let color = dto.color.map { LabelColor(backgroundColor: $0.backgroundColor, textColor: $0.textColor) }
            return Label(id: dto.id, accountId: accountId, name: dto.name, type: type,
                         unreadCount: dto.messagesUnread ?? 0, totalCount: dto.messagesTotal ?? 0, color: color)
        }
        try await db.write { db in
            for label in labels { try LabelRecord.from(label).upsert(db) }
        }
        let list = try await client.listMessages(maxResults: 100)
        let ids = list.messages?.map(\.id) ?? []
        let mails = try await fetchMails(ids: ids, accountId: accountId, client: client)
        try await db.write { db in
            for mail in mails { try MailRecord.from(mail).upsert(db) }
        }
        if let lastMail = mails.first, let historyId = try? await client.getMessage(id: lastMail.id).historyId {
            try await db.write { db in
                try SyncStateRecord(accountId: accountId, historyId: historyId).upsert(db)
            }
        }
    }

    private func incrementalSync(accountId: String, client: GmailAPIClient, historyId: String) async throws {
        let history = try await client.listHistory(startHistoryId: historyId)
        guard let changes = history.history, !changes.isEmpty else { return }
        var addedIds: [String] = []
        var deletedIds: [String] = []
        for change in changes {
            addedIds += change.messagesAdded?.map(\.message.id) ?? []
            deletedIds += change.messagesDeleted?.map(\.message.id) ?? []
        }
        if !deletedIds.isEmpty {
            let idsToDelete = deletedIds
            try await db.write { db in try MailRecord.filter(keys: idsToDelete).deleteAll(db) }
        }
        if !addedIds.isEmpty {
            let newMails = try await fetchMails(ids: addedIds, accountId: accountId, client: client)
            try await db.write { db in
                for mail in newMails { try MailRecord.from(mail).upsert(db) }
            }
        }
        if let newHistoryId = history.historyId {
            try await db.write { db in
                try SyncStateRecord(accountId: accountId, historyId: newHistoryId).upsert(db)
            }
        }
    }

    private func fetchMails(ids: [String], accountId: String, client: GmailAPIClient) async throws -> [Mail] {
        try await withThrowingTaskGroup(of: Mail?.self) { group in
            for id in ids {
                group.addTask {
                    guard let dto = try? await client.getMessage(id: id) else { return nil }
                    return self.mailFromDTO(dto, accountId: accountId)
                }
            }
            var result: [Mail] = []
            for try await mail in group {
                if let mail { result.append(mail) }
            }
            return result.sorted { $0.date > $1.date }
        }
    }

    nonisolated private func mailFromDTO(_ dto: MessageDTO, accountId: String) -> Mail {
        let headers = dto.payload?.headers ?? []
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? "(no subject)"
        let fromStr = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? ""
        let from = parseEmailAddress(fromStr)
        let toStr = headers.first(where: { $0.name.lowercased() == "to" })?.value ?? ""
        let date = dto.internalDate.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let labels = dto.labelIds ?? []
        return Mail(
            id: dto.id, threadId: dto.threadId, accountId: accountId,
            from: from, to: [parseEmailAddress(toStr)],
            subject: subject, snippet: dto.snippet ?? "",
            body: nil, date: date, labelIds: labels,
            isRead: !labels.contains("UNREAD"),
            isStarred: labels.contains("STARRED"),
            hasAttachment: checkHasAttachment(dto.payload)
        )
    }

    nonisolated private func parseEmailAddress(_ raw: String) -> EmailAddress {
        if raw.contains("<") {
            let parts = raw.components(separatedBy: "<")
            let name = parts[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let email = parts[1].replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespaces)
            return EmailAddress(name: name.isEmpty ? nil : name, email: email)
        }
        return EmailAddress(name: nil, email: raw.trimmingCharacters(in: .whitespaces))
    }

    nonisolated private func checkHasAttachment(_ payload: PayloadDTO?) -> Bool {
        guard let parts = payload?.parts else { return false }
        return parts.contains { $0.mimeType?.hasPrefix("application/") == true || $0.mimeType?.hasPrefix("image/") == true }
    }

    nonisolated private func extractBody(from payload: PayloadDTO?) -> String {
        guard let payload else { return "" }
        if let data = payload.body?.data, !data.isEmpty {
            let padded = data.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            if let decoded = Data(base64Encoded: padded, options: .ignoreUnknownCharacters),
               let str = String(data: decoded, encoding: .utf8) { return str }
        }
        for part in payload.parts ?? [] {
            let body = extractBody(from: part)
            if !body.isEmpty { return body }
        }
        return ""
    }

    private func updateFlag(mailId: String, isStarred: Bool) async throws {
        try await db.write { db in
            if var record = try MailRecord.fetchOne(db, key: mailId) {
                record.isStarred = isStarred
                try record.update(db)
            }
        }
    }

    private func removeLabel(mailId: String, labelId: String) async throws {
        try await db.write { db in
            guard var record = try MailRecord.fetchOne(db, key: mailId) else { return }
            if var labels = try? JSONDecoder().decode([String].self, from: Data(record.labelIds.utf8)) {
                labels.removeAll { $0 == labelId }
                record.labelIds = String(data: (try? JSONEncoder().encode(labels)) ?? Data(), encoding: .utf8) ?? "[]"
                try record.update(db)
            }
        }
    }
}
