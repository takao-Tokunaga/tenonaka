import SwiftUI

/// 文箱(ふばこ)。これまでに拾った便りと、流した便りの記録。
///
/// 手紙を入れておく箱を指す言葉。「棚」は本を並べる場所なので、便りには合わない。
///
/// 入口(海)から分けてある。海は流すか拾うかを選ぶ場所で、
/// 過去を眺める場所ではない。振り返りたいときだけここを開く。
///
/// 拾った便りの**本文は手元に持たない**。開くたびにサーバーから取り直して
/// 読む画面を通すので、読み直しでも握る必要がある。
struct ShelfView: View {
    @EnvironmentObject private var store: LetterStore
    @Environment(\.dismiss) private var dismiss

    /// 文箱から開いたもの。
    ///
    /// 拾った便りと流した便りで開き方が違う(前者は握って読む、後者はそのまま出す)。
    /// 重ねる画面を種類ごとに分けると、2つの fullScreenCover が同じ画面に並んで
    /// 出し直しの事故が起きるので、1つにまとめて中で振り分ける
    private enum Opened: Identifiable {
        /// 拾った便り。握らないと読めない
        case received(Letter)
        /// 自分が流した便り。そのまま出す
        case sent(Letter)

        var id: String {
            switch self {
            case .received(let letter): return "received-\(letter.code)"
            case .sent(let letter): return "sent-\(letter.code)"
            }
        }
    }

    @State private var opened: Opened?
    @State private var openingCode: String?
    @State private var failureText: String?

    private var isEmpty: Bool {
        store.received.isEmpty && store.sent.isEmpty
    }

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let failureText {
                            Text(failureText)
                                .font(Mincho.font(12.5))
                                .lineSpacing(5)
                                .foregroundStyle(Paper.ribbon)
                                .padding(.bottom, 24)
                        }

                        if isEmpty {
                            empty
                        }

                        if !store.received.isEmpty {
                            receivedSection
                        }

                        if !store.sent.isEmpty {
                            sentSection
                                .padding(.top, store.received.isEmpty ? 0 : 38)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
        }
        // 読み直しは文箱を閉じずにこの上へ重ねる。
        // 閉じてから出すと、閉じかけの画面と重なって出し直しになる
        .fullScreenCover(item: $opened) { target in
            switch target {
            case .received(let letter):
                LetterReadingView(letter: letter) { receipt in
                    Task { await store.submitReceipt(code: letter.code, receipt: receipt) }
                }
            case .sent(let letter):
                SentLetterView(letter: letter)
            }
        }
        .task { await store.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("文箱")
                    .font(Mincho.font(22, bold: true))
                    .kerning(6)
                    .foregroundStyle(Paper.ink)

                Spacer()

                Button("とじる") { dismiss() }
                    .font(Mincho.font(13.5))
                    .foregroundStyle(Paper.inkFaint)
                    .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(width: 54, height: 0.8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 26)
        .padding(.bottom, 30)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("まだ何もありません")
                .font(Mincho.font(15))
                .foregroundStyle(Paper.inkSoft)
            Text("海に一通流すと、ここに残ります。")
                .font(Mincho.font(12))
                .foregroundStyle(Paper.inkFaint)
        }
        .padding(.top, 10)
    }

    // MARK: - 拾った便り

    private var receivedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("拾った便り")

            VStack(spacing: 0) {
                ForEach(store.received) { letter in
                    Button {
                        Task { await open(code: letter.code) }
                    } label: {
                        ReceivedLetterRow(
                            letter: letter,
                            isOpening: openingCode == letter.code
                        )
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Paper.rule.opacity(0.4))
                        .frame(height: 0.6)
                }
            }

            Text("開くたびに、もう一度手に持つ必要があります。")
                .font(Mincho.font(11))
                .foregroundStyle(Paper.inkFaint)
                .padding(.top, 4)
        }
    }

    /// 文箱から開く。本文は手元に無いので取り直す
    private func open(code: String) async {
        guard openingCode == nil else { return }
        openingCode = code
        failureText = nil
        do {
            opened = .received(try await store.fetch(code: code))
        } catch {
            failureText = error.localizedDescription
        }
        openingCode = nil
    }

    // MARK: - 流した便り

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("流した便り")

            VStack(spacing: 0) {
                ForEach(store.sent) { letter in
                    // 自分の便りは本文が控えにあるので、取りに行かずそのまま開く
                    Button {
                        opened = .sent(letter)
                    } label: {
                        SentLetterRow(letter: letter)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Paper.rule.opacity(0.4))
                        .frame(height: 0.6)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Mincho.font(12))
            .kerning(2)
            .foregroundStyle(Paper.inkSoft)
    }
}

/// 拾った便り1件。本文は持たないので、差出人の名札と読み方だけが並ぶ。
struct ReceivedLetterRow: View {
    let letter: ReceivedLetter
    let isOpening: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(letter.senderName ?? "名もなき誰か")
                    .font(Mincho.font(15))
                    .foregroundStyle(Paper.ink)

                HStack(spacing: 12) {
                    if !letter.claimedDateText.isEmpty {
                        Text("拾った \(letter.claimedDateText)")
                            .font(Mincho.font(11))
                            .foregroundStyle(Paper.inkFaint)
                    }

                    if let receipt = letter.receipt {
                        if receipt.completed {
                            Text("読み終えた")
                                .font(Mincho.font(11))
                                .foregroundStyle(Paper.inkSoft)
                        } else {
                            Text("途中まで")
                                .font(Mincho.font(11))
                                .foregroundStyle(Paper.ribbon.opacity(0.75))
                        }
                    } else {
                        Text("まだ読んでいない")
                            .font(Mincho.font(11))
                            .foregroundStyle(Paper.ribbon.opacity(0.75))
                    }
                }
            }

            Spacer()

            if isOpening {
                Text("開いている")
                    .font(Mincho.font(11))
                    .foregroundStyle(Paper.inkFaint)
            } else if let bpm = letter.senderBpm {
                // 流した人が押した封の脈
                ZStack {
                    Circle()
                        .fill(Paper.ribbon.opacity(0.13))
                        .frame(width: 34, height: 34)
                    Text("\(Int(bpm.rounded()))")
                        .font(Mincho.font(13))
                        .foregroundStyle(Paper.ribbon.opacity(0.85))
                }
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// 流した便り1件。返ってくるのは身体の事実だけ。
struct SentLetterRow: View {
    let letter: Letter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(opening)
                    .font(Mincho.font(14.5))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)

                Spacer()

                Text(letter.dateText)
                    .font(Mincho.font(11))
                    .foregroundStyle(Paper.inkFaint)
            }

            LetterReturnSummary(letter: letter)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// どの便りかを見分けるための書き出し。
    ///
    /// 宛名を持たない海なので、手がかりは本文の頭しかない。
    /// 全文を並べると文箱が読み物になってしまうので、一行だけ。
    private var opening: String {
        let firstLine = letter.body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        let trimmed = firstLine.trimmed
        let limit = 18
        return trimmed.count > limit ? String(trimmed.prefix(limit)) + "…" : trimmed
    }
}
