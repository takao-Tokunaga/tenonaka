import SwiftUI

/// 画面の下に広がる海。
///
/// 漂っている手紙の数を、そのまま瓶の数として浮かべる。
/// 「海に6通あります」と書くより、6本の瓶が揺れているほうが海に見える。
struct SeaView: View {
    /// 漂っている手紙の数
    let drifting: Int
    /// 海の高さ。画面に対する割合ではなく実寸で渡す
    var height: CGFloat = 235

    @State private var phase: CGFloat = 0
    @State private var bob = false

    /// 並べる上限。多すぎると海が混み合って静けさが失われる
    private let maxBottles = 7

    /// 瓶の横位置。毎回同じ並びにしたいので固定値を持つ
    private let positions: [CGFloat] = [0.14, 0.33, 0.52, 0.71, 0.86, 0.23, 0.62]

    private var bottleCount: Int { min(drifting, maxBottles) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .top) {
                // 瓶は波の線の上に乗せる。波より先に描いて、手前の波に半分隠させる
                ForEach(0..<bottleCount, id: \.self) { index in
                    driftingBottle(index: index, width: width)
                }

                WaveShape(phase: phase, amplitude: 5, wavelength: width * 0.72)
                    .fill(Color(red: 0.52, green: 0.62, blue: 0.62).opacity(0.24))
                    .frame(height: height * 2)
                    .offset(y: -height * 0.5)

                WaveShape(phase: phase + 0.42, amplitude: 8, wavelength: width * 0.98)
                    .fill(Color(red: 0.36, green: 0.48, blue: 0.50).opacity(0.26))
                    .frame(height: height * 2)
                    .offset(y: -height * 0.5 + 13)
            }
            .frame(height: height, alignment: .top)
            .clipped()
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 11).repeatForever(autoreverses: false)) {
                phase = 3
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
    }

    /// 漂う瓶。横倒しで、少しずつ違う間で上下する。
    ///
    /// 縦位置は波の線に合わせる。WaveShape は自分の frame の中央に線を引くので、
    /// 高さ2倍の枠を半分だけ上へずらしてある = 線はこの容器の height/2 にある。
    /// そこに瓶の中心を置くと、下半分が手前の波に隠れて水に浮いて見える。
    private func driftingBottle(index: Int, width: CGFloat) -> some View {
        let size = 21 + CGFloat(index % 3) * 3
        let x = width * positions[index % positions.count]
        // 一列に揃うと作り物に見えるので、少しずらす
        let row = CGFloat(index % 3) * 5 - 5
        let waterLine = height * 0.5

        return BottleShape()
            .fill(Color(red: 0.60, green: 0.70, blue: 0.68).opacity(0.62))
            .overlay {
                BottleShape()
                    .stroke(Color(red: 0.36, green: 0.46, blue: 0.45).opacity(0.5), lineWidth: 0.8)
            }
            .frame(width: size, height: size * 1.78)
            .rotationEffect(.degrees(74 + Double(index % 4) * 4))
            .offset(y: bob ? -5 : 3)
            .animation(
                .easeInOut(duration: 2.2 + Double(index % 4) * 0.5)
                    .repeatForever(autoreverses: true),
                value: bob
            )
            .position(x: x, y: waterLine + row)
    }
}
