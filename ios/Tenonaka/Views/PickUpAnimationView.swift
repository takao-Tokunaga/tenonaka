import SwiftUI

/// 瓶を拾って開ける演出。
///
/// 流すときに「瓶に入れて流れていく」を見せているので、拾うときも
/// 「流れてきて、栓を抜いて、中身が出てくる」を見せないと釣り合わない。
/// 拾った瞬間にいきなり本文が出ると、海の話が途切れてしまう。
///
/// 波の向こうから来る → 手元で立つ → 栓が抜ける → 便りが出る → 開く の順。
/// タップで飛ばせる。
struct PickUpAnimationView: View {
    let letter: Letter
    let onOpened: () -> Void

    /// 0:遠く 1:近づく 2:手元で立つ 3:栓が抜ける 4:便りが出る 5:開く
    @State private var stage = 0
    @State private var wavePhase: CGFloat = 0
    @State private var bob = false
    /// 一度流したら二度は流さない。画面が出し直されても最初から始めないため
    @State private var didPlay = false
    @State private var didFinish = false

    private var isNear: Bool { stage >= 1 }
    private var isUpright: Bool { stage >= 2 }
    private var isUncorked: Bool { stage >= 3 }
    private var isOut: Bool { stage >= 4 }
    private var isUnrolled: Bool { stage >= 5 }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            /// 水面。瓶はここから上がってくる
            let waterY = size.height * 0.66
            let side = min(size.width * 0.40, 190)
            let bottleHeight = side * 1.78

            ZStack {
                PaperSurface(showsRules: false)
                    .ignoresSafeArea()

                sea(size: size, waterY: waterY)

                bottle(side: side, height: bottleHeight)
                    // 横倒しで流れてきて、手元で立つ
                    .rotationEffect(.degrees(isUpright ? 0 : 76))
                    .scaleEffect(isNear ? 1 : 0.62)
                    .opacity(isUnrolled ? 0 : 1)
                    .position(
                        x: isNear ? size.width / 2 : size.width * 1.22,
                        y: isUpright
                            ? waterY - bottleHeight * 0.30 + (bob ? -6 : 0)
                            : waterY
                    )

                // 開いた便り。瓶から出た紙が広がる
                if isUnrolled {
                    page(size: size)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { finish() }
        }
        .task {
            guard !didPlay else { return }
            didPlay = true
            await play()
        }
    }

    // MARK: - 瓶

    private func bottle(side: CGFloat, height: CGFloat) -> some View {
        /// 瓶の上端からの割合を、中心を基準にしたずれに直す
        func offsetY(_ fraction: CGFloat) -> CGFloat { (fraction - 0.5) * height }

        return ZStack {
            glass(side: side)

            // 巻かれた便り。胴から首を通って上へ出る
            scroll(side: side)
                .offset(y: isOut ? offsetY(-0.28) : offsetY(0.64))
                .opacity(isOut ? 1 : 0.92)

            if !isUncorked {
                cork(side: side)
                    .offset(y: offsetY(0.045))
                    .transition(.offset(y: -side * 0.55).combined(with: .opacity))
            }
        }
        .frame(width: side, height: height)
    }

