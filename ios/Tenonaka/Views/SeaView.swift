import SwiftUI

/// 画面に広がる海。
///
/// 漂っている便りの数を、そのまま瓶の数として浮かべる。
/// 「海に6通あります」と書くより、6本の瓶が揺れているほうが海に見える。
///
/// 瓶は押せる。ボタンで「拾う」と書くより、浮かんでいるものに手を伸ばすほうが
/// 拾うという行いに近い。押されたときに拾えるかどうかは、呼んだ側が決める。
struct SeaView: View {
    /// 漂っている便りの数
    let drifting: Int
    /// 海を描く高さ。画面いっぱいを渡してよい
    var height: CGFloat = 235
    /// 水面の位置。この器の上端からの割合。
    /// 器を画面より大きくして水面をずらす作りだと、寸法が画面をはみ出して
    /// 前面の配置を壊すので、位置は割合で受け取る
    var waterLine: CGFloat = 0.5
    /// 瓶が押されたとき。渡さなければ押せない海になる
    var onOpenBottle: (() -> Void)?

    @State private var phase: CGFloat = 0
    @State private var bob = false
    @State private var sway = false
    @State private var swim = false

    /// 並べる上限。多すぎると海が混み合って静けさが失われる
    private let maxBottles = 7

    /// 瓶の横位置。毎回同じ並びにしたいので固定値を持つ
    private let positions: [CGFloat] = [0.14, 0.33, 0.52, 0.71, 0.86, 0.23, 0.62]

    private var bottleCount: Int { min(drifting, maxBottles) }

