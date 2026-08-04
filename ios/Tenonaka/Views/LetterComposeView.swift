import SwiftUI

/// 手紙を書く画面。書き終えたら脈で封をして送る。
struct LetterComposeView: View {
    @EnvironmentObject private var store: LetterStore
    @Environment(\.dismiss) private var dismiss

    @State private var recipientName = ""
    @State private var senderName = ""
    @State private var body_ = ""
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
            PaperSurface(lineSpacing: 36)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        field("宛名", placeholder: "だれかへ", text: $recipientName)

                        ZStack(alignment: .topLeading) {
                            if body_.isEmpty {
                                Text("見知らぬ誰かに宛てて、要約されたくないことを。")
                                    .font(Mincho.font(17))
                                    .foregroundStyle(Paper.inkFaint.opacity(0.7))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $body_)
                                .font(Mincho.font(17))
                                .lineSpacing(17)
                                .foregroundStyle(Paper.ink)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .tint(Paper.ribbon)
                                .focused($isBodyFocused)
                                .frame(minHeight: 260)
                        }

                        field("署名", placeholder: "誰から", text: $senderName)

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
        .sheet(item: $sentLetter) { letter in
            SentCodeView(letter: letter) { dismiss() }
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

    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Mincho.font(11.5))
                .kerning(1.5)
                .foregroundStyle(Paper.inkFaint)
            TextField(placeholder, text: text)
                .font(Mincho.font(16))
                .foregroundStyle(Paper.ink)
                .tint(Paper.ribbon)
                .padding(.bottom, 7)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Paper.rule.opacity(0.7))
                        .frame(height: 0.6)
                }
        }
    }

    private func send(bpm: Double) async {
        isSending = true
        failureText = nil
        do {
            let letter = try await store.cast(
                body: body_,
                senderName: senderName.nilIfBlank,
                recipientName: recipientName.nilIfBlank,
                bpm: bpm
            )
            sentLetter = letter
        } catch {
            failureText = error.localizedDescription
        }
        isSending = false
    }
}

/// 流したあとの画面。符号は見せない。宛先も相手も無いので、
/// 伝えることは「海に出た」ことだけ。
struct SentCodeView: View {
    let letter: Letter
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("海に流しました")
                    .font(Mincho.font(19))
                    .foregroundStyle(Paper.ink)

                if let bpm = letter.senderBpm {
                    ZStack {
                        Circle()
                            .fill(Paper.ribbon.opacity(0.92))
                            .frame(width: 84, height: 84)
                        VStack(spacing: 0) {
                            Text("\(Int(bpm.rounded()))")
                                .font(Mincho.font(31, bold: true))
                            Text("拍")
                                .font(Mincho.font(11))
                        }
                        .foregroundStyle(Paper.base)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 7, y: 3)
                }

                VStack(spacing: 7) {
                    Text("いつか、見知らぬ誰かが拾います")
                        .font(Mincho.font(13))
                        .foregroundStyle(Paper.inkSoft)
                    Text("返ってくるのは、その人が持っていた時間と脈だけです")
                        .font(Mincho.font(11.5))
                        .foregroundStyle(Paper.inkFaint)
                }
                .multilineTextAlignment(.center)

                Text("あなたも一通、拾えるようになりました")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.ribbon.opacity(0.85))
                    .padding(.top, 6)

                Spacer()

                Button {
                    dismiss()
                    onClose()
                } label: {
                    Text("とじる")
                        .font(Mincho.font(14))
                        .foregroundStyle(Paper.inkSoft)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 32)
        }
    }
}
