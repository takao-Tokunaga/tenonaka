import SwiftUI

/// 自分が流した便りを読み返す画面。
///
/// **握らなくてもそのまま出す。** 拾った便りは一文字ずつ現す機構を通すが、
/// 自分の文章に同じ関門を課す意味がない。書いた本人はもう中身を知っている。
///
/// 本文は控えに含まれているのでサーバーへ取りに行かない。
/// (拾った便りだけが本文を持たず、開くたびに取り直す)
struct SentLetterView: View {
    let letter: Letter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(letter.body)
                            .font(BodyText.font)
                            .lineSpacing(BodyText.textSpacing)
                            .foregroundStyle(Paper.ink)
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        Text(letter.dateText)
                            .font(Mincho.font(13))
                            .kerning(1.5)
                            .foregroundStyle(Paper.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 34)

                        returned
                            .padding(.top, 38)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("海に流した便り")
                    .font(Mincho.font(13))
                    .kerning(3)
                    .foregroundStyle(Paper.inkSoft)

                Spacer()

                Button("とじる") { dismiss() }
                    .font(Mincho.font(13.5))
                    .foregroundStyle(Paper.inkFaint)
                    .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(height: 0.6)
        }
        .padding(.horizontal, 32)
        .padding(.top, 26)
        .padding(.bottom, 26)
    }

    /// 返ってきたもの。内容への返信ではなく身体の事実だけ
    private var returned: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("返ってきたもの")
                .font(Mincho.font(11.5))
                .kerning(2)
                .foregroundStyle(Paper.inkFaint)

            LetterReturnSummary(letter: letter, isCompact: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 流した便りに返ってきたものの表示。文箱の一覧と読み返しの画面で共有する。
///
/// 同じことを二箇所に書くと、片方だけ直して食い違う。
struct LetterReturnSummary: View {
    let letter: Letter
    /// 一覧に並べるときは小さく組む
    var isCompact = true

    var body: some View {
        if let receipt = letter.receipt {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 14) {
                // ここがこのアプリの答え。流した身体から、読んだ身体へ
                HStack(alignment: .center, spacing: isCompact ? 10 : 16) {
                    pulseChip(letter.senderBpm, label: "流した")
                    Text("→")
                        .font(Mincho.font(isCompact ? 13 : 17))
                        .foregroundStyle(Paper.inkFaint)
                    pulseChip(receipt.readerBpm, label: "読んだ")
                }

                Text("見知らぬ誰かが \(receipt.heldText) 持っていました")
                    .font(Mincho.font(isCompact ? 12 : 14))
                    .foregroundStyle(Paper.ink.opacity(0.8))

                if receipt.releaseCount > 0 || !receipt.completed {
                    HStack(spacing: 12) {
                        if receipt.releaseCount > 0 {
                            Text("置かれた \(receipt.releaseCount)回")
                                .font(Mincho.font(isCompact ? 11 : 12.5))
                                .foregroundStyle(Paper.inkFaint)
                        }
                        if !receipt.completed {
                            Text("最後まで届いていません")
                                .font(Mincho.font(isCompact ? 11 : 12.5))
                                .foregroundStyle(Paper.ribbon.opacity(0.8))
                        }
                    }
                }
            }
        } else if letter.claimedAt != nil {
            Text("誰かが拾いました")
                .font(Mincho.font(isCompact ? 12 : 14))
                .foregroundStyle(Paper.inkSoft)
        } else {
            Text("まだ海を漂っています")
                .font(Mincho.font(isCompact ? 12 : 14))
                .foregroundStyle(Paper.inkFaint)
        }
    }

    private func pulseChip(_ bpm: Double?, label: String) -> some View {
        VStack(spacing: 2) {
            Text(bpm.map { "\(Int($0.rounded()))" } ?? "——")
                .font(Mincho.font(isCompact ? 19 : 26, bold: true))
                .foregroundStyle(bpm == nil ? Paper.inkFaint : Paper.ribbon)
            Text(label)
                .font(Mincho.font(isCompact ? 9.5 : 11))
                .foregroundStyle(Paper.inkFaint)
        }
    }
}
