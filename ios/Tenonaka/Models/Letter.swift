import Foundation

/// 海に流す便り。
/// 流すときに書いた人の脈が刻まれ、拾った誰かが読み終えたときの
/// 脈と握っていた時間が返る。
struct Letter: Identifiable, Hashable, Sendable {
    /// 便りの識別子。UI には出さないが、読み直しの取得に使う
    var code: String
    var body: String
    /// 署名(差出人)
    var senderName: String?
    /// 宛名。海に流すので相手は決まっていないが「だれかへ」と書ける
    var recipientName: String?
    /// 流した瞬間の脈
    var senderBpm: Double?
    var sentAt: Date
    /// 拾われた時刻。読み終えたかとは別の状態
    var claimedAt: Date?
    /// 読まれ方の記録。まだ読まれていなければ nil
    var receipt: ReadReceipt?

    var id: String { code }

    var characters: [Character] { Array(body) }

    /// 便りの日付
    var dateText: String { JapaneseDate.text(sentAt) }
}

/// 受け取った便りの控え。
///
/// **本文を持たない。** 読み直すときもサーバーから取り直して読む画面を通す。
/// 手元に全文を置いてしまうと、握らないと読めないという機構が読み直しで崩れる。
/// これは本文の保管場所ではなく、符号の保管場所である。
struct ReceivedLetter: Identifiable, Hashable, Sendable {
    var code: String
    var senderName: String?
    var sentAt: Date
    var claimedAt: Date?
    /// 封をした瞬間の送り主の脈
    var senderBpm: Double?
    /// 自分がどう読んだか
    var receipt: ReadReceipt?

    var id: String { code }

    /// 拾った日
    var claimedDateText: String {
        guard let claimedAt else { return "" }
        return JapaneseDate.text(claimedAt)
    }
}

/// 読まれ方の記録。内容への返信ではなく、費やされた時間だけが返る。
struct ReadReceipt: Hashable, Sendable {
    /// 生きた手が握っていた合計秒数
    var heldSeconds: Double
    /// 途中で置かれた回数
    var releaseCount: Int
    /// 最後まで現れたか
    var completed: Bool
    /// 読み終えたときの読み手の脈。封をせずに閉じた場合は nil
    var readerBpm: Double?
    var readAt: Date

    var heldText: String {
        let total = Int(heldSeconds.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 { return "\(minutes)分\(seconds)秒" }
        return "\(seconds)秒"
    }
}

/// 日付の組み。「2026年8月5日」と読める形にする。
///
/// 以前は紙と明朝に合わせて漢数字で組んでいたが、日付は雰囲気より
/// 読み取りやすさが要る。数字のほうが一目で分かる。
enum JapaneseDate {
    static func text(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            return ""
        }
        return "\(year)年\(month)月\(day)日"
    }
}

// MARK: - 空文字の扱い

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 空文字は nil と同じ扱いにする
    var nilIfBlank: String? { trimmed.isEmpty ? nil : self }
}

extension Letter {
    /// 動作確認用。サーバーに繋がらないときでも読む画面を見られるようにしている。
    static let sample = Letter(
        code: "AOI",
        body: """
        元気にしていますか。

        こちらは変わりありません。母の膝は相変わらずで、朝の階段だけは手すりを使うようになりました。それでも庭のことは自分でやると言って聞きません。

        去年あなたが植えていった木が、今年は花をつけました。写真を撮ったのですが、どうにも本物のようには写らないので、送るのはやめました。

        伝えたいことがあって書きはじめたのに、こうしていると、どうでもいいことばかり並べてしまいます。本当のことを書くのが、少し怖いのだと思います。

        先週、病院で検査を受けました。結果はまだ出ていません。何でもないと思います。ただ、何でもなかったとしても、一度ちゃんと言っておきたくなりました。

        あのとき、あなたを引き止めなかったのは、行かせたかったからです。寂しくなかったわけではありません。

        返事はいりません。読んでくれただけで、じゅうぶんです。
        """,
        senderName: "母より",
        recipientName: "だれかへ",
        senderBpm: 74,
        sentAt: Date(),
        receipt: nil
    )
}
