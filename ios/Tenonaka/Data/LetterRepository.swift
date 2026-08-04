import Foundation

enum LetterError: LocalizedError {
    case notFound
    /// サーバーが返した理由をそのまま見せる(受け取り済みなど)
    case rejected(String)
    case badResponse(status: Int)
    case decoding
    case offline

    var errorDescription: String? {
        switch self {
        case .notFound: return "その符号の手紙はありません"
        case .rejected(let reason): return reason
        case .badResponse(let status): return "サーバーからの応答が不正です (\(status))"
        case .decoding: return "サーバーからの応答を解釈できませんでした"
        case .offline: return "サーバーに繋がりません"
        }
    }
}

/// NestJS の例外フィルタが返す形。message は文字列か文字列の配列。
private struct ServerErrorBody: Decodable {
    let message: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let single = try? container.decode(String.self, forKey: .message) {
            message = [single]
        } else {
            message = (try? container.decode([String].self, forKey: .message)) ?? []
        }
    }

    private enum CodingKeys: String, CodingKey { case message }
}

/// 手紙のやりとり。接続先は実行時に差し替えられるよう毎回 AppConfig から読む。
struct LetterRepository {
    private var baseURL: URL { AppConfig.apiBaseURL }
    private var userId: String { AppConfig.userId }
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        // 会場でサーバーが落ちていても UI が固まらないよう短めに切る
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        session = URLSession(configuration: configuration)
    }

    /// 脈を渡さないと送れない。ここがこのアプリの関門なので、引数から外せないようにしてある。
    func send(
        body: String,
        senderName: String?,
        recipientName: String?,
        bpm: Double
    ) async throws -> Letter {
        var payload: [String: Any] = ["body": body, "senderBpm": bpm]
        if let senderName = senderName?.nilIfBlank { payload["senderName"] = senderName }
        if let recipientName = recipientName?.nilIfBlank {
            payload["recipientName"] = recipientName
        }

        let data = try await send(
            path: "letters",
            method: "POST",
            payload: payload
        )
        return try decodeLetter(data)
    }

    func fetch(code: String) async throws -> Letter {
        let data = try await send(path: "letters/\(code.uppercased())", method: "GET")
        return try decodeLetter(data)
    }

    func listSent() async throws -> [Letter] {
        let data = try await send(path: "letters/sent", method: "GET")
        guard let dtos = try? JSONDecoder().decode([LetterDTO].self, from: data) else {
            throw LetterError.decoding
        }
        return dtos.map { $0.toDomain() }
    }

    /// 受け取った手紙の控え。本文は含まれない
    func listReceived() async throws -> [ReceivedLetter] {
        let data = try await send(path: "letters/received", method: "GET")
        guard let dtos = try? JSONDecoder().decode([ReceivedLetterDTO].self, from: data) else {
            throw LetterError.decoding
        }
        return dtos.map { $0.toDomain() }
    }

    /// 読まれ方を返す。内容への返信は含まない。
    func submitReceipt(code: String, receipt: ReadReceipt) async throws {
        _ = try await send(
            path: "letters/\(code.uppercased())/receipt",
            method: "POST",
            payload: [
                "heldSeconds": receipt.heldSeconds,
                "releaseCount": receipt.releaseCount,
                "completed": receipt.completed,
            ]
        )
    }

    // MARK: - 下請け

    private func decodeLetter(_ data: Data) throws -> Letter {
        guard let dto = try? JSONDecoder().decode(LetterDTO.self, from: data) else {
            throw LetterError.decoding
        }
        return dto.toDomain()
    }

    private func send(
        path: String,
        method: String,
        payload: [String: Any]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(userId, forHTTPHeaderField: "x-user-id")
        if let payload {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LetterError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw LetterError.decoding }
        if http.statusCode == 404 { throw LetterError.notFound }
        guard (200..<300).contains(http.statusCode) else {
            // 受け取り済みなどはサーバーの文言をそのまま読み手に見せたい
            if let body = try? JSONDecoder().decode(ServerErrorBody.self, from: data),
               let reason = body.message.first {
                throw LetterError.rejected(reason)
            }
            throw LetterError.badResponse(status: http.statusCode)
        }
        return data
    }
}

// MARK: - DTO

/// 日付は文字列で受けて自分で変換する。
/// サーバーは小数秒つきの ISO8601 を返すが、JSONDecoder の .iso8601 は小数秒を扱えない。
private struct LetterDTO: Decodable {
    // 受け取った手紙の控えでも同じ形なので共有する
    struct Receipt: Decodable {
        let heldSeconds: Double
        let releaseCount: Int
        let completed: Bool
        let readAt: String
    }

    let code: String
    let body: String
    let senderName: String?
    let recipientName: String?
    let senderBpm: Double?
    let sentAt: String
    let claimedAt: String?
    let receipt: Receipt?

    func toDomain() -> Letter {
        Letter(
            code: code,
            body: body,
            senderName: senderName,
            recipientName: recipientName,
            senderBpm: senderBpm,
            sentAt: ISO8601.date(from: sentAt) ?? Date(),
            claimedAt: claimedAt.flatMap(ISO8601.date(from:)),
            receipt: receipt.map {
                ReadReceipt(
                    heldSeconds: $0.heldSeconds,
                    releaseCount: $0.releaseCount,
                    completed: $0.completed,
                    readAt: ISO8601.date(from: $0.readAt) ?? Date()
                )
            }
        )
    }
}

/// 受け取った手紙の控え。本文が無いのが正しい形。
private struct ReceivedLetterDTO: Decodable {
    let code: String
    let senderName: String?
    let senderBpm: Double?
    let sentAt: String
    let claimedAt: String?
    let receipt: LetterDTO.Receipt?

    func toDomain() -> ReceivedLetter {
        ReceivedLetter(
            code: code,
            senderName: senderName,
            sentAt: ISO8601.date(from: sentAt) ?? Date(),
            claimedAt: claimedAt.flatMap(ISO8601.date(from:)),
            senderBpm: senderBpm,
            receipt: receipt.map {
                ReadReceipt(
                    heldSeconds: $0.heldSeconds,
                    releaseCount: $0.releaseCount,
                    completed: $0.completed,
                    readAt: ISO8601.date(from: $0.readAt) ?? Date()
                )
            }
        )
    }
}

private enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    static func date(from text: String) -> Date? {
        withFraction.date(from: text) ?? plain.date(from: text)
    }
}
