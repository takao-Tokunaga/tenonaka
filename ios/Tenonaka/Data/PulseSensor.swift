import AVFoundation
import CoreVideo
import Foundation

/// 背面カメラに指を当てて脈を測る(光電容積脈波 / PPG)。
///
/// 原理: ライトを点けた状態で指の腹をレンズに当てると、指を透過した光がセンサに届く。
/// 心臓が血を送るたびに毛細血管の血液量が増え、赤い光の吸収量が変わるので、
/// 画像の赤成分の平均が心拍に合わせて上下する。その波形から拍を拾う。
///
/// AI には脈が無い。生きていないものに当てても波形は出ない。
/// このアプリが身体を要求する、という一線がここにある。
/// 測定の状態。失敗しているときは何を直せばいいかまで持たせる。
/// 人に渡して数秒で当ててもらう必要があるので、「測れません」では足りない。
enum PulseQuality: Equatable {
    /// レンズが覆われていない
    case noFinger
    /// 隙間から光が漏れている(浅い・ずれている)
    case leaking
    /// 指を乗せた直後。落ち着くのを待っている
    case settling
    /// 波形が小さい。押しつけすぎて血流が止まっている
    case tooHard
    /// 拍がばらついている。動いている
    case unstable
    /// 光が足りない。ライトを使わないので明るい場所が要る
    case tooDark
    /// 取れている
    case good

    var guidance: String {
        switch self {
        case .noFinger: return "背面のレンズを指の腹で覆う"
        case .leaking: return "レンズ全体を隙間なく覆う"
        case .settling: return "そのまま動かさない"
        case .tooHard: return "力を抜いて、そっと触れるだけ"
        case .unstable: return "動かさずに待つ"
        case .tooDark: return "明るい場所で試す"
        case .good: return "取れている"
        }
    }
}

final class PulseSensor: NSObject, ObservableObject {
    // MARK: - 外に出す状態

    /// 直近の推定心拍数。まだ確からしくないときは nil
    @Published private(set) var bpm: Double?
    /// 測定の状態
    @Published private(set) var quality: PulseQuality = .noFinger
    /// 波形の振幅を DC で割ったもの。指の当て方の良さの目安
    @Published private(set) var perfusion: Double = 0
    /// 赤成分の平均。ライトを使わないときに光量が足りているかの目安
    @Published private(set) var brightness: Double = 0
    /// 指が当たっているか
    @Published private(set) var isFingerPresent = false
    /// 推定の確からしさ 0...1
    @Published private(set) var confidence: Double = 0
    /// 表示用の波形(-1...1 に正規化した直近ぶん)
    @Published private(set) var waveform: [Double] = []
    /// 拍を検出した瞬間に増えるカウンタ(トンという表示に使う)
    @Published private(set) var beatCount = 0
    @Published private(set) var isRunning = false
    @Published private(set) var failureText: String?

