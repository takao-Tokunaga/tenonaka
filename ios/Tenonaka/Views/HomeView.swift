import SwiftUI
import UIKit

/// 入口。手紙を書くか、符号で受け取るか。
///
/// 受け取った手紙は棚に残るが、**本文は手元に持たない**。
/// 開くたびにサーバーから取り直して読む画面を通すので、読み直しでも握る必要がある。
struct HomeView: View {
    @EnvironmentObject private var store: LetterStore

    @State private var isComposing = false
    @State private var isReceiving = false
    @State private var isConnectionSheetOpen = false

    /// 棚から開いた手紙。取り直してから読む画面に入る
    @State private var openedLetter: Letter?
    @State private var openingCode: String?
    @State private var failureText: String?
    @State private var didCopyAddress = false

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    title

                    actions
                        .padding(.top, 36)

                    if let failureText {
                        Text(failureText)
                            .font(Mincho.font(12.5))
                            .foregroundStyle(Paper.ribbon)
                            .padding(.top, 18)
                    }

                    receivedSection
                        .padding(.top, 40)

                    sentSection
                        .padding(.top, 38)

                    if store.isOffline {
                        Text("サーバーに繋がっていません")
                            .font(Mincho.font(11.5))
                            .foregroundStyle(Paper.ribbon.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 30)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 46)
                .padding(.bottom, 50)
            }
        }
        .task { await store.refresh() }
        .fullScreenCover(isPresented: $isComposing) {
            LetterComposeView()
        }
        .fullScreenCover(isPresented: $isReceiving) {
            ReceiveLetterView()
        }
        .fullScreenCover(item: $openedLetter) { letter in
            LetterReadingView(letter: letter) { receipt in
                Task { await store.submitReceipt(code: letter.code, receipt: receipt) }
            }
        }
        .sheet(isPresented: $isConnectionSheetOpen) {
            ConnectionSheet()
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手のなか")
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

            myAddressPlate
                .padding(.top, 10)
        }
    }

    /// 自分の住所。これを相手に教えると手紙が届く
    private var myAddressPlate: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("あなたの住所")
                    .font(Mincho.font(10.5))
                    .kerning(1.5)
                    .foregroundStyle(Paper.inkFaint)

                if let address = store.myAddress {
                    Text(address)
                        .font(Mincho.font(17))
                        .kerning(1)
                        .foregroundStyle(Paper.ink)
                        .textSelection(.enabled)
                } else {
                    Text("——")
                        .font(Mincho.font(17))
                        .foregroundStyle(Paper.inkFaint.opacity(0.6))
                }
            }

            Spacer()

            // かなを打つのは手間なので、写して渡せるようにする
            if let address = store.myAddress {
                Button {
                    UIPasteboard.general.string = address
                    withAnimation(.easeOut(duration: 0.2)) { didCopyAddress = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeIn(duration: 0.4)) { didCopyAddress = false }
                    }
                } label: {
                    Text(didCopyAddress ? "写した" : "写す")
                        .font(Mincho.font(12))
                        .foregroundStyle(didCopyAddress ? Paper.inkSoft : Paper.ribbon)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(Paper.base.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Paper.rule.opacity(0.6), lineWidth: 0.6)
                }
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

    // MARK: - 受け取った手紙

    private var receivedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("受け取った手紙")

            if store.received.isEmpty {
                Text("まだありません")
                    .font(Mincho.font(12.5))
                    .foregroundStyle(Paper.inkFaint)
            } else {
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
    }

    /// 棚から開く。本文は手元に無いので取り直す
    private func open(code: String) async {
        guard openingCode == nil else { return }
        openingCode = code
        failureText = nil
        do {
            openedLetter = try await store.fetch(code: code)
        } catch {
            failureText = error.localizedDescription
        }
        openingCode = nil
    }

    // MARK: - 送った手紙

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("送った手紙")

            if store.sent.isEmpty {
                Text("まだありません")
                    .font(Mincho.font(12.5))
                    .foregroundStyle(Paper.inkFaint)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.sent) { letter in
                        SentLetterRow(letter: letter)
                        Rectangle()
                            .fill(Paper.rule.opacity(0.4))
                            .frame(height: 0.6)
                    }
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

/// 受け取った手紙1件。本文は持たないので、符号と差出人だけが並ぶ。
struct ReceivedLetterRow: View {
    let letter: ReceivedLetter
    let isOpening: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(letter.senderName ?? "差出人不明")
                        .font(Mincho.font(15))
                        .foregroundStyle(Paper.ink)

                    Text(letter.code)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Paper.inkFaint)
                }

                HStack(spacing: 12) {
                    if !letter.claimedDateText.isEmpty {
                        Text("受け取り \(letter.claimedDateText)")
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
            } else {
                // 封の跡。送り主が押した脈
                if let bpm = letter.senderBpm {
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
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// 送った手紙1件。返ってくるのは費やされた時間だけ。
struct SentLetterRow: View {
    let letter: Letter

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .lastTextBaseline) {
                Text(letter.code)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .kerning(1.5)
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
            } else if letter.claimedAt != nil {
                Text("受け取られました")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.inkSoft)
            } else {
                Text("まだ受け取られていません")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(.vertical, 13)
    }
}
