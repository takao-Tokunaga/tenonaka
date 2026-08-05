import SwiftUI

/// 入口。海がそのまま操作面になっている。
///
/// 流すのは海の中に置いた一つのボタンから。拾うのは「拾う」ボタンではなく、
/// 浮かんでいる瓶に手を伸ばすこと。ボタンを並べるより、
/// 海に手を入れているように扱えるほうがこのアプリの動きに合う。
///
/// 過去に拾った・流した便りは文箱(``ShelfView``)に分けてある。
struct HomeView: View {
    @EnvironmentObject private var store: LetterStore

    @State private var isComposing = false
    @State private var isShelfOpen = false
    @State private var isConnectionSheetOpen = false

    /// 拾った便り。取り直してから読む画面に入る
    @State private var openedLetter: Letter?
    @State private var isPickingUp = false
    @State private var noticeText: String?

    private var canPickUp: Bool {
        store.sea.canPickUp > 0 && store.sea.drifting > 0
    }

    var body: some View {
        GeometryReader { geometry in
            // 海は下端まで満たしたいので、下の余白のぶんだけ丈を伸ばす。
            // 上は水面より上=紙なので、伸ばす必要がない
            let seaHeight = geometry.size.height + geometry.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                PaperSurface(showsRules: false)
                    .ignoresSafeArea()

                SeaView(
                    drifting: store.sea.drifting,
                    height: seaHeight,
                    waterLine: 0.32,
                    onOpenBottle: { Task { await openBottle() } }
                )
                .ignoresSafeArea(edges: .bottom)

                VStack(alignment: .leading, spacing: 0) {
                    titleRow

                    Spacer(minLength: 0)

                    footer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .task { await store.refresh() }
        .fullScreenCover(isPresented: $isComposing) {
            LetterComposeView()
        }
        .fullScreenCover(isPresented: $isShelfOpen) {
            ShelfView()
        }
        // 拾ったときは、瓶が流れてきて栓が抜けるところから見せる。
        // 文箱から読み直すときは演出を挟まない(もう拾ってある便りなので)
        .fullScreenCover(item: $openedLetter) { letter in
            PickUpFlowView(letter: letter) { receipt in
                Task { await store.submitReceipt(code: letter.code, receipt: receipt) }
            }
        }
        .sheet(isPresented: $isConnectionSheetOpen) {
            ConnectionSheet()
        }
    }

    // MARK: - 見出し

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("波びん")
                    .font(Mincho.font(30, bold: true))
                    .kerning(10)
                    .foregroundStyle(Paper.ink)
                    // 接続先を変える隠し導線。世界観を邪魔しないよう長押しに置く
                    .onLongPressGesture(minimumDuration: 0.8) {
                        isConnectionSheetOpen = true
                    }

                Spacer()

                shelfLink
            }

            Text("浮かんでいる瓶をひらくと、\n見知らぬ誰かの便りが現れる。")
                .font(Mincho.font(13))
                .lineSpacing(6)
                .foregroundStyle(Paper.inkSoft)

            Rectangle()
                .fill(Paper.rule.opacity(0.6))
                .frame(width: 54, height: 0.8)
        }
    }

    /// 過去は主役ではないので、隅に小さく置く。
    ///
    /// 丸で囲って押せることを示す。塗りではなく細い輪郭にしてあるのは、
    /// 朱で塗った丸が**脈の封印**に使われているため。同じ形にすると意味が混ざる。
    ///
    /// 何も無いうちは出さない(空の文箱を開かせても得るものがない)
    private var shelfLink: some View {
        Group {
            if !store.received.isEmpty || !store.sent.isEmpty {
                Button {
                    isShelfOpen = true
                } label: {
                    Text("文箱")
                        .font(Mincho.font(12.5))
                        .foregroundStyle(Paper.inkSoft)
                        .frame(width: 48, height: 48)
                        .background {
                            Circle()
                                .fill(Paper.base.opacity(0.5))
                                .overlay {
                                    Circle()
                                        .stroke(Paper.ink.opacity(0.35), lineWidth: 0.8)
                                }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 海の中の足元

    private var footer: some View {
        VStack(spacing: 14) {
            // 文が出ない状態でもボタンが上下しないよう、場所だけ確保する
            Text(noticeText ?? seaText ?? " ")
                .font(Mincho.font(11.5))
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .foregroundStyle(noticeText == nil ? Paper.inkSoft : Paper.ribbon)

            castButton
        }
        .frame(maxWidth: .infinity)
    }

    /// 海の様子。
    ///
    /// **通数は書かない。** 浮かんでいる瓶がその数を示しているので、
    /// 文字で重ねると同じことを二度言うことになる。
    /// 押しても何も起きない理由があるときだけ言葉にする
    private var seaText: String? {
        if isPickingUp {
            return "拾っている"
        }
        if store.isOffline {
            return "海に繋がっていません"
        }
        if store.sea.drifting <= 0 {
            return "いま海に便りはない"
        }
        if !canPickUp {
            return "ひらくには、まず一通流す"
        }
        return nil
    }

    /// 流す入口。海の中に置く。
    /// 陸から投げ込むのではなく、海の中で手を放す絵に近づける
    private var castButton: some View {
        Button {
            noticeText = nil
            isComposing = true
        } label: {
            Text("海に流す")
                .font(Mincho.font(21, bold: true))
                .kerning(5)
                .foregroundStyle(Paper.ink)
                // 幅は文字なりに。横に広げると板になって、
                // 海に浮かんでいるものに見えなくなる
                .padding(.horizontal, 44)
                .padding(.vertical, 23)
                .background {
                    Capsule()
                        .fill(Paper.base.opacity(0.88))
                        .overlay {
                            Capsule()
                                .stroke(Paper.ink.opacity(0.55), lineWidth: 1.2)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 瓶をひらく

    /// 瓶に手を伸ばす。拾えないときは断る理由を返す
    private func openBottle() async {
        guard !isPickingUp else { return }
        guard store.sea.drifting > 0 else {
            noticeText = "いま海に便りはない"
            return
        }
        guard store.sea.canPickUp > 0 else {
            noticeText = "ひらけるのは、一通流したあと"
            return
        }

        isPickingUp = true
        noticeText = nil
        do {
            openedLetter = try await store.pickUp()
        } catch {
            noticeText = error.localizedDescription
        }
        isPickingUp = false
    }
}
