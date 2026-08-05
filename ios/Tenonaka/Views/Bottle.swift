import SwiftUI

/// 瓶の輪郭。細い首と、なだらかな肩を持たせて硝子瓶に見せる。
///
/// 海に浮かぶ瓶と、流すときの演出で同じ形を使う。
/// 自分が流した瓶と海の瓶が違う形だと、同じ海の話に見えない。
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

/// 便りの入った瓶。栓がされ、胴に巻かれた紙が沈んでいる。
///
/// 空の瓶だと「漂流物」に見えてしまう。栓と中身があって初めて
/// 誰かが宛先の無いまま流した便りに見える。
///
/// 中身の位置は瓶の丈に対する割合で置く。大きさを変えても崩れない。
struct BottleMail: View {
    /// 瓶の幅。丈はここから決まる
    let width: CGFloat

    private var height: CGFloat { width * 1.78 }

    /// 瓶の上端からの割合を、中心を基準にしたずれに直す
    private func offsetY(_ fraction: CGFloat) -> CGFloat { (fraction - 0.5) * height }

    var body: some View {
        ZStack {
            glass

            scroll
                .offset(y: offsetY(0.64))

            cork
                .offset(y: offsetY(0.045))
        }
        .frame(width: width, height: height)
    }

    private var glass: some View {
        ZStack {
            BottleShape()
                .fill(Color(red: 0.60, green: 0.70, blue: 0.68).opacity(0.62))
            BottleShape()
                .stroke(Color(red: 0.36, green: 0.46, blue: 0.45).opacity(0.5), lineWidth: 0.8)
        }
    }

    /// 巻かれた便り。
    ///
    /// 細い棒にすると瓶のラベルに見えてしまうので、筒として太く取り、
    /// 両端に口を描いて中が空いていることを示す。
    private var scroll: some View {
        let thickness = width * 0.24
        let length = width * 0.52

        return RoundedRectangle(cornerRadius: thickness * 0.16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.80, blue: 0.71),
                        Paper.base,
                        Color(red: 0.82, green: 0.78, blue: 0.69),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                VStack {
                    // 筒の両端。中が空いている口
                    Ellipse()
                        .fill(Paper.shade.opacity(0.45))
                        .frame(width: thickness * 0.84, height: thickness * 0.30)
                    Spacer(minLength: 0)
                    Ellipse()
                        .fill(Paper.shade.opacity(0.3))
                        .frame(width: thickness * 0.84, height: thickness * 0.30)
                }
                .padding(.vertical, -thickness * 0.09)
            }
            .frame(width: thickness, height: length)
            .rotationEffect(.degrees(-8))
    }

    private var cork: some View {
        RoundedRectangle(cornerRadius: width * 0.016)
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
            .frame(width: width * 0.158, height: width * 0.082)
    }
}
