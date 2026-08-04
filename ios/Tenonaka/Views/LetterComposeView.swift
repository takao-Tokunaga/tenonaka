import SwiftUI

/// 手紙を書く画面。書き終えたら脈で封をして送る。
struct LetterComposeView: View {
    @EnvironmentObject private var store: LetterStore
    @Environment(\.dismiss) private var dismiss

    @State private var recipientAddress = ""
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
                        addressField
                        field("宛名", placeholder: "誰へ", text: $recipientName)

                        ZStack(alignment: .topLeading) {
                            if body_.isEmpty {
                                Text("要約されたくないことを、書く。")
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

            Text("手紙を書く")
                .font(Mincho.font(15, bold: true))
                .kerning(3)
                .foregroundStyle(Paper.ink)

            Spacer()

            Button {
                isBodyFocused = false
                isSealing = true
            } label: {
                Text(isSending ? "送っている" : "封をする")
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

    /// 宛先の住所。空なら符号を口で伝えて渡す
    private var addressField: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .lastTextBaseline) {
                Text("宛先")
                    .font(Mincho.font(11.5))
                    .kerning(1.5)
                    .foregroundStyle(Paper.inkFaint)
                Spacer()
                Text(recipientAddress.trimmed.isEmpty ? "空なら符号で渡す" : "相手の棚に直接届く")
                    .font(Mincho.font(10.5))
                    .foregroundStyle(Paper.inkFaint.opacity(0.8))
            }

            TextField("komorebi-nagisa-shigure", text: $recipientAddress)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Paper.ink)
                .tint(Paper.ribbon)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: recipientAddress) { _, value in
                    // 住所は小文字とハイフンだけ
                    recipientAddress = value.lowercased()
                        .filter { $0.isLetter || $0 == "-" }
                }
                .padding(.bottom, 7)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Paper.rule.opacity(0.7))
                        .frame(height: 0.6)
                }
        }
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
            let letter = try await store.send(
                body: body_,
                senderName: senderName.nilIfBlank,
                recipientName: recipientName.nilIfBlank,
                recipientAddress: recipientAddress.nilIfBlank,
                bpm: bpm
            )
            sentLetter = letter
        } catch {
            failureText = error.localizedDescription
        }
        isSending = false
    }
}

/// 送ったあとに出る符号。これを相手に口で伝える。
struct SentCodeView: View {
    let letter: Letter
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                Text("封をして送りました")
                    .font(Mincho.font(15))
                    .foregroundStyle(Paper.inkSoft)

                // 宛先を指定した手紙は既に届いているので、符号は主役ではない
                if let address = letter.recipientAddress {
                    Text(address)
                        .font(.system(size: 21, design: .monospaced))
                        .foregroundStyle(Paper.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("この住所に届きました")
                        .font(Mincho.font(12.5))
                        .foregroundStyle(Paper.inkFaint)
                } else {
                    Text(letter.code)
                        .font(.system(
                            size: letter.code.count > 8 ? 34 : 50,
                            weight: .semibold,
                            design: .serif
                        ))
                        .kerning(letter.code.count > 8 ? 3 : 8)
                        .foregroundStyle(Paper.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 24)

                    Text("この符号を相手に声で伝えてください")
                        .font(Mincho.font(12.5))
                        .foregroundStyle(Paper.inkFaint)
                }

                if let bpm = letter.senderBpm {
                    Text("脈 \(Int(bpm.rounded())) で封をされました")
                        .font(Mincho.font(11.5))
                        .foregroundStyle(Paper.inkFaint)
                }

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
        }
    }
}
