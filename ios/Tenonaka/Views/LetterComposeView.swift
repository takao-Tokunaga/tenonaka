import SwiftUI

/// 手紙を書く画面。書き終えたら脈で封をして海に流す。
///
/// 宛名も署名も持たない。宛先の無い海に流すので宛名は要らず、
/// 誰が書いたかを名乗らないことがこの海の匿名性そのものである。
struct LetterComposeView: View {
    @EnvironmentObject private var store: LetterStore
    @Environment(\.dismiss) private var dismiss

    // 検証時は文字を入れた状態で開く(罫線との噛み合わせを見るため)
    @State private var body_ = DebugFlags.composeTest
        ? "元気にしていますか。こちらは変わりありません。母の膝は相変わらずで、朝の階段だけは手すりを使うようになりました。それでも庭のことは自分でやると言って聞きません。"
        : ""
    @State private var isSealing = false
    @State private var isSending = false
    @State private var sentLetter: Letter?
    @State private var failureText: String?
    @FocusState private var isBodyFocused: Bool

    private var canSeal: Bool {
        !body_.trimmed.isEmpty && !isSending
    }

    var body: some View {
        ZStack {
            // 罫線は背景に敷かない。本文と同じ器の中で引いて行を揃える
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ZStack(alignment: .topLeading) {
                            // TextEditor は内側に余白を持つので、罫線もその分ずらす
                            BodyRules()
                                .padding(.top, 8)
                                .padding(.horizontal, 5)

                            if body_.isEmpty {
                                Text("見知らぬ誰かに宛てて、要約されたくないことを。")
                                    .font(BodyText.font)
                                    .foregroundStyle(Paper.inkFaint.opacity(0.7))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $body_)
                                .font(BodyText.font)
                                .lineSpacing(BodyText.spacing)
                                .foregroundStyle(Paper.ink)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .tint(Paper.ribbon)
                                .focused($isBodyFocused)
                                .frame(minHeight: 380)
                        }

                        if let failureText {
                            Text(failureText)
                                .font(Mincho.font(12.5))
                                .foregroundStyle(Paper.ribbon)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $isSealing) {
            SealSheet { bpm in
                Task { await send(bpm: bpm) }
            }
        }
        .fullScreenCover(item: $sentLetter) { letter in
            CastAnimationView(letter: letter) { dismiss() }
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
            sentLetter = letter
        } catch {
            failureText = error.localizedDescription
        }
        isSending = false
    }
}
