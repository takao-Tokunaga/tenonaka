import SwiftUI

/// 脈で封をする画面。
///
/// ここがこのアプリの関門。脈が取れないと手紙は送れない。
/// 生きた身体がこの瞬間にここに居たことが、封として手紙に刻まれる。
struct SealSheet: View {
    let onSealed: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var sensor = PulseSensor()

    /// 良い状態が続いた秒数。ぶれた一瞬で確定させないため
    @State private var steadySeconds: Double = 0
    @State private var sealedBpm: Double?

    /// この秒数だけ安定したら封をする
    private let requiredSteady: Double = 2.0

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                if let sealedBpm {
                    sealed(bpm: sealedBpm)
                } else {
                    measuring
                }

                Spacer()

                Text("この封は、生きた身体でしか押せません。")
                    .font(Mincho.font(11.5))
                    .foregroundStyle(Paper.inkFaint)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 30)
        }
        .onAppear { sensor.start() }
        .onDisappear { sensor.stop() }
        .task {
            // 良い状態が続いた時間を数える。ぶれたら振り出しに戻す
            let step = 0.25
            while sealedBpm == nil && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard sensor.quality == .good, let bpm = sensor.bpm else {
                    steadySeconds = 0
                    continue
                }
                steadySeconds += step
                if steadySeconds >= requiredSteady {
                    withAnimation(.easeOut(duration: 0.4)) { sealedBpm = bpm }
                    sensor.stop()
                }
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

            Text("封をする")
                .font(Mincho.font(15, bold: true))
                .kerning(3)
                .foregroundStyle(Paper.ink)

            Spacer()

            // 左のボタンと釣り合わせるための余白
            Text("やめる")
                .font(Mincho.font(13.5))
                .foregroundStyle(.clear)
        }
        .padding(.top, 24)
    }

    // MARK: - 測っている間

    private var measuring: some View {
        VStack(spacing: 30) {
            WaveformView(samples: sensor.waveform)
                .frame(height: 110)

            VStack(spacing: 12) {
                if let bpm = sensor.bpm {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(Int(bpm.rounded()))")
                            .font(Mincho.font(52, bold: true))
                            .foregroundStyle(Paper.ink)
                        Text("拍/分")
                            .font(Mincho.font(13))
                            .foregroundStyle(Paper.inkSoft)
                    }
                } else {
                    Text("——")
                        .font(Mincho.font(44))
                        .foregroundStyle(Paper.inkFaint.opacity(0.5))
                }

                Text(sensor.quality.guidance)
                    .font(Mincho.font(15))
                    .foregroundStyle(sensor.quality == .good ? Paper.inkSoft : Paper.ribbon)
                    .animation(.easeOut(duration: 0.2), value: sensor.quality)

                if let failure = sensor.failureText {
                    Text(failure)
                        .font(Mincho.font(12))
                        .foregroundStyle(Paper.ribbon)
                }
            }

            // 封が押されるまでの進み具合
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Paper.rule.opacity(0.3))
                    Rectangle()
                        .fill(Paper.ribbon.opacity(0.7))
                        .frame(
                            width: min(1, steadySeconds / requiredSteady) * geometry.size.width
                        )
                        .animation(.linear(duration: 0.4), value: steadySeconds)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - 封が押されたあと

    private func sealed(bpm: Double) -> some View {
        VStack(spacing: 26) {
            // 封蝋のかわりの朱印
            ZStack {
                Circle()
                    .fill(Paper.ribbon.opacity(0.92))
                    .frame(width: 92, height: 92)
                VStack(spacing: 0) {
                    Text("\(Int(bpm.rounded()))")
                        .font(Mincho.font(34, bold: true))
                    Text("拍")
                        .font(Mincho.font(12))
                }
                .foregroundStyle(Paper.base)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Text("封をしました")
                .font(Mincho.font(17))
                .foregroundStyle(Paper.ink)

            Button {
                onSealed(bpm)
                dismiss()
            } label: {
                Text("この封で送る")
                    .font(Mincho.font(15, bold: true))
                    .foregroundStyle(Paper.base)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .background {
                        Capsule().fill(Paper.ink.opacity(0.88))
                    }
            }
            .buttonStyle(.plain)
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}
