import Foundation
import SwiftUI

/// 海の様子。
struct SeaState: Hashable, Sendable {
    /// いま漂っていて拾える手紙の数(自分が流したものは含まない)
    var drifting: Int
    /// あと何通拾えるか。流した数から拾った数を引いたもの
    var canPickUp: Int

    static let unknown = SeaState(drifting: 0, canPickUp: 0)
}

/// 画面から見た手紙の入り口。
@MainActor
final class LetterStore: ObservableObject {
    /// 自分が流した手紙。返ってきた身体の記録がここに載る
    @Published private(set) var sent: [Letter] = []
    /// 自分が拾った手紙の控え。本文は持たない
    @Published private(set) var received: [ReceivedLetter] = []
    @Published private(set) var sea: SeaState = .unknown
    @Published private(set) var isOffline = false

    private let repository = LetterRepository()

    func refresh() async {
        await refreshSea()
        await refreshReceived()
        await refreshSent()
    }

    func refreshSea() async {
        do {
            sea = try await repository.sea()
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    func refreshSent() async {
        do {
            sent = try await repository.listSent()
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    func refreshReceived() async {
        do {
            received = try await repository.listReceived()
            isOffline = false
        } catch {
            isOffline = true
        }
    }

    /// 海に流す。脈が無いと流せない
    func cast(body: String, bpm: Double) async throws -> Letter {
        let letter = try await repository.cast(body: body, bpm: bpm)
        isOffline = false
        sent.insert(letter, at: 0)
        await refreshSea()
        return letter
    }

    /// 海から一通拾う
    func pickUp() async throws -> Letter {
        let letter = try await repository.pickUp()
        isOffline = false
        await refreshReceived()
        await refreshSea()
        return letter
    }

    /// 拾った手紙を読み直す。本文を手元に置かず、毎回取り直させる
    func fetch(code: String) async throws -> Letter {
        let letter = try await repository.fetch(code: code)
        isOffline = false
        return letter
    }

    /// 読まれ方を流した人に返す。失敗しても読んだ体験は壊さないので黙って諦める
    func submitReceipt(code: String, receipt: ReadReceipt) async {
        do {
            try await repository.submitReceipt(code: code, receipt: receipt)
            await refreshReceived()
            await refreshSent()
        } catch {
            isOffline = true
        }
    }

    /// 接続先を変えたあとの疎通確認。つながったかどうかを返す
    func reload() async -> Bool {
        await refresh()
        return !isOffline
    }
}
