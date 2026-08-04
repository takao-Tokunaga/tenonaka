import SwiftUI

/// 微動の判定が実用になるかを見るための検証画面。
/// 「握る / 置く / 机に構える / 歩く」で数値がどう分かれるかを確かめる。
struct TremorTestView: View {
    @StateObject private var sensor = TremorSensor()
    @State private var threshold: Double = 0.0015
    @State private var samples: [String: Double] = [:]

    var body: some View {
        ZStack {
            PaperSurface(showsRules: false)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("微動の検証")
                    .font(Mincho.font(18, bold: true))
                    .kerning(3)
                    .foregroundStyle(Paper.ink)

                // 判定
                HStack(spacing: 12) {
                    Circle()
                        .fill(sensor.isHeld ? Paper.ribbon : Paper.inkFaint.opacity(0.3))
                        .frame(width: 14, height: 14)
                    Text(sensor.isHeld ? "握られている" : "置かれている")
                        .font(Mincho.font(24, bold: true))
                        .foregroundStyle(sensor.isHeld ? Paper.ink : Paper.inkFaint)
                }
                .animation(.easeOut(duration: 0.15), value: sensor.isHeld)

                // 数値と棒
                VStack(spacing: 12) {
                    meter("微動 加速度 8-12Hz", sensor.tremorAccel, scale: 0.006)
                    meter("微動 ジャイロ 8-12Hz", sensor.tremorGyro, scale: 0.03)
                    meter("粗い動き 0.5-3Hz", sensor.grossMotion, scale: 0.05)
                }

                // しきい値をその場で動かせるようにする
                VStack(alignment: .leading, spacing: 6) {
                    Text("しきい値 " + String(format: "%.5f", threshold))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Paper.inkSoft)
                    Slider(value: $threshold, in: 0.0002...0.006)
                        .tint(Paper.ribbon)
                        .onChange(of: threshold) { _, value in
                            sensor.threshold = value
                        }
                }

                Divider().overlay(Paper.rule)

                // 条件ごとの実測値を控えておく
                Text("いまの値を記録")
                    .font(Mincho.font(13))
                    .foregroundStyle(Paper.inkSoft)

                HStack(spacing: 8) {
                    ForEach(["握る", "置く", "机に構える", "歩く"], id: \.self) { label in
                        Button(label) {
                            samples[label] = max(sensor.tremorAccel, sensor.tremorGyro * 0.2)
                        }
                        .font(Mincho.font(12))
                        .foregroundStyle(Paper.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background {
                            Capsule().stroke(Paper.rule, lineWidth: 0.6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(["握る", "置く", "机に構える", "歩く"], id: \.self) { label in
                        if let value = samples[label] {
                            HStack {
                                Text(label)
                                    .font(Mincho.font(12.5))
                                    .foregroundStyle(Paper.inkSoft)
                                Spacer()
                                Text(String(format: "%.5f", value))
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .foregroundStyle(Paper.ink)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .onAppear {
            sensor.threshold = threshold
            sensor.start()
        }
        .onDisappear { sensor.stop() }
    }

    private func meter(_ label: String, _ value: Double, scale: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Mincho.font(11.5))
                    .foregroundStyle(Paper.inkFaint)
                Spacer()
                Text(String(format: "%.5f", value))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Paper.inkSoft)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Paper.rule.opacity(0.25))
                    Rectangle()
                        .fill(Paper.ribbon.opacity(0.75))
                        .frame(width: min(1, value / scale) * geometry.size.width)
                }
            }
            .frame(height: 7)
        }
    }
}
