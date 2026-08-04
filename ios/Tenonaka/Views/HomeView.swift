import SwiftUI

/// 入口。手紙を書くか、符号で受け取るか。
/// 送った手紙の「読まれ方」がここに返ってくる。
struct HomeView: View {
    @EnvironmentObject private var store: LetterStore

    @State private var isComposing = false
    @State private var isReceiving = false
    @State private var isConnectionSheetOpen = false

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                title

                actions
                    .padding(.top, 40)

                sentSection
                    .padding(.top, 44)

                Spacer()

                if store.isOffline {
                    Text("サーバーに繋がっていません")
                        .font(Mincho.font(11.5))
                        .foregroundStyle(Paper.ribbon.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 14)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 46)
        }
        .task { await store.refreshSent() }
        .fullScreenCover(isPresented: $isComposing) {
            LetterComposeView()
        }
        .fullScreenCover(isPresented: $isReceiving) {
            ReceiveLetterView()
        }
        .sheet(isPresented: $isConnectionSheetOpen) {
            ConnectionSheet()
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手紙")
                .font(Mincho.font(30, bold: true))
                .kerning(10)
                .foregroundStyle(Paper.ink)
                // 接続先を変える隠し導線。世界観を邪魔しないよう長押しに置く
                .onLongPressGesture(minimumDuration: 0.8) {
                    isConnectionSheetOpen = true
                }

            Text("読むには、手で持ち続けるしかない。")
                .font(Mincho.font(13))
                .foregroundStyle(Paper.inkSoft)

            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(width: 54, height: 0.8)
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            action("手紙を書く", detail: "書いて、脈で封をして送る") {
                isComposing = true
            }
            action("符号で受け取る", detail: "教わった符号を入れる") {
                isReceiving = true
            }
        }
    }

    private func action(
        _ label: String,
        detail: String,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(Mincho.font(17, bold: true))
                        .foregroundStyle(Paper.ink)
                    Text(detail)
                        .font(Mincho.font(11.5))
                        .foregroundStyle(Paper.inkFaint)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Paper.base.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Paper.rule.opacity(0.75), lineWidth: 0.6)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 送った手紙

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("送った手紙")
                .font(Mincho.font(12))
                .kerning(2)
                .foregroundStyle(Paper.inkSoft)

            if store.sent.isEmpty {
                Text("まだありません")
                    .font(Mincho.font(12.5))
                    .foregroundStyle(Paper.inkFaint)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.sent) { letter in
                            SentLetterRow(letter: letter)
                            Rectangle()
                                .fill(Paper.rule.opacity(0.4))
                                .frame(height: 0.6)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
    }
}

/// 送った手紙1件。返ってくるのは費やされた時間だけ。
struct SentLetterRow: View {
    let letter: Letter

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .lastTextBaseline) {
                Text(letter.code)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .kerning(2)
                    .foregroundStyle(Paper.ink)

                if let recipient = letter.recipientName {
                    Text(recipient)
                        .font(Mincho.font(12.5))
                        .foregroundStyle(Paper.inkSoft)
                }

                Spacer()

                Text(letter.dateText)
                    .font(Mincho.font(11))
                    .foregroundStyle(Paper.inkFaint)
            }

            if let receipt = letter.receipt {
                HStack(spacing: 12) {
                    Text("生きた手が \(receipt.heldText) 持っていました")
                        .font(Mincho.font(12))
                        .foregroundStyle(Paper.ink.opacity(0.8))

                    if receipt.releaseCount > 0 {
                        Text("置かれた \(receipt.releaseCount)回")
                            .font(Mincho.font(11))
                            .foregroundStyle(Paper.inkFaint)
                    }

                    if !receipt.completed {
                        Text("最後まで届いていません")
                            .font(Mincho.font(11))
                            .foregroundStyle(Paper.ribbon.opacity(0.8))
                    }
                }
            } else {
                Text("まだ読まれていません")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(.vertical, 13)
    }
}
