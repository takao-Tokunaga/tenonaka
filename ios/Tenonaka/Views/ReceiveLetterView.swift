import SwiftUI

/// 符号を入れて手紙を受け取る画面。
struct ReceiveLetterView: View {
    @EnvironmentObject private var store: LetterStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isFetching = false
    @State private var failureText: String?
    @State private var letter: Letter?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                VStack(spacing: 24) {
                    Text("教わった符号を入れてください")
                        .font(Mincho.font(14))
                        .foregroundStyle(Paper.inkSoft)

                    TextField("", text: $code)
                        // 10文字の符号が入るので、長さに応じて字を詰める
                        .font(.system(
                            size: code.count > 8 ? 27 : 38,
                            weight: .semibold,
                            design: .serif
                        ))
                        .kerning(code.count > 8 ? 3 : 8)
                        .multilineTextAlignment(.center)
                        .animation(.easeOut(duration: 0.15), value: code.count > 8)
                        .foregroundStyle(Paper.ink)
                        .tint(Paper.ribbon)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .onChange(of: code) { _, value in
                            // 符号は英字のみ。自動発行は10文字で、指定符号は最大12文字
                            code = String(
                                value.uppercased().filter { $0.isLetter }.prefix(12)
                            )
                        }
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Paper.rule.opacity(0.8))
                                .frame(height: 0.8)
                        }
                        .padding(.horizontal, 50)

                    if let failureText {
                        Text(failureText)
                            .font(Mincho.font(12.5))
                            .foregroundStyle(Paper.ribbon)
                    }

                    Button {
                        Task { await fetch() }
                    } label: {
                        Text(isFetching ? "探している" : "受け取る")
                            .font(Mincho.font(15, bold: true))
                            .foregroundStyle(Paper.base)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 13)
                            .background {
                                Capsule().fill(
                                    code.count >= 5
                                        ? Paper.ink.opacity(0.88)
                                        : Paper.inkFaint.opacity(0.4)
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(code.count < 5 || isFetching)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .onAppear { isFocused = true }
        .fullScreenCover(item: $letter) { letter in
            LetterReadingView(letter: letter) { receipt in
                Task { await store.submitReceipt(code: letter.code, receipt: receipt) }
            }
        }
    }

    private var header: some View {
        HStack {
            Button("やめる") { dismiss() }
                .font(Mincho.font(13.5))
                .foregroundStyle(Paper.inkFaint)
                .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 24)
    }

    private func fetch() async {
        isFetching = true
        failureText = nil
        isFocused = false
        do {
            letter = try await store.fetch(code: code)
        } catch {
            failureText = error.localizedDescription
        }
        isFetching = false
    }
}
