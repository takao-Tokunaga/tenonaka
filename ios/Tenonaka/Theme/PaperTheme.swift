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
///
/// 大きさは各画面で基準の値を渡し、ここで一律に倍率をかける。
/// 画面ごとに数字を書き換えると、少し直すたびに全画面を見て回ることになる。
enum Mincho {
    /// 字の大きさの倍率。
    /// 明朝は同じ pt でもゴシックより小さく見えるので、一段上げてある
    static let scale: CGFloat = 1.15

    /// 実際に組まれる大きさ。端数は丸めて、罫線の計算とずれないようにする
    static func size(_ base: CGFloat) -> CGFloat { (base * scale).rounded() }

    static func font(_ base: CGFloat, bold: Bool = false) -> Font {
        let name = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        if let uiFont = UIFont(name: name, size: size(base)) {
            return Font(uiFont)
        }
        // 明朝が取れない環境ではセリフ体にフォールバック
        return .system(size: size(base), weight: bold ? .semibold : .regular, design: .serif)
    }

    static func uiFont(_ base: CGFloat, bold: Bool = false) -> UIFont {
        let name = bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        return UIFont(name: name, size: size(base))
            ?? UIFont.systemFont(ofSize: size(base), weight: bold ? .semibold : .regular)
    }
}

/// 本文の組み。
///
/// 罫線と文字を同じ律で並べるため、行送りをここ一箇所で決める。
/// 背景に固定間隔の罫線を敷くと文字と噛み合わず、線が字に重なってしまう。
enum BodyText {
    /// 基準の大きさ。組み上がりは Mincho が倍率をかける
    static let size: CGFloat = 17

    /// 組み上がりの字の大きさ
    static var rendered: CGFloat { Mincho.size(size) }

    /**
     行送り。罫線の間隔もこれ。

     字の大きさに対する比で決める。17pt のときに 40pt で釣り合っていたので、
     その比を保つ。字を大きくしたときに罫線だけ据え置かれると詰まって見える。
     */
    static var pitch: CGFloat { (rendered * 40 / 17).rounded() }

    /// 字そのものの高さ。カーソルの丈もこれに合わせる
    static var glyphHeight: CGFloat {
        let font = Mincho.uiFont(size)
        return font.ascender - font.descender
    }

    /**
     カーソルを持ち上げる量。

     UITextView が返すカーソルの枠は行送りの余白まで含んでいるので、
     そのまま使うと字より下へ伸びる(実測で11pt下がっていた)。
     字の下端に合う量を画面で測り、字の大きさに対する比で持つ。
     */
    static var caretLift: CGFloat { (rendered * 0.5).rounded() }

    /**
     組み上がりの一行の高さは、描く仕組みによって違う。画面を測って確かめた値。

     - SwiftUI の `Text`  : 1em(17pt)
     - `UITextView`       : 約1.49em(25.3pt)

     どちらも行の高さは指定できず行間しか渡せないので、行送りを共通にして
     行間を種類ごとに逆算する。同じ行間を渡すと片方だけずれる。
     */
    static var textLineHeight: CGFloat { rendered }
    static var editorLineHeight: CGFloat { rendered * 1.488 }

    /// 読む画面(SwiftUI Text)に渡す行間
    static var textSpacing: CGFloat { pitch - textLineHeight }
    /// 書く欄(UITextView)に渡す行間
    static var editorSpacing: CGFloat { pitch - editorLineHeight }

    static var font: Font { Mincho.font(size) }
}

/// 本文の行に合わせて引く罫線。
///
/// 本文と同じ器の中に敷くので、器の原点が共通になり位置がずれない。
struct BodyRules: View {
    /**
     一行目の線の位置。

     字は行の器の上寄りに乗るので、行送りから素直に引くと線が下がりすぎる。
     画面を測ると、行送りのちょうど半分が字の下端の少し下に当たった。
     書く欄と読む欄で同じ値になったので、画面ごとの調整は持たせない。
     */
    var firstLine: CGFloat = BodyText.pitch / 2

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
            .stroke(Paper.rule.opacity(0.30), lineWidth: 0.5)
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