    // MARK: - 内部

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "dev.takao.namibin.pulse")
    private var device: AVCaptureDevice?

    /// 生の観測値(時刻と赤成分の平均)
    private var times: [Double] = []
    private var values: [Double] = []

    private var fingerSince: Double?
    private var didLockExposure = false
    private var lastPublishedBeatTime: Double?

    /// ライトを最初から使うか。既定は消灯。
    /// 消灯のほうが体験として静かだが、指を透過する光が環境光だけになるので
    /// 暗い場所では測れない。足りないときだけ自動で点ける(fallbackToTorch)。
    var usesTorch = false

    /// 光量不足でやむなくライトを点けたか
    @Published private(set) var didFallBackToTorch = false

    /// ライトの強さ。強すぎると飽和して波形が消え、弱すぎると光が届かない。
    /// 指の厚みは人によって違うので、実測の明るさを見て追い込む。
    private var torchLevel: Float = 0.25
    private var lastTorchAdjust: Double = 0
    /// 暗いまま何秒経ったか(ライトに切り替える判断に使う)
    private var darkSince: Double?
    private var torchIsOn = false
    /// 赤成分の平均をこの範囲に入れたい(ライトを使うときだけ)
    private let brightnessTarget: ClosedRange<Double> = 150...225
    /// これより暗いと脈波が埋もれる
    private let darkFloor: Double = 14

    /// 解析に使う窓の長さ。短いと安定せず、長いと反応が鈍る
    private let windowSeconds: Double = 8
    /// 拍の最短間隔(= 200bpm)。これ未満は同じ拍の揺れとして捨てる
    private let minInterval: Double = 0.30
    /// 拍の最長間隔(= 約37bpm)
    private let maxInterval: Double = 1.60

    // MARK: - 開始・停止

    func start() {
        guard !isRunning else { return }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.failureText = "カメラの使用が許可されていません"
                }
                return
            }
            self.queue.async { self.configureAndRun() }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.setTorch(on: false)
            self.unlockExposure()
            self.reset()
            DispatchQueue.main.async {
                self.isRunning = false
                self.bpm = nil
                self.confidence = 0
                self.isFingerPresent = false
                self.waveform = []
            }
        }
    }

    private func reset() {
        times.removeAll()
        values.removeAll()
        fingerSince = nil
        didLockExposure = false
        lastPublishedBeatTime = nil
        darkSince = nil
        torchLevel = 0.25
        DispatchQueue.main.async { self.didFallBackToTorch = false }
    }

    // MARK: - カメラ設定

    private func configureAndRun() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else {
            DispatchQueue.main.async { self.failureText = "背面カメラが見つかりません" }
            return
        }
        device = camera

        session.beginConfiguration()
        // 解像度は要らない。平均値しか使わないので軽いほうがいい
        session.sessionPreset = .low

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            DispatchQueue.main.async { self.failureText = "カメラを開けませんでした" }
            session.commitConfiguration()
            return
        }

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()

        configureDevice(camera)
        setTorch(on: usesTorch)

        session.startRunning()
        DispatchQueue.main.async {
            self.isRunning = true
            self.failureText = nil
        }
    }

    private func configureDevice(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            // 指はレンズに密着するのでピントは合わない。合わせようとする動きが
            // ノイズになるだけなので固定する
            if camera.isFocusModeSupported(.locked) { camera.focusMode = .locked }
            // フレームレートを固定して、時間軸のばらつきを減らす
            let duration = CMTime(value: 1, timescale: 30)
            if camera.activeFormat.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameDuration <= duration && duration <= $0.maxFrameDuration
            }) {
                camera.activeVideoMinFrameDuration = duration
                camera.activeVideoMaxFrameDuration = duration
            }
            camera.unlockForConfiguration()
        } catch {
            // 固定できなくても測れないわけではないので続行する
        }
    }

    private func setTorch(on: Bool) {
        guard let camera = device, camera.hasTorch else { return }
        do {
            try camera.lockForConfiguration()
            if on {
                try? camera.setTorchModeOn(level: torchLevel)
            } else {
                camera.torchMode = .off
            }
            camera.unlockForConfiguration()
            torchIsOn = on
        } catch {}
    }

    /// 露出が自動のままだと、血液量の変化を明るさ補正で打ち消してしまう。
    /// 指が乗って落ち着いたところで固定する。
    private func lockExposureIfNeeded() {
        guard !didLockExposure, let camera = device else { return }
        do {
            try camera.lockForConfiguration()
            if camera.isExposureModeSupported(.locked) { camera.exposureMode = .locked }
            if camera.isWhiteBalanceModeSupported(.locked) { camera.whiteBalanceMode = .locked }
            camera.unlockForConfiguration()
            didLockExposure = true
        } catch {}
    }

    private func unlockExposure() {
        guard didLockExposure, let camera = device else { return }
        do {
            try camera.lockForConfiguration()
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            camera.unlockForConfiguration()
        } catch {}
        didLockExposure = false
    }
}

// MARK: - フレームの処理

