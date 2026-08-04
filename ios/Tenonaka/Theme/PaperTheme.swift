import SwiftUI
import UIKit

/// 紙と本の質感をまとめた定義。
enum Paper {
    /// 生成りの紙
    static let base = Color(red: 0.953, green: 0.925, blue: 0.867)
    /// ページの端に落ちる影の色
    static let shade = Color(red: 0.784, green: 0.729, blue: 0.639)
    /// 罫線
    static let rule = Color(red: 0.741, green: 0.694, blue: 0.616)
    /// 本文の墨色
    static let ink = Color(red: 0.169, green: 0.145, blue: 0.125)
    /// 薄い墨(日付・補助文字)
    static let inkSoft = Color(red: 0.408, green: 0.365, blue: 0.318)
    /// さらに薄い墨(プレースホルダ)
    static let inkFaint = Color(red: 0.596, green: 0.549, blue: 0.490)
    /// 机の色(本の外側)
    static let desk = Color(red: 0.145, green: 0.118, blue: 0.098)
    /// 表紙の布
    static let cover = Color(red: 0.239, green: 0.278, blue: 0.259)
    /// しおりの紐
    static let ribbon = Color(red: 0.549, green: 0.216, blue: 0.204)
    /// 箔押しの金
    static let gold = Color(red: 0.816, green: 0.729, blue: 0.549)
}

/// 明朝体。日本語の記録アプリなので、本文はゴシックではなく明朝で組む。
enum Mincho {
    static func font(_ size: CGFloat, bold: Bool = false) -> Font {
        let name = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        if let uiFont = UIFont(name: name, size: size) {
            return Font(uiFont)
        }
        // 明朝が取れない環境ではセリフ体にフォールバック
        return .system(size: size, weight: bold ? .semibold : .regular, design: .serif)
    }

    static func uiFont(_ size: CGFloat, bold: Bool = false) -> UIFont {
        let name = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        return UIFont(name: name, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    }
}

/// 本文の組み。
///
/// 罫線と文字を同じ律で並べるため、行送りをここ一箇所で決める。
/// 背景に固定間隔の罫線を敷くと文字と噛み合わず、線が字に重なってしまう。
enum BodyText {
    static let size: CGFloat = 17
    /// 行間。字の詰まりはこれで決まる
    static let spacing: CGFloat = 15

    /// フォント自体の行の高さ。実測値を使う(明朝で size の1.5倍前後)
    static var lineHeight: CGFloat { Mincho.uiFont(size).lineHeight }

    /// 一行が占める高さ。罫線の間隔もこれに合わせる
    static var pitch: CGFloat { lineHeight + spacing }

    static var font: Font { Mincho.font(size) }
}

/// 本文の行に合わせて引く罫線。
///
/// 本文と同じ器の中に敷くので、器の原点が共通になり位置がずれない。
struct BodyRules: View {
    /// 最初の線をどこに引くか。字の下に来るよう、行の高さから少し上げる
    private var firstLine: CGFloat { BodyText.lineHeight - 3 }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                var y = firstLine
                while y < geometry.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += BodyText.pitch
                }
            }
            .stroke(Paper.rule.opacity(0.34), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// 紙の粒子。単色の矩形だと「画面」に見えてしまうので、
/// 起動時に一度だけノイズ画像を作ってタイル敷きしている。
enum PaperGrain {
    static let image: Image = Image(uiImage: make())

    private static func make() -> UIImage {
        let side = 128
        let size = CGSize(width: side, height: side)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15

        func random() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((seed >> 33) % 1000) / 1000
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            for x in 0..<side {
                for y in 0..<side {
                    let value = random()
                    guard value > 0.55 else { continue }
                    let isDark = random() > 0.45
                    UIColor(white: isDark ? 0.35 : 1.0, alpha: (value - 0.55) * 0.22).setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
}

/// 1枚の紙。罫線・粒子・端の影までを含む。
struct PaperSurface: View {
    var showsRules = true
    var lineSpacing: CGFloat = 34

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Paper.base,
                    Paper.base.opacity(0.97),
                    Color(red: 0.929, green: 0.898, blue: 0.831),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PaperGrain.image
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.55)

            if showsRules {
                GeometryReader { geometry in
                    Path { path in
                        var y = lineSpacing * 3.6
                        while y < geometry.size.height - lineSpacing {
                            path.move(to: CGPoint(x: 26, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width - 26, y: y))
                            y += lineSpacing
                        }
                    }
                    .stroke(Paper.rule.opacity(0.32), lineWidth: 0.5)
                }
            }

            // 綴じ側(左)に落ちる影 — 平面ではなく「本のページ」に見せるための要素
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Paper.shade.opacity(0.55), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 26)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.clear, Paper.shade.opacity(0.22)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 14)
            }
        }
    }
}
