import SwiftUI

/// バックエンドの接続先を変える画面。
/// 会場の Wi-Fi で Mac の IP が変わってもアプリを作り直さずに直せるように置いている。
/// 世界観を邪魔しないよう、日付の長押しからだけ開ける。
struct ConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LetterStore

    @State private var text: String = AppConfig.apiBaseURLText
    @State private var isChecking = false
    @State private var result: String?

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("接続先")
                        .font(Mincho.font(16, bold: true))
                        .kerning(2)
                        .foregroundStyle(Paper.ink)
                    Spacer()
                    Button("とじる") { dismiss() }
                        .font(Mincho.font(13.5))
                        .foregroundStyle(Paper.inkFaint)
                        .buttonStyle(.plain)
                }

                TextField(AppConfig.fallbackBaseURL, text: $text)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(Paper.ink)
                    .tint(Paper.ribbon)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Paper.rule.opacity(0.8), lineWidth: 0.6)
                    }

                Text("実機の場合は、同じ Wi-Fi 上の Mac の IP を指定する。\nビルド時の既定値は \(AppConfig.bundledBaseURLText)")
                    .font(Mincho.font(12))
                    .lineSpacing(5)
                    .foregroundStyle(Paper.inkFaint)

                HStack(spacing: 18) {
                    Button {
                        AppConfig.setAPIBaseURL(text)
                        Task {
                            isChecking = true
                            result = nil
                            let reachable = await store.reload()
                            isChecking = false
                            result = reachable ? "つながった" : "つながらない"
                        }
                    } label: {
                        Text("つなぐ")
                            .font(Mincho.font(14, bold: true))
                            .foregroundStyle(Paper.ribbon)
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking)

                    if AppConfig.hasOverride {
                        Button {
                            AppConfig.setAPIBaseURL("")
                            text = AppConfig.apiBaseURLText
                            result = nil
                        } label: {
                            Text("既定に戻す")
                                .font(Mincho.font(13))
                                .foregroundStyle(Paper.inkSoft)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if isChecking {
                        Text("確認中")
                            .font(Mincho.font(12))
                            .foregroundStyle(Paper.inkFaint)
                    } else if let result {
                        Text(result)
                            .font(Mincho.font(12.5))
                            .foregroundStyle(
                                result == "つながった" ? Paper.inkSoft : Paper.ribbon
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
        }
    }
}
