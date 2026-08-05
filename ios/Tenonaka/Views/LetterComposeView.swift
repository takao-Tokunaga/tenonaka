import SwiftUI

/// 便りを書く画面。書き終えたら脈で封をして海に流す。
///
/// 宛名も署名も持たない。宛先の無い海に流すので宛名は要らず、
/// 誰が書いたかを名乗らないことがこの海の匿名性そのものである。
struct LetterComposeView: View {
    @EnvironmentObject private var store: LetterStore
    @Environment(\.dismiss) private var dismiss

    // 検証時は文字を入れた状態で開く。
    // 長文で崩れないかを見たいので、画面に収まらない量を入れてある
    @State private var body_ = DebugFlags.composeTest
        ? String(
            repeating: """
            元気にしていますか。こちらは変わりありません。母の膝は相変わらずで、朝の階段だけは\
            手すりを使うようになりました。それでも庭のことは自分でやると言って聞きません。
            """,
            count: 4
        )
        : ""
    @State private var isSealing = false
    /// 押された封。封をする画面が閉じ終わってから使う
    @State private var sealedBpm: Double?
    @State private var isSending = false
    @State private var sentLetter: Letter?
    @State private var failureText: String?
    @State private var isBodyFocused = false
    /// 鍵盤を開くのは開いた最初の一度だけ。
    /// onAppear は封の画面が閉じたときにも走るので、そのたびに開き直すと
    /// 演出に移る瞬間に鍵盤の開閉が重なる
    @State private var didFocusOnce = false

    private var canSeal: Bool {
        !body_.trimmed.isEmpty && !isSending
    }

    var body: some View {
        ZStack {
            // 罫線は背景に敷かない。本文と同じ器の中で引いて行を揃える
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            if let sentLetter {
                // 流したら、この画面の中でそのまま演出に移る。
                // 別の画面として出すと、閉じかけの画面と重なって出し直しになり、
                // 演出が二度流れてしまう
                CastAnimationView(letter: sentLetter) { dismiss() }
            } else {
                writingSheet
            }
        }
        // 封をする画面が閉じ終わってから送る。
        // 閉じている途中で送ると、閉じるアニメーションと演出の始まりが重なる
        .sheet(isPresented: $isSealing, onDismiss: {
            guard let bpm = sealedBpm else { return }
            sealedBpm = nil
            Task { await send(bpm: bpm) }
        }) {
            SealSheet { bpm in sealedBpm = bpm }
        }
        // 書くために開いた画面なので、開いた時点で書き始められるようにする
        .onAppear {
            guard !didFocusOnce else { return }
            didFocusOnce = true
            if DebugFlags.autoCast {
                isSealing = true
            } else {
                isBodyFocused = true
            }
        }
    }

    /// 書く欄。
    ///
    /// 罫線は敷かない。字と噛み合わせるには欄のスクロールを外側に預ける必要があり、
    /// それが長文で崩れる元だった。紙の質感と明朝で便箋には見えるので、
    /// 線を捨てて書くことの安定を取った。
    private var writingSheet: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .topLeading) {
                if body_.isEmpty {
                    Text("見知らぬ誰かに宛てて")
                        .font(BodyText.font)
                        .foregroundStyle(Paper.inkFaint.opacity(0.7))
                        .allowsHitTesting(false)
                }

                BodyTextEditor(text: $body_, isFocused: $isBodyFocused)
            }
            .padding(.horizontal, 30)
            .frame(maxHeight: .infinity, alignment: .top)

            if let failureText {
                Text(failureText)
                    .font(Mincho.font(12.5))
                    .foregroundStyle(Paper.ribbon)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 12)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Button("やめる") { dismiss() }
                .font(Mincho.font(13.5))
                .foregroundStyle(Paper.inkFaint)

            Spacer()

            Text("海に流す")
                .font(Mincho.font(15, bold: true))
                .kerning(3)
                .foregroundStyle(Paper.ink)

            Spacer()

            Button {
                isBodyFocused = false
                isSealing = true
            } label: {
                Text(isSending ? "流している" : "封をする")
                    .font(Mincho.font(13.5, bold: true))
                    .foregroundStyle(canSeal ? Paper.ribbon : Paper.inkFaint)
            }
            .disabled(!canSeal)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private func send(bpm: Double) async {
        isSending = true
        failureText = nil
        do {
            let letter = try await store.cast(body: body_, bpm: bpm)
            // 鍵盤を先に下げる。演出に移るのと閉じるのが重なると絵が跳ねる
            isBodyFocused = false
            sentLetter = letter
        } catch {
            failureText = error.localizedDescription
        }
        isSending = false
    }
}
