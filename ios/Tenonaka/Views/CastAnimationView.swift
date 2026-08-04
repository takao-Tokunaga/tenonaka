import SwiftUI

/// 瓶の輪郭。細い首と、なだらかな肩を持たせて硝子瓶に見せる。
struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        // 口(わずかに張り出す)
        path.move(to: point(0.393, 0.004))
        path.addLine(to: point(0.607, 0.004))
        path.addLine(to: point(0.607, 0.040))
        path.addLine(to: point(0.580, 0.056))
        // 首。細く長くする
        path.addLine(to: point(0.580, 0.270))
        // 肩(右)。二段の曲線でなだらかに落とす
        path.addCurve(
            to: point(0.795, 0.455),
            control1: point(0.596, 0.355),
            control2: point(0.795, 0.365)
        )
        // 胴(右)
        path.addLine(to: point(0.795, 0.930))
        path.addQuadCurve(to: point(0.695, 0.996), control: point(0.795, 0.982))
        // 底
        path.addLine(to: point(0.305, 0.996))
        path.addQuadCurve(to: point(0.205, 0.930), control: point(0.205, 0.982))
        // 胴(左)
        path.addLine(to: point(0.205, 0.455))
        // 肩(左)
        path.addCurve(
            to: point(0.420, 0.270),
            control1: point(0.205, 0.365),
            control2: point(0.404, 0.355)
        )
        // 首
        path.addLine(to: point(0.420, 0.056))
        path.addLine(to: point(0.393, 0.040))
        path.closeSubpath()
        return path
    }
}

