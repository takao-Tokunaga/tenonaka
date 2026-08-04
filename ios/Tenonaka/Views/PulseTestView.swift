import SwiftUI

/// 脈が実機で安定して取れるかを見るための検証画面。
/// 波形・心拍数・確からしさを生で出して、指の当て方やしきい値を詰めるために使う。
struct PulseTestView: View {
    @StateObject private var sensor = PulseSensor()

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("脈の検証")
                    .font(Mincho.font(18, bold: true))
                    .kerning(3)
                    .foregroundStyle(Paper.ink)

                // 状態に応じた指示。これが的確なら、人に渡しても当てられる
                Text(sensor.quality.guidance)
                    .font(Mincho.font(16))
                    .foregroundStyle(sensor.quality == .good ? Paper.inkSoft : Paper.ribbon)
                    .animation(.easeOut(duration: 0.2), value: sensor.quality)

                // 波形
                WaveformView(samples: sensor.waveform)
                    .frame(height: 130)
                    .background {
                        Rectangle().fill(Paper.base.opacity(0.5))
                    }
                    .overlay {
                        Rectangle().stroke(Paper.rule.opacity(0.7), lineWidth: 0.6)
                    }

                // 数値
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    if let bpm = sensor.bpm {
                        Text("\(Int(bpm.rounded()))")
                            .font(Mincho.font(56, bold: true))
                            .foregroundStyle(Paper.ink)
                        Text("拍/分")
                            .font(Mincho.font(14))
                            .foregroundStyle(Paper.inkSoft)
                    } else {
                        Text(sensor.isFingerPresent ? "測っている" : "指を当てる")
                            .font(Mincho.font(24))
                            .foregroundStyle(Paper.inkFaint)
                    }

                    Spacer()

                    // 拍のたびに脈打つ点
                    Circle()
                        .fill(Paper.ribbon)
                        .frame(width: 16, height: 16)
                        .scaleEffect(1.0)
                        .opacity(sensor.bpm == nil ? 0.25 : 1)
                        .animation(.easeOut(duration: 0.18), value: sensor.beatCount)
                        .id(sensor.beatCount)
                        .transition(.scale)
                }

                VStack(alignment: .leading, spacing: 7) {
                    row("指の検出", sensor.isFingerPresent ? "あり" : "なし")
                    row("確からしさ", String(format: "%.2f", sensor.confidence))
                    row("脈波の強さ", String(format: "%.4f", sensor.perfusion))
                    row("明るさ(赤)", String(format: "%.1f", sensor.brightness))
                    row("カメラ", sensor.isRunning ? "動作中" : "停止")
                    if let failure = sensor.failureText {
                        row("エラー", failure)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
        }
        .onAppear { sensor.start() }
        .onDisappear { sensor.stop() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Mincho.font(12.5))
                .foregroundStyle(Paper.inkFaint)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Paper.inkSoft)
        }
    }
}

/// 脈波の折れ線。
struct WaveformView: View {
    let samples: [Double]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard samples.count > 1 else { return }
                let stepX = geometry.size.width / CGFloat(samples.count - 1)
                let midY = geometry.size.height / 2
                let amplitude = geometry.size.height / 2 * 0.85

                for (index, value) in samples.enumerated() {
                    let point = CGPoint(
                        x: CGFloat(index) * stepX,
                        y: midY - CGFloat(value) * amplitude
                    )
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(Paper.ribbon.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
    }
}
