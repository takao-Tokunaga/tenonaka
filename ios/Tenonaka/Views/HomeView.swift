import SwiftUI

/// 入口。海に流すか、海から拾うか。
///
/// 拾った手紙は棚に残るが、**本文は手元に持たない**。
/// 開くたびにサーバーから取り直して読む画面を通すので、読み直しでも握る必要がある。
struct HomeView: View {
    @EnvironmentObject private var store: LetterStore

    @State private var isComposing = false
    @State private var isConnectionSheetOpen = false

    /// 拾った、または棚から開いた手紙。取り直してから読む画面に入る
    @State private var openedLetter: Letter?
    @State private var openingCode: String?
    @State private var isPickingUp = false
    @State private var failureText: String?

    var body: some View {
        GeometryReader { geometry in
            // 水面を画面のこのあたりに置く。下半分を海にすると、
            // 砂浜から沖を見ている構図になって余白が空白ではなくなる
            let seaHeight = geometry.size.height * 0.62

            ZStack {
                PaperSurface(showsRules: false)
                    .ignoresSafeArea()

                // 海は画面の下に固定する。内容と一緒にスクロールすると
                // 水面が上下して落ち着かない
                VStack {
                    Spacer()
                    SeaView(drifting: store.sea.drifting, height: seaHeight)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        title

                        actions
                            .padding(.top, 34)

                        if let failureText {
                            Text(failureText)
                                .font(Mincho.font(12.5))
                                .lineSpacing(5)
                                .foregroundStyle(Paper.ribbon)
                                .padding(.top, 18)
                        }

                        if !store.received.isEmpty {
                            receivedSection
                                .padding(.top, 40)
                        }

                        if !store.sent.isEmpty {
                            sentSection
                                .padding(.top, 38)
                        }

                        if store.isOffline {
                            Text("海に繋がっていません")
                                .font(Mincho.font(11.5))
                                .foregroundStyle(Paper.ribbon.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 30)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 46)
                    // 海に文字が沈まないよう、水面より上で終わらせる
                    .padding(.bottom, seaHeight * 0.5 + 30)
                }
            }
        }
        .task { await store.refresh() }
        .fullScreenCover(isPresented: $isComposing) {
            LetterComposeView()
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

            Text("見知らぬ誰かの手紙は、\n手で持ち続けているあいだだけ現れる。")
                .font(Mincho.font(13))
                .lineSpacing(6)
                .foregroundStyle(Paper.inkSoft)

            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(width: 54, height: 0.8)
        }
    }

    // MARK: - 流す・拾う

    private var actions: some View {
        VStack(spacing: 14) {
            action(
                "海に流す",
                detail: "書いて、脈で封をして流す",
                enabled: true
            ) {
                isComposing = true
            }

            action(
                isPickingUp ? "拾っている" : "海から拾う",
                detail: pickUpDetail,
                enabled: store.sea.canPickUp > 0 && store.sea.drifting > 0 && !isPickingUp
            ) {
                Task { await pickUp() }
            }
        }
    }

    /// 拾える条件を、断られる前に伝える。
    /// 海の様子は拾えない時でも見せる。そこに手紙があると分かるほうが流したくなる
    private var pickUpDetail: String {
        if store.sea.drifting <= 0 {
            return "いま海に手紙はない"
        }
        if store.sea.canPickUp <= 0 {
            return "海に \(store.sea.drifting)通。拾うには、まず一通流す"
        }
        return "海に \(store.sea.drifting)通 漂っている"
    }

    private func action(
        _ label: String,
        detail: String,
        enabled: Bool,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(Mincho.font(17, bold: true))
                        .foregroundStyle(enabled ? Paper.ink : Paper.inkFaint)
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
                    .fill(Paper.base.opacity(enabled ? 0.6 : 0.3))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(
                                Paper.rule.opacity(enabled ? 0.75 : 0.4),
                                lineWidth: 0.6
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func pickUp() async {
        guard !isPickingUp else { return }
        isPickingUp = true
        failureText = nil
        do {
            openedLetter = try await store.pickUp()
        } catch {
            failureText = error.localizedDescription
        }
        isPickingUp = false
    }

    // MARK: - 拾った手紙

    private var receivedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("拾った手紙")

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

    // MARK: - 流した手紙

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("流した手紙")

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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Mincho.font(12))
            .kerning(2)
            .foregroundStyle(Paper.inkSoft)
    }
}

/// 拾った手紙1件。本文は持たないので、差出人の名札と読み方だけが並ぶ。
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

/// 流した手紙1件。返ってくるのは身体の事実だけ。
struct SentLetterRow: View {
    let letter: Letter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(letter.recipientName ?? "だれかへ")
                    .font(Mincho.font(14.5))
                    .foregroundStyle(Paper.ink)

                Spacer()

                Text(letter.dateText)
                    .font(Mincho.font(11))
                    .foregroundStyle(Paper.inkFaint)
            }

            if let receipt = letter.receipt {
                // ここがこのアプリの答え。流した身体から、読んだ身体へ
                HStack(alignment: .center, spacing: 10) {
                    pulseChip(letter.senderBpm, label: "流した")
                    Text("→")
                        .font(Mincho.font(13))
                        .foregroundStyle(Paper.inkFaint)
                    pulseChip(receipt.readerBpm, label: "読んだ")
                }

                Text("見知らぬ誰かが \(receipt.heldText) 持っていました")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.ink.opacity(0.8))

                if receipt.releaseCount > 0 || !receipt.completed {
                    HStack(spacing: 12) {
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
                }
            } else if letter.claimedAt != nil {
                Text("誰かが拾いました")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.inkSoft)
            } else {
                Text("まだ海を漂っています")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.inkFaint)
            }
        }
        .padding(.vertical, 14)
    }

    private func pulseChip(_ bpm: Double?, label: String) -> some View {
        VStack(spacing: 2) {
            Text(bpm.map { "\(Int($0.rounded()))" } ?? "——")
                .font(Mincho.font(19, bold: true))
                .foregroundStyle(bpm == nil ? Paper.inkFaint : Paper.ribbon)
            Text(label)
                .font(Mincho.font(9.5))
                .foregroundStyle(Paper.inkFaint)
        }
    }
}