    private func glass(side: CGFloat) -> some View {
        ZStack {
            BottleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.76, green: 0.83, blue: 0.80).opacity(0.34),
                            Color(red: 0.60, green: 0.71, blue: 0.69).opacity(0.44),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            BottleShape()
                .stroke(Color(red: 0.40, green: 0.50, blue: 0.48).opacity(0.5), lineWidth: 1.1)

            // 硝子の照り
            Capsule()
                .fill(Color.white.opacity(0.38))
                .frame(width: side * 0.03, height: side * 0.34)
                .offset(x: -side * 0.14, y: side * 0.20)
        }
    }

    /// 巻かれた便り。筒として描き、両端に口を出す
    private func scroll(side: CGFloat) -> some View {
        let thickness = side * 0.125
        let length = side * 0.50

        return RoundedRectangle(cornerRadius: thickness * 0.16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.83, green: 0.79, blue: 0.70),
                        Paper.base,
                        Paper.base,
                        Color(red: 0.80, green: 0.76, blue: 0.67),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                VStack {
                    Ellipse()
                        .stroke(Paper.shade.opacity(0.7), lineWidth: 0.9)
                        .frame(width: thickness * 0.86, height: thickness * 0.30)
                    Spacer(minLength: 0)
                    Ellipse()
                        .fill(Paper.shade.opacity(0.35))
                        .frame(width: thickness * 0.86, height: thickness * 0.30)
                }
                .padding(.vertical, -thickness * 0.10)
            }
            .frame(width: thickness, height: length)
            .shadow(color: .black.opacity(0.13), radius: 4, y: 2)
            .rotationEffect(.degrees(-6))
    }

    private func cork(side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: side * 0.016)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.74, green: 0.59, blue: 0.40),
                        Color(red: 0.58, green: 0.44, blue: 0.28),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: side * 0.158, height: side * 0.078)
    }

    // MARK: - 海

    private func sea(size: CGSize, waterY: CGFloat) -> some View {
        ZStack {
            WaveShape(phase: wavePhase, amplitude: 5, wavelength: size.width * 0.70)
                .fill(Color(red: 0.52, green: 0.62, blue: 0.62).opacity(0.22))
            WaveShape(phase: wavePhase + 0.42, amplitude: 8, wavelength: size.width * 0.98)
                .fill(Color(red: 0.36, green: 0.48, blue: 0.50).opacity(0.26))
                .offset(y: 11)
        }
        // 高さを画面の2倍取り、中央(=波の線)を水面に合わせる
        .frame(width: size.width, height: size.height * 2)
        .position(x: size.width / 2, y: waterY)
    }

    // MARK: - 開いた紙

    /// 巻かれていた紙が広がったところ。読む画面へ渡す直前の絵
    private func page(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Paper.base)
            .overlay(alignment: .topLeading) {
                // 便箋に見せる罫線。文字はまだ出さない(握らないと現れない)
                BodyRules()
                    .padding(.horizontal, 22)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Paper.shade.opacity(0.5), lineWidth: 0.7)
            }
            .frame(width: size.width * 0.78, height: size.height * 0.52)
            .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
    }

    // MARK: - 進行

    /// 待ちは `try?` で潰さない。
    /// 打ち切られた Task の中では待ちが即座に抜けるので、`try?` にすると
    /// 残りの段が一気に流れてしまう
    private func play() async {
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            wavePhase = 3
        }

        // 全体で4秒台に収める。読む前に長く待たせると、
        // 本文が現れるまで手を握り続ける段でさらに待つことになる
        do {
            try await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 1.1)) { stage = 1 }
            try await Task.sleep(for: .milliseconds(1130))
            withAnimation(.easeInOut(duration: 0.75)) { stage = 2 }
            try await Task.sleep(for: .milliseconds(780))
            // 立ってから揺れはじめる
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                bob = true
            }
            try await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { stage = 3 }
            try await Task.sleep(for: .milliseconds(380))
            withAnimation(.easeInOut(duration: 0.65)) { stage = 4 }
            try await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeInOut(duration: 0.5)) { stage = 5 }
            try await Task.sleep(for: .milliseconds(520))
        } catch {
            return
        }

        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onOpened()
    }
}

/// 拾ってから読むまでの流れ。
///
/// 演出と読む画面を別の画面として重ねず、同じ器の中で差し替える。
/// 重ねると、閉じかけの画面と出しかけの画面がぶつかって出し直しになる。
struct PickUpFlowView: View {
    let letter: Letter
    let onReceipt: (ReadReceipt) -> Void

    @State private var isOpened = false

    var body: some View {
        ZStack {
            if isOpened {
                LetterReadingView(letter: letter, onReceipt: onReceipt)
            } else {
                PickUpAnimationView(letter: letter) {
                    withAnimation(.easeInOut(duration: 0.5)) { isOpened = true }
                }
            }
        }
    }
}
