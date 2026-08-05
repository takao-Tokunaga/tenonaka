import SwiftUI
import UIKit

/// 本文を書く欄。
///
/// SwiftUI の TextEditor を使わない理由はカーソルの高さである。
/// 行送りを広く取ると、17pt の字の横に行送りぶんの縦棒が立って壊れて見える。
/// TextEditor にはカーソルの丈を変える手立てがない。
///
/// **スクロールは自分で持つ。** 外側のスクロールに預けると、
/// 内容が増えたときの丈を SwiftUI に伝え続けることになり、長文で崩れる。
/// 自分でスクロールすれば、カーソルの追従も長文の扱いも UIKit がやってくれる。
struct BodyTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// 外から下げられるようにする(封をする前に鍵盤を閉じたい)
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let view = CaretTrimmedTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = UIColor(Paper.ink)
        view.tintColor = UIColor(Paper.ribbon)
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = true
        view.showsVerticalScrollIndicator = false
        view.keyboardDismissMode = .interactive
        view.typingAttributes = Self.attributes
        view.attributedText = NSAttributedString(string: text, attributes: Self.attributes)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: Self.attributes)
        }
        // 鍵盤の開閉を外の状態に合わせる
        if isFocused, !view.isFirstResponder {
            view.becomeFirstResponder()
        } else if !isFocused, view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    /// 行送りは行間で調整する。
    /// minimum/maximumLineHeight で高さを決めると、その上にさらに行送りが
    /// 足されて広がってしまう(実測で 48pt)。
    static var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = BodyText.editorSpacing
        return [
            .font: Mincho.uiFont(BodyText.size),
            .foregroundColor: UIColor(Paper.ink),
            .paragraphStyle: paragraph,
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>
        private let isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !isFocused.wrappedValue { isFocused.wrappedValue = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if isFocused.wrappedValue { isFocused.wrappedValue = false }
        }
    }
}

/// カーソルを字に合わせる。
///
/// 既定のカーソルは行の器いっぱいに立つので、行送りを広く取ると縦棒が長くなり、
/// さらに行送りの余白ぶん字より下へ伸びる。丈と位置の両方を字に合わせる。
private final class CaretTrimmedTextView: UITextView {
    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        let height = BodyText.glyphHeight
        rect.origin.y = rect.maxY - height - BodyText.caretLift
        rect.size.height = height
        return rect
    }
}
