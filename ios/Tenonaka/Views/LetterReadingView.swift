import SwiftUI

/// 手紙を読む画面。
/// 握られている間だけ文字が現れ、置くと止まる。
/// 長さを見せないので、あと何行あるか推し量ることもできない。
struct LetterReadingView: View {
    @StateObject private var session: LetterReadingSession
    @Environment(\.dismiss) private var dismiss
    @State private var showsReceipt = false
    /// 0: 本文のみ / 1: 後付け(日付・署名・宛名)が現れた / 2: 報告も出た
    @State private var endingStage = 0

    /// 読まれ方を送り主に返す
    private let onReceipt: (ReadReceipt) -> Void

    init(letter: Letter, onReceipt: @escaping (ReadReceipt) -> Void = { _ in }) {
        _session = StateObject(wrappedValue: LetterReadingSession(letter: letter))
        self.onReceipt = onReceipt
    }

    var body: some View {
        ZStack {
            PaperSurface(lineSpacing: 36)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        Text(session.revealedText)
                            .font(Mincho.font(17))
                            .lineSpacing(17)
                            .foregroundStyle(Paper.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // 現れた最後の一文字にだけ、まだ乾いていない滲みを置く
                            .overlay(alignment: .bottomTrailing) { EmptyView() }

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
            // 途中で閉じられても、そこまで費やされた時間は返す
            if session.heldSeconds > 0 { onReceipt(session.receipt) }
        }
        // 本文が現れ切ってから、間を置いて後付け → 報告の順に落ち着かせる
        .task(id: session.isFinished) {
            guard session.isFinished else { return }
            onReceipt(session.receipt)
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.easeIn(duration: 1.1)) { endingStage = 1 }
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeIn(duration: 0.7)) { endingStage = 2 }
        }
        .sheet(isPresented: $showsReceipt) {
            ReadReceiptView(receipt: session.receipt)
        }
    }

    // MARK: - 上部

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("手紙")
                    .font(Mincho.font(13))
                    .kerning(4)
                    .foregroundStyle(Paper.inkSoft)

                Spacer()

                if let bpm = session.letter.senderBpm {
                    // 送り主が封をしたときの脈。生きた身体が送った証
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
                Text("手に持っているあいだだけ、続きが現れます")
                    .font(Mincho.font(13))
                    .foregroundStyle(Paper.inkSoft)
                Text("この手紙は、要約できません")
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

            Text("あなたはこの手紙を \(session.receipt.heldText) 持っていました。")
                .font(Mincho.font(13.5))
                .foregroundStyle(Paper.inkSoft)

            Text("それが送り主に伝わります。")
                .font(Mincho.font(12))
                .foregroundStyle(Paper.inkFaint)

            HStack(spacing: 22) {
                Button {
                    showsReceipt = true
                } label: {
                    Text("返るものを見る")
                        .font(Mincho.font(13.5, bold: true))
                        .foregroundStyle(Paper.ribbon)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("とじる")
                        .font(Mincho.font(13.5))
                        .foregroundStyle(Paper.inkSoft)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 34)
    }
}

/// 送り主に返る内容。返信ではなく、費やされた時間だけ。
struct ReadReceiptView: View {
    let receipt: ReadReceipt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Text("送り主に返るもの")
                        .font(Mincho.font(15, bold: true))
                        .kerning(2)
                        .foregroundStyle(Paper.ink)
                    Spacer()
                    Button("とじる") { dismiss() }
                        .font(Mincho.font(13))
                        .foregroundStyle(Paper.inkFaint)
                        .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    row("生きた手が持っていた時間", receipt.heldText)
                    row("途中で置かれた回数", "\(receipt.releaseCount)回")
                    row("最後まで読まれたか", receipt.completed ? "はい" : "いいえ")
                }

                Text("内容への返信は含まれません。費やされた時間だけが返ります。")
                    .font(Mincho.font(11.5))
                    .lineSpacing(5)
                    .foregroundStyle(Paper.inkFaint)

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label)
                .font(Mincho.font(12.5))
                .foregroundStyle(Paper.inkSoft)
            Spacer()
            Text(value)
                .font(Mincho.font(17, bold: true))
                .foregroundStyle(Paper.ink)
        }
    }
}
