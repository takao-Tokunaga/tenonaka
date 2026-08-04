import Foundation

/// 動作確認とデモ用の起動フラグ。環境変数で初期状態を指定して起動できる。
///
///   xcrun devicectl device process launch --device <id> --terminate-existing \
///     --environment-variables '{"LETTER":"1"}' dev.takao.tenonaka
///
/// シミュレータの場合は SIMCTL_CHILD_ 接頭辞をつけて渡す。
/// Release ビルドでは常に無効。
enum DebugFlags {
    #if DEBUG
    private static let env = ProcessInfo.processInfo.environment

    /// 手紙を読む画面だけを出す(サンプルの手紙)
    static var letterReading: Bool { env["LETTER"] == "1" }

    /// 脈の検証画面だけを出す
    static var pulseTest: Bool { env["PULSE_TEST"] == "1" }

    /// 微動の検証画面だけを出す
    static var tremorTest: Bool { env["TREMOR_TEST"] == "1" }
    #else
    static var letterReading: Bool { false }
    static var pulseTest: Bool { false }
    static var tremorTest: Bool { false }
    #endif
}