    /// 水面の高さ
    private var waterY: CGFloat { height * waterLine }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .top) {
                // 瓶は波の線の上に乗せる。波より先に描いて、手前の波に半分隠させる
                ForEach(0..<bottleCount, id: \.self) { index in
                    driftingBottle(index: index, width: width)
                }

                // 波と水の中の気配は絵なので押せない。
                // 下に敷いた瓶に指が届くようにする
                Group {
                    waves(width: width)
                    underwater(width: width)
                }
                .allowsHitTesting(false)
            }
            .frame(height: height, alignment: .top)
            .clipped()
        }
        .frame(height: height)
        .onAppear { startDrifting() }
    }

    private func startDrifting() {
        withAnimation(.linear(duration: 11).repeatForever(autoreverses: false)) {
            phase = 3
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            bob = true
        }
        withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
            sway = true
        }
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            // 個々の速さは魚ごとに上書きする。ここは向きを決めるだけ
            swim = true
        }
    }

    // MARK: - 水面

    private func waves(width: CGFloat) -> some View {
        // WaveShape は自分の枠の中央に線を引く。
        // 高さ2倍の枠の中央を水面に合わせるので、上端は水面から height だけ上
        ZStack(alignment: .top) {
            WaveShape(phase: phase, amplitude: 5, wavelength: width * 0.72)
                .fill(Color(red: 0.52, green: 0.62, blue: 0.62).opacity(0.24))
                .frame(height: height * 2)
                .offset(y: waterY - height)

            WaveShape(phase: phase + 0.42, amplitude: 8, wavelength: width * 0.98)
                .fill(Color(red: 0.36, green: 0.48, blue: 0.50).opacity(0.26))
                .frame(height: height * 2)
                .offset(y: waterY - height + 13)
        }
    }

    // MARK: - 水の中

    /// 水の中の気配。
    ///
    /// 水面より下が一様な塗りだと「面」に見えてしまう。
    /// 姿をはっきり描くと絵本になるので、影の濃さだけで気配を置く。
    private func underwater(width: CGFloat) -> some View {
        let depth = height - waterY

        return ZStack(alignment: .top) {
            ForEach(0..<Fish.all.count, id: \.self) { index in
                fish(Fish.all[index], width: width, depth: depth)
            }

            ForEach(0..<Seaweed.all.count, id: \.self) { index in
                seaweed(Seaweed.all[index], width: width, depth: depth)
            }
        }
        .frame(height: height, alignment: .top)
    }

    /// 魚の影。ゆっくり横切る。
    /// 深いほど淡く小さくして、遠くにいるように見せる
    private func fish(_ f: Fish, width: CGFloat, depth: CGFloat) -> some View {
        let length = 46 * f.scale
        let y = waterY + depth * f.depth

        return FishShape()
            .fill(Color(red: 0.20, green: 0.31, blue: 0.33).opacity(0.16 * f.scale))
            .frame(width: length, height: length * 0.42)
            // 向きを進む方へ。左へ泳ぐ魚は裏返す
            .scaleEffect(x: f.toLeft ? -1 : 1)
            .offset(x: swimOffset(f, width: width, length: length))
            .animation(
                .linear(duration: f.duration).repeatForever(autoreverses: false),
                value: swim
            )
            .position(x: 0, y: y)
    }

    /// 画面の外から外へ渡らせる。折り返さないので、ずっと同じ向きに泳ぐ
    private func swimOffset(_ f: Fish, width: CGFloat, length: CGFloat) -> CGFloat {
        let start = f.toLeft ? width + length : -length
        let end = f.toLeft ? -length : width + length
        return swim ? end : start
    }

    /// 海藻。根は底に、先は水の中で揺れる
    private func seaweed(_ w: Seaweed, width: CGFloat, depth: CGFloat) -> some View {
        let strandHeight = depth * w.height

        return SeaweedShape(sway: sway ? w.sway : -w.sway)
            .stroke(
                Color(red: 0.18, green: 0.30, blue: 0.28).opacity(0.13),
                style: StrokeStyle(lineWidth: w.thickness, lineCap: .round)
            )
            .frame(width: strandHeight * 0.5, height: strandHeight)
            .animation(
                .easeInOut(duration: w.duration).repeatForever(autoreverses: true),
                value: sway
            )
            // 根を海の底に置く
            .position(x: width * w.x, y: height - strandHeight / 2)
    }

    // MARK: - 瓶

    /// 漂うボトルメール。横倒しで、少しずつ違う間で上下する。
    ///
    /// 縦位置は水面に合わせる。中心を水面に置くと、
    /// 下半分が手前の波に隠れて水に浮いて見える。
    private func driftingBottle(index: Int, width: CGFloat) -> some View {
        // 中の便りと栓が見える大きさにする。空の瓶だと漂流物に見えてしまう
        let size = 27 + CGFloat(index % 3) * 4
        let x = width * positions[index % positions.count]
        // 一列に揃うと作り物に見えるので、少しずらす
        let row = CGFloat(index % 3) * 5 - 5

        return BottleMail(width: size)
            .rotationEffect(.degrees(74 + Double(index % 4) * 4))
            .offset(y: bob ? -5 : 3)
            .animation(
                .easeInOut(duration: 2.2 + Double(index % 4) * 0.5)
                    .repeatForever(autoreverses: true),
                value: bob
            )
            // 瓶は小さいので、指の当たる範囲は絵より広く取る
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { onOpenBottle?() }
            .position(x: x, y: waterY + row)
    }
}

// MARK: - 水の中の住人

/// 魚一匹の設定。乱数は使わない。毎回同じ海にしたいので固定で持つ
private struct Fish {
    /// 水面からの深さ(水の中の高さに対する割合)
    let depth: CGFloat
    /// 大きさ。遠くの魚は小さく淡くする
    let scale: CGFloat
    /// 渡り切るまでの秒数
    let duration: Double
    let toLeft: Bool

    /// 渡る秒数は一匹ずつ違える。揃うと群れが隊列を組んでいるように見えてしまう
    static let all: [Fish] = [
        Fish(depth: 0.14, scale: 0.75, duration: 31, toLeft: true),
        Fish(depth: 0.22, scale: 1.00, duration: 26, toLeft: false),
        Fish(depth: 0.30, scale: 0.60, duration: 38, toLeft: false),
        Fish(depth: 0.38, scale: 0.70, duration: 34, toLeft: true),
        Fish(depth: 0.46, scale: 0.90, duration: 23, toLeft: false),
        Fish(depth: 0.55, scale: 0.85, duration: 30, toLeft: false),
        Fish(depth: 0.62, scale: 0.50, duration: 44, toLeft: true),
        Fish(depth: 0.70, scale: 0.55, duration: 41, toLeft: true),
        Fish(depth: 0.78, scale: 0.72, duration: 28, toLeft: false),
        Fish(depth: 0.86, scale: 0.45, duration: 47, toLeft: true),
    ]
}