/// 波。位相を動かして流れをつくる。線は frame の中央、塗りはそこから下。
struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var wavelength: CGFloat

    /// これがあると phase の変化がアニメーションになる
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        var x = rect.minX
        while x <= rect.maxX {
            let relative = (x - rect.minX) / wavelength
            let y = rect.midY + sin((relative + phase) * 2 * .pi) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 手紙を瓶に入れて海に流す演出。
///
/// 巻く → 瓶が来る → 入れる → 栓をする → 水面に浮かぶ → 流れていく の順。
/// 位置は画面の高さに対する割合で決めているので、水面と瓶がずれない。
/// タップで飛ばせる。
struct CastAnimationView: View {
    let letter: Letter
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// 0:紙 1:巻く 2:瓶が来る 3:入れる 4:栓 5:水面に浮かぶ 6:流れていく 7:文字
    @State private var stage = 0
    @State private var wavePhase: CGFloat = 0
    @State private var bob = false
    @State private var didFinish = false

    private var isRolled: Bool { stage >= 1 }
    private var hasBottle: Bool { stage >= 2 }
    private var isInside: Bool { stage >= 3 }
    private var isCorked: Bool { stage >= 4 }
    private var isFloating: Bool { stage >= 5 }
    private var isDrifting: Bool { stage >= 6 }
    private var showsCaption: Bool { stage >= 7 }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            /// 水面の高さ。ここに瓶を乗せる
            let waterY = size.height * 0.70
            let side = min(size.width * 0.44, 210)
            let bottleHeight = side * 1.78

            ZStack {
                PaperSurface(showsRules: false)
                    .ignoresSafeArea()

                sea(size: size, waterY: waterY)

                bottleAssembly(side: side, height: bottleHeight)
                    .rotationEffect(.degrees(isFloating ? 72 : 0))
                    .scaleEffect(isDrifting ? 0.82 : 1)
                    .opacity(isDrifting ? 0 : 1)
                    .position(
                        x: isDrifting ? size.width * 1.3 : size.width / 2,
                        // 浮かぶ段では瓶の中心を水面のすぐ上に置く
                        y: isFloating
                            ? waterY - side * 0.06 + (bob ? -7 : 0)
                            : size.height * 0.40
                    )

                caption
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 34)
                    .position(x: size.width / 2, y: size.height * 0.40)
                    .opacity(showsCaption ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { skip() }
        }
        .task { await play() }
    }

    // MARK: - 瓶と手紙

    private func bottleAssembly(side: CGFloat, height: CGFloat) -> some View {
        /// 瓶の上端からの割合を、中心基準のずれに直す
        func offsetY(_ fraction: CGFloat) -> CGFloat { (fraction - 0.5) * height }

        return ZStack {
            if hasBottle {
                glass(side: side)
                    .transition(.opacity)
            }

            // 巻かれた手紙。瓶の上から胴の中へ落ちる
            scroll(side: side)
                .offset(y: isInside ? offsetY(0.66) : (hasBottle ? offsetY(-0.22) : 0))

            if isCorked {
                cork(side: side)
                    .offset(y: offsetY(0.045))
                    .transition(.offset(y: -side * 0.5).combined(with: .opacity))
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

    /// 巻かれた手紙。巻く前は罫線のある紙、巻いた後は筒。
    ///
    /// 角を丸めすぎるとカプセル薬に見えるので、筒の角は僅かだけ落とし、
    /// 巻きの縁と両端の口を線で描いて紙が巻かれていることを示す。
    private func scroll(side: CGFloat) -> some View {
        let width = isRolled ? side * 0.115 : side * 0.66
        let height = isRolled ? side * 0.46 : side * 0.80
        let radius: CGFloat = isRolled ? side * 0.012 : 2

        return RoundedRectangle(cornerRadius: radius)
            .fill(
                LinearGradient(
                    colors: isRolled
                        ? [
                            Color(red: 0.83, green: 0.79, blue: 0.70),
                            Paper.base,
                            Paper.base,
                            Color(red: 0.80, green: 0.76, blue: 0.67),
                          ]
                        : [Paper.base, Paper.base],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                if isRolled {
                    ZStack {
                        // 巻き終わりの縁。紙が重なっている線
                        Rectangle()
                            .fill(Paper.shade.opacity(0.55))
                            .frame(width: 0.9)
                            .offset(x: width * 0.16)

                        // 筒の両端。中が空いていることを示す濃い線
                        VStack {
                            Ellipse()
                                .stroke(Paper.shade.opacity(0.7), lineWidth: 0.9)
                                .frame(width: width * 0.86, height: width * 0.30)
                            Spacer()
                            Ellipse()
                                .fill(Paper.shade.opacity(0.35))
                                .frame(width: width * 0.86, height: width * 0.30)
                        }
                        .padding(.vertical, -width * 0.10)
                    }
                } else {
                    VStack(spacing: side * 0.085) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(Paper.rule.opacity(0.5))
                                .frame(height: 0.8)
                        }
                    }
                    .padding(side * 0.10)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Paper.shade.opacity(0.5), lineWidth: 0.6)
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.13), radius: 4, y: 2)
            .rotationEffect(.degrees(isRolled ? -7 : 0))
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
        // 浮かぶ段になってから満ちてくる
        .offset(y: isFloating ? 0 : size.height - waterY + 40)
    }

    private var caption: some View {
        VStack(spacing: 18) {
            Text("海に流しました")
                .font(Mincho.font(19))
                .foregroundStyle(Paper.ink)

            if let bpm = letter.senderBpm {
                ZStack {
                    Circle()
                        .fill(Paper.ribbon.opacity(0.92))
                        .frame(width: 70, height: 70)
                    VStack(spacing: 0) {
                        Text("\(Int(bpm.rounded()))")
                            .font(Mincho.font(26, bold: true))
                        Text("拍")
                            .font(Mincho.font(10))
                    }
                    .foregroundStyle(Paper.base)
                }
                .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
            }

            VStack(spacing: 6) {
                Text("いつか、見知らぬ誰かが拾います")
                    .font(Mincho.font(13))
                    .foregroundStyle(Paper.inkSoft)
                Text("返ってくるのは、その人が持っていた時間と脈だけです")
                    .font(Mincho.font(11.5))
                    .foregroundStyle(Paper.inkFaint)
                Text("あなたも一通、拾えるようになりました")
                    .font(Mincho.font(12))
                    .foregroundStyle(Paper.ribbon.opacity(0.85))
                    .padding(.top, 6)
            }
            .multilineTextAlignment(.center)

            Button {
                finish()
            } label: {
                Text("とじる")
                    .font(Mincho.font(14))
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - 進行

    private func play() async {
        // 波は最初から動かしておく(満ちてくるのは後から)
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            wavePhase = 3
        }

        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.easeInOut(duration: 0.7)) { stage = 1 }
        try? await Task.sleep(for: .milliseconds(760))
        withAnimation(.easeOut(duration: 0.5)) { stage = 2 }
        try? await Task.sleep(for: .milliseconds(580))
        withAnimation(.easeIn(duration: 0.7)) { stage = 3 }
        try? await Task.sleep(for: .milliseconds(760))
        withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { stage = 4 }
        try? await Task.sleep(for: .milliseconds(560))
        withAnimation(.easeInOut(duration: 1.1)) { stage = 5 }
        try? await Task.sleep(for: .milliseconds(1150))
        // 浮いてから揺れはじめる
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            bob = true
        }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeInOut(duration: 2.6)) { stage = 6 }
        try? await Task.sleep(for: .milliseconds(1700))
        withAnimation(.easeIn(duration: 0.9)) { stage = 7 }
    }

    /// タップで飛ばす。演出は主役ではないので待たせない
    private func skip() {
        guard stage < 7 else { return }
        withAnimation(.easeInOut(duration: 0.4)) { stage = 7 }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        dismiss()
        onClose()
    }
}
