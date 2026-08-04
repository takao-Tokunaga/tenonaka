import SwiftUI

struct RootView: View {
    var body: some View {
        // 検証用の画面は環境変数で差し込む(Debug ビルドのみ)
        if DebugFlags.composeTest {
            LetterComposeView()
        } else if DebugFlags.castAnimation {
            CastAnimationView(letter: .sample) {}
        } else if DebugFlags.letterReading {
            LetterReadingView(letter: .sample)
        } else if DebugFlags.tremorTest {
            TremorTestView()
        } else if DebugFlags.pulseTest {
            PulseTestView()
        } else {
            HomeView()
        }
    }
}
