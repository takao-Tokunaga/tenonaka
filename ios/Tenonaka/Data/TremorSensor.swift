import CoreMotion
import Foundation

/// 生きた手に握られているかを、手の微動から判定する。
///
/// 原理: 人間の手には常に 8〜12Hz の生理的微動がある。運動単位の発火に由来する
/// 不随意なもので、止めようとしても止まらない。机に置いた端末には存在しない。
///
/// 推論もモデルも使わない。加速度と角速度の、その帯域のエネルギーを見るだけ。
final class TremorSensor: NSObject, ObservableObject {
    /// 8〜12Hz の強さ(加速度)
    @Published private(set) var tremorAccel: Double = 0
    /// 8〜12Hz の強さ(角速度)。手の震えは回転成分に強く出ることがある
    @Published private(set) var tremorGyro: Double = 0
    /// 0.5〜3Hz の強さ。歩行や身振りなどの粗い動き
    @Published private(set) var grossMotion: Double = 0
    /// 握られていると判定しているか
    @Published private(set) var isHeld = false
    @Published private(set) var isAvailable = true

    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    private var accelBuffer: [Double] = []
    private var gyroBuffer: [Double] = []
    private var sinceUnheld: Date?

    /// 100Hz で回す。8〜12Hz を見るには十分に余裕がある
    private let sampleRate: Double = 100
    /// 解析の窓。1秒あれば 8Hz でも8周期入る
    private let windowSize = 100
    /// 何サンプルごとに判定するか
    private let hopSize = 10

    /// 握っていると見なすしきい値。
    /// iPhone 15 での実測: 握る 0.00352 / 机に構える 0.00184 / 置く 0.00015 / 歩く 0.02512。
    /// 「置く」の5倍上、「机に構える」の2倍下に置いて、両側に余裕を持たせている。
    var threshold: Double = 0.0008
    /// 離してから止めるまでの猶予。読書中の一瞬の取りこぼしで止めないため
    var releaseDelay: TimeInterval = 3.0

    func start() {
        guard motion.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }
        queue.maxConcurrentOperationCount = 1
        motion.deviceMotionUpdateInterval = 1 / sampleRate
        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.consume(data)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        accelBuffer.removeAll()
        gyroBuffer.removeAll()
        sinceUnheld = nil
        DispatchQueue.main.async {
            self.isHeld = false
            self.tremorAccel = 0
            self.tremorGyro = 0
            self.grossMotion = 0
        }
    }

    private func consume(_ data: CMDeviceMotion) {
        // 重力を除いた加速度の大きさ。向きを問わず震えを拾える
        let accel = data.userAcceleration
        let gyro = data.rotationRate
        accelBuffer.append(
            (accel.x * accel.x + accel.y * accel.y + accel.z * accel.z).squareRoot()
        )
        gyroBuffer.append(
            (gyro.x * gyro.x + gyro.y * gyro.y + gyro.z * gyro.z).squareRoot()
        )

        guard accelBuffer.count >= windowSize else { return }

        let accelWindow = Array(accelBuffer.suffix(windowSize))
        let gyroWindow = Array(gyroBuffer.suffix(windowSize))

        // 窓が溜まったぶんだけ捨てる
        if accelBuffer.count > windowSize {
            accelBuffer.removeFirst(accelBuffer.count - windowSize)
            gyroBuffer.removeFirst(gyroBuffer.count - windowSize)
        }
        guard accelBuffer.count % hopSize == 0 else { return }

        let tremorA = bandEnergy(accelWindow, from: 8, to: 12)
        let tremorG = bandEnergy(gyroWindow, from: 8, to: 12)
        let gross = bandEnergy(accelWindow, from: 0.5, to: 3)

        // 加速度と角速度のどちらかが出ていれば握っていると見る
        let signal = max(tremorA, tremorG * 0.2)
        let now = Date()
        let held: Bool

        if signal > threshold {
            sinceUnheld = nil
            held = true
        } else {
            if sinceUnheld == nil { sinceUnheld = now }
            // 掴み直す一瞬で止めないよう、離す判定だけ遅らせる
            held = now.timeIntervalSince(sinceUnheld ?? now) < releaseDelay
        }

        DispatchQueue.main.async {
            self.tremorAccel = tremorA
            self.tremorGyro = tremorG
            self.grossMotion = gross
            self.isHeld = held
        }
    }

    /// 指定した帯域のエネルギー。1Hz刻みで Goertzel をかけて二乗和を取る。
    /// FFT を持ち出すほどの帯域数ではないので、必要な周波数だけ直接計算する。
    private func bandEnergy(_ samples: [Double], from low: Double, to high: Double) -> Double {
        let count = samples.count
        guard count > 8 else { return 0 }

        // 直流成分を抜いて、ハン窓をかけて漏れを抑える
        let mean = samples.reduce(0, +) / Double(count)
        var windowed = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let hann = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(count - 1))
            windowed[i] = (samples[i] - mean) * hann
        }

        var power = 0.0
        var frequency = low
        while frequency <= high {
            let magnitude = goertzel(windowed, frequency: frequency)
            power += magnitude * magnitude
            frequency += 1
        }
        return power.squareRoot()
    }

    /// 単一周波数の振幅。FFT のうち欲しい1本だけを取り出す古典的な手法。
    private func goertzel(_ samples: [Double], frequency: Double) -> Double {
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
        var s1 = 0.0
        var s2 = 0.0
        for value in samples {
            let s0 = value + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        let power = s1 * s1 + s2 * s2 - coefficient * s1 * s2
        return (max(0, power)).squareRoot() * 2 / Double(samples.count)
    }
}
