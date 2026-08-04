import SwiftUI

/// 手紙を読む画面。
/// 握られている間だけ文字が現れ、置くと止まる。
/// 長さを見せないので、あと何行あるか推し量ることもできない。
struct LetterReadingView: View {
    @StateObject private var session: LetterReadingSession
    @Environment(\.dismiss) private var dismiss
    /// 0: 本文のみ / 1: 後付け(日付・署名・宛名)が現れた / 2: 返す導線も出た
    @State private var endingStage = 0
    /// 読み終えて封をしたときの、自分の脈
    @State private var isSealing = false
    @State private var readerBpm: Double?

    /// 読まれ方を送り主に返す
    private let onReceipt: (ReadReceipt) -> Void

    init(letter: Letter, onReceipt: @escaping (ReadReceipt) -> Void = { _ in }) {
        _session = StateObject(wrappedValue: LetterReadingSession(letter: letter))
        self.onReceipt = onReceipt
    }

    var body: some View {
        ZStack {
            // 罫線は背景に敷かない。本文と同じ器の中で引いて行を揃える
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        Text(session.revealedText)
                            .font(BodyText.font)
                            .lineSpacing(BodyText.spacing)
                            .foregroundStyle(Paper.ink)
                            // 文字が現れる前も便箋に見えるよう、罫線の下限を確保する
                            .frame(
                                maxWidth: .infinity,
                                minHeight: BodyText.pitch * 14,
                                alignment: .topLeading
                            )
                            // 罫線は本文の後ろに、同じ行送りで敷く
                            .background(alignment: .topLeading) { BodyRules() }

                        if endingStage >= 1 {
                            closing
                        }

                        // 末尾に印を置いて、そこへ追従させる
                        Color.clear
                            .frame(height: 1)
                            .id("tail")

                        if endingStage >= 2 {
                            finishedFooter
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 34)
                    .padding(.bottom, 120)
                }
                .onChange(of: session.revealedCount) { _, _ in
                    // 現れる先に目がついていくよう、末尾を追い続ける
                    withAnimation(.linear(duration: 0.05)) {
                        proxy.scrollTo("tail", anchor: .bottom)
                    }
                }
                .onChange(of: endingStage) { _, _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        proxy.scrollTo("tail", anchor: .bottom)
                    }
                }
            }

            // 置かれたときだけ、静かに理由を出す
            if session.isPausedVisibly && !session.isFinished {
                pausedNotice
            }
        }
        .onAppear { session.start() }
        .onDisappear {
            session.stop()
            // 途中で閉じられても、そこまで費やされた時間は返す。
            // 脈を封じていればそれも一緒に返る
            if session.heldSeconds > 0 {
                onReceipt(session.receipt(readerBpm: readerBpm))
            }
        }
        // 本文が現れ切ってから、間を置いて後付け → 報告の順に落ち着かせる
        .task(id: session.isFinished) {
            guard session.isFinished else { return }
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeIn(duration: 1.1)) { endingStage = 1 }
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeIn(duration: 0.7)) { endingStage = 2 }
        }
        .sheet(isPresented: $isSealing) {
            SealSheet { bpm in
                readerBpm = bpm
                onReceipt(session.receipt(readerBpm: bpm))
            }
        }
    }

    // MARK: - 上部

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("海から")
                    .font(Mincho.font(13))
                    .kerning(4)
                    .foregroundStyle(Paper.inkSoft)

                Spacer()

                if let bpm = session.letter.senderBpm {
                    // 流した人が封をしたときの脈。生きた身体が流した証
                    Text("脈 \(Int(bpm.rounded())) で封をされた手紙")
                        .font(Mincho.font(11))
                        .foregroundStyle(Paper.inkFaint)
                }
            }

            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(height: 0.6)
        }
        .padding(.bottom, 26)
    }

    // MARK: - 置かれたときの案内

    private var pausedNotice: some View {
        VStack {
            Spacer()
            VStack(spacing: 7) {
                // まだ一文字も現れていないときは、やることを伝える。
                // 途中で止まったときは、止まった理由を伝える
                Text(
                    session.revealedCount == 0
                        ? "手に持つと、文字が現れます"
                        : "手に持っているあいだだけ、続きが現れます"
                )
                .font(Mincho.font(13.5))
                .foregroundStyle(Paper.inkSoft)

                Text(
                    session.revealedCount == 0
                        ? "机に置くと止まります"
                        : "この手紙は、要約できません"
                )
                .font(Mincho.font(11))
                .foregroundStyle(Paper.inkFaint)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 26)
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Paper.base.opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Paper.shade.opacity(0.5), lineWidth: 0.6)
                    }
            }
            .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
            .padding(.bottom, 44)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: session.isPausedVisibly)
    }

    // MARK: - 後付け(日付・署名・宛名)

    /// 日本語の手紙の作法どおり、日付と署名を右に寄せ、宛名を左に置く。
    private var closing: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .trailing, spacing: 12) {
                Text(session.letter.dateText)
                    .font(Mincho.font(14))
                    .kerning(1.5)
                    .foregroundStyle(Paper.inkSoft)

                if let sender = session.letter.senderName {
                    Text(sender)
                        .font(Mincho.font(17))
                        .kerning(2)
                        .foregroundStyle(Paper.ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 6)

            if let recipient = session.letter.recipientName {
                Text(recipient)
                    .font(Mincho.font(18))
                    .kerning(2)
                    .foregroundStyle(Paper.ink)
                    .padding(.leading, 2)
            }
        }
        .padding(.top, 42)
        .transition(.opacity)
    }

    // MARK: - 読み終えたあと

    private var finishedFooter: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(height: 0.6)

            Text("あなたはこの手紙を \(session.receipt(readerBpm: nil).heldText) 持っていました。")
                .font(Mincho.font(13.5))
                .foregroundStyle(Paper.inkSoft)

            if let readerBpm {
                // 返した後。流した人の脈と自分の脈が並ぶ
                HStack(alignment: .center, spacing: 12) {
                    pulseChip(session.letter.senderBpm, label: "流した人")
                    Text("→")
                        .font(Mincho.font(14))
                        .foregroundStyle(Paper.inkFaint)
                    pulseChip(readerBpm, label: "あなた")
                }
                .padding(.top, 4)

                Text("流した人に返るのは、この時間とこの脈だけです。")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.inkFaint)

                Button {
                    dismiss()
                } label: {
                    Text("とじる")
                        .font(Mincho.font(13.5, bold: true))
                        .foregroundStyle(Paper.ribbon)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            } else {
                Text("読み終えたときのあなたの脈を、封にして返せます。")
                    .font(Mincho.font(12))
                    .lineSpacing(5)
                    .foregroundStyle(Paper.inkFaint)

                Button {
                    isSealing = true
                } label: {
                    Text("脈で封をして返す")
                        .font(Mincho.font(15, bold: true))
                        .foregroundStyle(Paper.base)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .background { Capsule().fill(Paper.ink.opacity(0.88)) }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Button {
                    dismiss()
                } label: {
                    Text("返さずにとじる")
                        .font(Mincho.font(12.5))
                        .foregroundStyle(Paper.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 34)
    }

    private func pulseChip(_ bpm: Double?, label: String) -> some View {
        VStack(spacing: 3) {
            Text(bpm.map { "\(Int($0.rounded()))" } ?? "——")
                .font(Mincho.font(26, bold: true))
                .foregroundStyle(bpm == nil ? Paper.inkFaint : Paper.ribbon)
            Text(label)
                .font(Mincho.font(10))
                .foregroundStyle(Paper.inkFaint)
        }
    }
}
