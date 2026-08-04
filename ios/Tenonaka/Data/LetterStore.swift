import Foundation
import SwiftUI

/// 画面から見た手紙の入り口。
@MainActor
final class LetterStore: ObservableObject {
    /// 自分が送った手紙。読まれ方がここに返ってくる
    @Published private(set) var sent: [Letter] = []
    @Published private(set) var isOffline = false

    private let repository = LetterRepository()

    func refreshSent() async {
        do {
            sent = try await repository.listSent()
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    func send(
        body: String,
        senderName: String?,
        recipientName: String?,
        bpm: Double
    ) async throws -> Letter {
        let letter = try await repository.send(
            body: body,
            senderName: senderName,
            recipientName: recipientName,
            bpm: bpm
        )
        isOffline = false
        sent.insert(letter, at: 0)
        return letter
    }

    func fetch(code: String) async throws -> Letter {
        let letter = try await repository.fetch(code: code)
        isOffline = false
        return letter
    }

    /// 読まれ方を送り主に返す。失敗しても読んだ体験は壊さないので、黙って諦める。
    func submitReceipt(code: String, receipt: ReadReceipt) async {
        do {
            try await repository.submitReceipt(code: code, receipt: receipt)
            await refreshSent()
        } catch {
            isOffline = true
        }
    }

    /// 接続先を変えたあとの疎通確認。つながったかどうかを返す。
    func reload() async -> Bool {
        await refreshSent()
        return !isOffline
    }
}
