import Foundation

/// ハッカソン用の最小設定。
///
/// 接続先の決まり方(上から優先):
///   1. アプリ内で設定した値(UserDefaults) — 会場で IP が変わったとき用
///   2. Info.plist の TenonakaAPIBaseURL(ビルド設定 NIOI_API_BASE_URL から流し込む)
///   3. http://localhost:3100
///
/// シミュレータは localhost で Mac のサーバーに届く。実機の場合は同一 Wi-Fi 上の
/// Mac の IP(例 http://192.168.0.5:3100)を指す必要がある。
enum AppConfig {
    private static let overrideKey = "apiBaseURL"
    static let fallbackBaseURL = "http://localhost:3100"

    /// ビルド時に埋め込まれた接続先(本番)
    static var bundledBaseURLText: String {
        infoPlistURL(forKey: "TenonakaAPIBaseURL") ?? fallbackBaseURL
    }

    /// ビルド時に埋め込まれた手元のサーバー。
    /// デプロイせずに動作確認するための逃げ道。埋め込まれていなければ nil
    static var localBaseURLText: String? {
        infoPlistURL(forKey: "TenonakaLocalAPIBaseURL")
    }

    private static func infoPlistURL(forKey key: String) -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        guard let value, !value.isEmpty, value.hasPrefix("http") else { return nil }
        return value
    }

    static var apiBaseURLText: String {
        UserDefaults.standard.string(forKey: overrideKey) ?? bundledBaseURLText
    }

    static var apiBaseURL: URL {
        URL(string: apiBaseURLText) ?? URL(string: fallbackBaseURL)!
    }

    /// 接続先を上書きする。空文字を渡すとビルド時の値に戻る。
    static func setAPIBaseURL(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: overrideKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: overrideKey)
        }
    }

    static var hasOverride: Bool {
        UserDefaults.standard.string(forKey: overrideKey) != nil
    }

    /// 認証は簡易実装。x-user-id ヘッダとして送る ID。
    ///
    /// 端末ごとに一度だけ発行して保存する。公開したサーバーでは固定値にすると
    /// 全員の「送った便り」が混ざってしまうため。
    static var userId: String {
        let key = "userId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