extension PulseSensor: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard let mean = averageColor(of: pixelBuffer) else { return }

        // 指がレンズを覆っていれば、光が血を通るので赤だけが強く残る。
        // 明るさの絶対値ではなく比率で見る。ライトを使わないと画像全体が暗くなるため。
        let redness = mean.red - max(mean.green, mean.blue)
        let rednessRatio = redness / max(mean.red, 1)
        let covered = rednessRatio > 0.45 && mean.red > 4
        // 覆っているが隙間から外光が漏れている状態
        let leaking = covered && rednessRatio < 0.6
        // 覆えてはいるが光量が足りない
        let tooDark = covered && mean.red < darkFloor

        if covered {
            if fingerSince == nil { fingerSince = time }
            // 乗せた直後は手ぶれで波形が荒れるので、落ち着いてから露出を固定する
            if let since = fingerSince, time - since > 0.8 { lockExposureIfNeeded() }
            fallBackToTorchIfTooDark(isDark: tooDark, now: time)
            if torchIsOn { adjustTorchIfNeeded(brightness: mean.red, now: time) }

            times.append(time)
            values.append(mean.red)
            trimWindow()
        } else {
            fingerSince = nil
            unlockExposure()
            times.removeAll()
            values.removeAll()
        }

        let settled = fingerSince.map { time - $0 > 1.6 } ?? false
        let analysis = covered ? analyse() : nil

        let state: PulseQuality
        if !covered {
            state = .noFinger
        } else if tooDark {
            state = .tooDark
        } else if leaking {
            state = .leaking
        } else if !settled {
            state = .settling
        } else if let analysis {
            if analysis.confidence >= 0.5 {
                state = .good
            } else if analysis.perfusion < 0.0015 {
                state = .tooHard
            } else {
                state = .unstable
            }
        } else {
            state = .settling
        }

        DispatchQueue.main.async {
            self.isFingerPresent = covered
            self.quality = state
            self.brightness = mean.red
            if let analysis {
                self.waveform = analysis.waveform
                self.confidence = analysis.confidence
                self.perfusion = analysis.perfusion
                self.bpm = analysis.confidence >= 0.5 ? analysis.bpm : nil
                if let last = analysis.lastBeatTime, last != self.lastPublishedBeatTime {
                    self.lastPublishedBeatTime = last
                    self.beatCount += 1
                }
            } else {
                self.waveform = []
                self.confidence = 0
                self.perfusion = 0
                self.bpm = nil
            }
        }
    }

    /// 環境光だけでは足りないと分かったら、やむなくライトを点ける。
    /// 消灯のまま測れないより、点いてでも測れるほうがましなので。
    private func fallBackToTorchIfTooDark(isDark: Bool, now: Double) {
        guard !torchIsOn else { return }
        guard isDark else {
            darkSince = nil
            return
        }
        if darkSince == nil { darkSince = now }
        guard let since = darkSince, now - since > 2.0 else { return }

        // ごく弱く点ける。眩しくない範囲から始めて、足りなければ自動で上げる
        torchLevel = 0.1
        setTorch(on: true)
        times.removeAll()
        values.removeAll()
        fingerSince = now
        darkSince = nil
        DispatchQueue.main.async { self.didFallBackToTorch = true }
    }

    /// 明るさが目標から外れていればライトを調整する。
    /// 変えた直後は波形が乱れるので、窓を捨ててやり直す。
    private func adjustTorchIfNeeded(brightness: Double, now: Double) {
        guard now - lastTorchAdjust > 0.7 else { return }
        guard !brightnessTarget.contains(brightness) else { return }

        let next: Float
        if brightness > brightnessTarget.upperBound {
            next = max(0.05, torchLevel - 0.08)
        } else {
            next = min(1.0, torchLevel + 0.08)
        }
        guard abs(next - torchLevel) > 0.001 else { return }

        torchLevel = next
        lastTorchAdjust = now
        setTorch(on: true)
        times.removeAll()
        values.removeAll()
        fingerSince = now
    }

    private func trimWindow() {
        guard let newest = times.last else { return }
        let cutoff = newest - windowSeconds
        var drop = 0
        while drop < times.count && times[drop] < cutoff { drop += 1 }
        if drop > 0 {
            times.removeFirst(drop)
            values.removeFirst(drop)
        }
    }

    /// ROI(中央付近)の色の平均。全画素見る必要はないので間引く。
    private func averageColor(of buffer: CVPixelBuffer) -> (red: Double, green: Double, blue: Double)? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)

        let x0 = width / 3, x1 = width * 2 / 3
        let y0 = height / 3, y1 = height * 2 / 3
        let step = 4

        var sumR = 0, sumG = 0, sumB = 0, count = 0
        var y = y0
        while y < y1 {
            let row = pointer + y * bytesPerRow
            var x = x0
            while x < x1 {
                let pixel = row + x * 4
                // BGRA
                sumB += Int(pixel[0])
                sumG += Int(pixel[1])
                sumR += Int(pixel[2])
                count += 1
                x += step
            }
            y += step
        }

        guard count > 0 else { return nil }
        return (
            red: Double(sumR) / Double(count),
            green: Double(sumG) / Double(count),
            blue: Double(sumB) / Double(count)
        )
    }

    private struct Analysis {
        var bpm: Double
        var confidence: Double
        var waveform: [Double]
        var lastBeatTime: Double?
        /// 脈波の振幅 ÷ 明るさ。押しつけすぎると血流が止まってこの値が落ちる
        var perfusion: Double
    }

    /// 窓のなかを毎回まるごと解析する。240点程度なので素直に計算して構わない。
    /// 状態を持ち越さないので、ずれが溜まらない。
    private func analyse() -> Analysis? {
        let count = values.count
        guard count > 45, let span = times.last.map({ $0 - times[0] }), span > 1.5 else {
            return nil
        }

        let rate = Double(count - 1) / span   // 実測のサンプリングレート

        // 1. ゆっくりした明るさの変動(指の圧力・手ぶれ)を引く = ハイパスフィルタ
        let slowWindow = max(3, Int(rate * 1.0))
        var detrended = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let from = max(0, i - slowWindow / 2)
            let to = min(count - 1, i + slowWindow / 2)
            var sum = 0.0
            for j in from...to { sum += values[j] }
            detrended[i] = values[i] - sum / Double(to - from + 1)
        }

        // 2. 細かいノイズを潰す = ローパスフィルタ
        let fastWindow = max(2, Int(rate * 0.10))
        var filtered = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let from = max(0, i - fastWindow / 2)
            let to = min(count - 1, i + fastWindow / 2)
            var sum = 0.0
            for j in from...to { sum += detrended[j] }
            filtered[i] = sum / Double(to - from + 1)
        }

        // 3. 振幅を明るさで割って、当て方の良さを測る。
        // 絶対値ではなく比で見るので、ライトの有無で画像の明るさが変わっても効く
        let rms = (filtered.reduce(0) { $0 + $1 * $1 } / Double(count)).squareRoot()
        let dc = values.reduce(0, +) / Double(count)
        let perfusion = dc > 1 ? rms / dc : 0
        // 波形がほぼ平坦なら脈ではなくノイズ。押しつけすぎの判定に使えるよう
        // nil ではなく perfusion を返して呼び出し側に判断させる
        guard perfusion > 0.0004 else {
            return Analysis(
                bpm: 0,
                confidence: 0,
                waveform: normalise(filtered),
                lastBeatTime: nil,
                perfusion: perfusion
            )
        }

        // 4. 山を拾う。閾値と不応期で重複を防ぐ
        let threshold = rms * 0.5
        var beats: [Double] = []
        for i in 1..<(count - 1) {
            guard filtered[i] > threshold,
                  filtered[i] >= filtered[i - 1],
                  filtered[i] > filtered[i + 1]
            else { continue }
            if let last = beats.last, times[i] - last < minInterval { continue }
            beats.append(times[i])
        }

        // 5. 拍間隔から心拍数。中央値なので外れ値に強い
        var intervals: [Double] = []
        for i in 1..<max(beats.count, 1) {
            let interval = beats[i] - beats[i - 1]
            if interval >= minInterval && interval <= maxInterval { intervals.append(interval) }
        }
        guard intervals.count >= 3 else {
            return Analysis(
                bpm: 0,
                confidence: 0,
                waveform: normalise(filtered),
                lastBeatTime: beats.last,
                perfusion: perfusion
            )
        }

        let sorted = intervals.sorted()
        let median = sorted[sorted.count / 2]
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let deviation = variance.squareRoot() / mean

        // 6. 間隔が揃っていれば確からしい。ばらけていれば信じない
        let steadiness = max(0, 1 - deviation / 0.25)
        let enough = min(1, Double(intervals.count) / 6)
        let confidence = min(1, steadiness * enough)

        return Analysis(
            bpm: 60 / median,
            confidence: confidence,
            waveform: normalise(filtered),
            lastBeatTime: beats.last,
            perfusion: perfusion
        )
    }

    /// 表示用に -1...1 へ収める
    private func normalise(_ source: [Double]) -> [Double] {
        let tail = source.suffix(160)
        guard let maxAbs = tail.map({ abs($0) }).max(), maxAbs > 0.0001 else {
            return Array(repeating: 0, count: tail.count)
        }
        return tail.map { $0 / maxAbs }
    }
}