/// 海藻一本の設定
private struct Seaweed {
    /// 横位置(海の幅に対する割合)
    let x: CGFloat
    /// 丈(水の中の高さに対する割合)
    let height: CGFloat
    let thickness: CGFloat
    /// 揺れ幅
    let sway: CGFloat
    let duration: Double

    /// 揺れる間(duration)は一本ずつ違える。
    /// 揃うと一斉に動いて、造花の束のように見えてしまう
    static let all: [Seaweed] = [
        Seaweed(x: 0.03, height: 0.16, thickness: 3.2, sway: 0.7, duration: 5.0),
        Seaweed(x: 0.07, height: 0.22, thickness: 4.2, sway: 0.6, duration: 4.6),
        Seaweed(x: 0.12, height: 0.13, thickness: 2.8, sway: 0.85, duration: 3.8),
        Seaweed(x: 0.17, height: 0.19, thickness: 3.6, sway: 0.65, duration: 5.8),
        Seaweed(x: 0.24, height: 0.10, thickness: 2.6, sway: 0.9, duration: 4.2),
        Seaweed(x: 0.33, height: 0.15, thickness: 3.0, sway: 0.7, duration: 6.2),
        Seaweed(x: 0.41, height: 0.11, thickness: 2.6, sway: 0.8, duration: 4.8),
        Seaweed(x: 0.50, height: 0.17, thickness: 3.4, sway: 0.6, duration: 3.4),
        Seaweed(x: 0.58, height: 0.10, thickness: 2.4, sway: 0.9, duration: 5.4),
        Seaweed(x: 0.66, height: 0.14, thickness: 3.0, sway: 0.75, duration: 4.0),
        Seaweed(x: 0.74, height: 0.20, thickness: 3.8, sway: 0.6, duration: 6.0),
        Seaweed(x: 0.81, height: 0.12, thickness: 2.8, sway: 0.85, duration: 4.4),
        Seaweed(x: 0.88, height: 0.18, thickness: 3.6, sway: 0.7, duration: 5.6),
        Seaweed(x: 0.95, height: 0.13, thickness: 3.0, sway: 0.8, duration: 3.6),
    ]
}

/// 魚の影。尾のある紡錘形。右向きで描く
private struct FishShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        // 胴。前が丸く後ろが細い紡錘形
        path.move(to: point(1.0, 0.5))
        path.addCurve(to: point(0.30, 0.06), control1: point(0.82, 0.0), control2: point(0.52, 0.02))
        path.addCurve(to: point(0.30, 0.94), control1: point(0.10, 0.10), control2: point(0.10, 0.90))
        path.addCurve(to: point(1.0, 0.5), control1: point(0.52, 0.98), control2: point(0.82, 1.0))
        path.closeSubpath()

        // 尾びれ
        path.move(to: point(0.30, 0.5))
        path.addLine(to: point(0.0, 0.10))
        path.addQuadCurve(to: point(0.0, 0.90), control: point(0.14, 0.5))
        path.closeSubpath()
        return path
    }
}

/// 海藻一本。根を下に、先を揺らす
private struct SeaweedShape: Shape {
    /// 揺れ。0で直立、正負で左右にしなる
    var sway: CGFloat

    var animatableData: CGFloat {
        get { sway }
        set { sway = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX + sway * rect.width * 0.5, y: rect.minY),
            control1: CGPoint(
                x: rect.midX - sway * rect.width * 0.35,
                y: rect.maxY - rect.height * 0.4
            ),
            control2: CGPoint(
                x: rect.midX + sway * rect.width * 0.65,
                y: rect.minY + rect.height * 0.3
            )
        )
        return path
    }
}
