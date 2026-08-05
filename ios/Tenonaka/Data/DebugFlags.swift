import Foundation

/// 動作確認とデモ用の起動フラグ。環境変数で初期状態を指定して起動できる。
///
///   xcrun devicectl device process launch --device <id> --terminate-existing \
///     --environment-variables '{"LETTER":"1"}' dev.takao.namibin
///
/// シミュレータの場合は SIMCTL_CHILD_ 接頭辞をつけて渡す。
/// Release ビルドでは常に無効。
enum DebugFlags {
    #if DEBUG
    private static let env = ProcessInfo.processInfo.environment

    /// 便りを読む画面だけを出す(サンプルの便り)
    static var letterReading: Bool { env["LETTER"] == "1" }

    /// 脈の検証画面だけを出す
    static var pulseTest: Bool { env["PULSE_TEST"] == "1" }

    /// 微動の検証画面だけを出す
    static var tremorTest: Bool { env["TREMOR_TEST"] == "1" }

    /// 瓶に入れて流す演出だけを出す(カメラが要らないのでシミュレータで確認できる)
    static var castAnimation: Bool { env["CAST_ANIM"] == "1" }

    /// 握らなくても文字を現す。シミュレータには加速度センサーが無いので、
    /// 組み(罫線と文字の行送り)を確かめるために使う
    static var revealWithoutHolding: Bool { env["REVEAL_ALL"] == "1" }

    /// 書く画面を、文字を入れた状態で開く。罫線との噛み合わせを見るため
    static var composeTest: Bool { env["COMPOSE"] == "1" }

    /// 文箱(過去に拾った・流した便り)だけを出す
    static var shelf: Bool { env["SHELF"] == "1" }

    /// 瓶を拾って開ける演出だけを出す
    static var pickUpAnimation: Bool { env["PICKUP_ANIM"] == "1" }

    /// 自分が流した便りを読み返す画面だけを出す
    static var sentLetter: Bool { env["SENT"] == "1" }

    /// 脈を測らずに封をして、そのまま流すところまで自動で進める。
    /// シミュレータにはカメラが無いので、流す〜演出の繋ぎ目を確かめるにはこれが要る。
    /// 封は本番の関門なので、Debug ビルドの中だけに閉じてある
    static var autoCast: Bool { env["AUTO_CAST"] == "1" }
    #else
    static var letterReading: Bool { false }
    static var pulseTest: Bool { false }
    static var tremorTest: Bool { false }
    static var castAnimation: Bool { false }
    static var revealWithoutHolding: Bool { false }
    static var composeTest: Bool { false }
    static var pickUpAnimation: Bool { false }
    static var sentLetter: Bool { false }
    static var autoCast: Bool { false }
    static var shelf: Bool { false }
    #endif
}
