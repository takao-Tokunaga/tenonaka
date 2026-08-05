import AVFoundation

/// 波の音。
///
/// 録音(`Resources/sea.m4a`)を繰り返し鳴らす。無ければその場で作った音に落ちる。
///
/// 落とし所を持たせているのは、**音は世界の一部だが、無くても機構は成立する**から。
/// 素材が入っていないビルドで無音になるより、雑音でも海が鳴っているほうがいい。
///
/// 合成のほうは、白色雑音を低い側へ寄せ、波一発ぶんの包絡で撫でている。
/// 音量を正弦で上下させただけでは「うねる雑音」にしかならないので、
/// **急に立ち上がってゆっくり引く**一発を不規則な間隔で重ねている。
@MainActor
final class SeaSound {
    static let shared = SeaSound()

    /// 録音の名前。ここに置けば録音が優先される
    private static let fileName = "sea"
    private static let fileTypes = ["m4a", "caf", "mp3", "wav"]

    private var player: AVAudioPlayer?
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var isPrepared = false
    /// 合成側の目標音量。音声スレッドがここへ滑らかに近づく
    private let target = Gain()

    /// 音量。控えめにする。世界の気配であって主役ではない
    private let volume: Float = 0.42

    private init() {}

    func start() {
        prepare()

        if let player {
            guard !player.isPlaying else { return }
            player.volume = 0
            player.play()
            // いきなり鳴り出すと驚くので、少し掛けて上げる
            player.setVolume(volume, fadeDuration: 1.6)
            return
        }

        target.value = volume
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    /// 止める。無音にしてから止める(いきなり切ると鳴り際が跳ねる)
    func stop() {
        if let player {
            player.setVolume(0, fadeDuration: 0.35)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak player] in
                guard let player, player.volume == 0 else { return }
                player.pause()
            }
            return
        }

        target.value = 0
        guard engine.isRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.target.value == 0 else { return }
            self.engine.pause()
        }
    }

    // MARK: - 組み立て

    private func prepare() {
        guard !isPrepared else { return }
        isPrepared = true

        // .ambient にしておくと、消音スイッチが効き、他のアプリの音も止めない。
        // 環境音として鳴らすので、利用者の消音を上書きしてはいけない
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        if let url = Self.recordingURL() {
            player = try? AVAudioPlayer(contentsOf: url)
            // -1 で終わりなく繰り返す
            player?.numberOfLoops = -1
            player?.prepareToPlay()
        }
        guard player == nil else { return }

        prepareSynthesized()
    }

    /// 同梱された録音を探す
    private static func recordingURL() -> URL? {
        for type in fileTypes {
            if let url = Bundle.main.url(forResource: fileName, withExtension: type) {
                return url
            }
        }
        return nil
    }

    private func prepareSynthesized() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else {
            return
        }
        let node = AVAudioSourceNode(format: format, renderBlock: Self.renderBlock(
            sampleRate: format.sampleRate,
            gain: target
        ))
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    /// 波一発ぶんの状態。
    ///
    /// 雑音の音量を正弦で上下させると「うねる雑音」にしかならない。
    /// 波に聞こえるかどうかは、**急に立ち上がってゆっくり引く**一発の形と、
    /// その一発が不規則な間隔で重なることで決まる。
    private struct Wave {
        /// 進み具合 0〜1
        var progress: Float
        /// 一発の長さ(サンプル数)
        var length: Float
        var amplitude: Float
        /// 立ち上がりが占める割合。小さいほど鋭く砕ける
        var attack: Float
        /// 次の波までの残り(サンプル数)。0 なら鳴っている
        var rest: Float
    }

    /// 音声スレッドで回る。
    ///
    /// ここでは確保も鍵取りもしない。状態はすべて閉包が捕まえた変数に持つ。
    /// 乱数も `Double.random` を使わない(内部で鍵を取りうる)。xorshift で自分で回す。
    private static func renderBlock(
        sampleRate: Double,
        gain: Gain
    ) -> AVAudioSourceNodeRenderBlock {
        var seed: UInt32 = 0x9E37_79B9

        func noise() -> Float {
            // xorshift32。確保も鍵取りもしない
            seed ^= seed << 13
            seed ^= seed >> 17
            seed ^= seed << 5
            return Float(Int32(bitPattern: seed)) / Float(Int32.max)
        }

        /// 0〜1 の疑似乱数
        func unit() -> Float { (noise() + 1) * 0.5 }

        let rate = Float(sampleRate)

        /// 波を組み直す。長さも間隔も散らす。
        /// 一定にすると同じ波が時計のように来て、機械の音だと分かってしまう
        func rearm(_ wave: inout Wave, waiting: Bool) {
            wave.progress = 0
            wave.length = rate * (2.6 + unit() * 3.6)      // 2.6〜6.2秒
            wave.amplitude = 0.45 + unit() * 0.55
            wave.attack = 0.10 + unit() * 0.13             // 立ち上がりは全体の1〜2割
            wave.rest = waiting ? rate * (0.2 + unit() * 2.6) : 0
        }

        // 3本を重ねる。1本だと波の合間が無音になり、多いと雑音に戻る
        var waves = [Wave](repeating: Wave(progress: 0, length: rate * 4, amplitude: 0.7,
                                          attack: 0.15, rest: 0), count: 3)
        for index in waves.indices {
            rearm(&waves[index], waiting: true)
            // 出だしから重ならないよう、初めだけ位相をずらす
            waves[index].rest = rate * Float(index) * 1.7
        }

        // 濾波器の状態。左右で別に持って幅を出す
        var rumble: Float = 0
        var foamLeft: Float = 0
        var foamRight: Float = 0
        var level: Float = 0

        /// 底に薄く敷く低い唸り。波の合間を埋める
        let rumbleCoefficient: Float = 0.9915
        let followStep: Float = Float(1.0 / sampleRate)

        return { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let wanted = gain.value

            for frame in 0..<Int(frameCount) {
                // 波の包絡を合算する
                var envelope: Float = 0
                for index in waves.indices {
                    if waves[index].rest > 0 {
                        waves[index].rest -= 1
                        continue
                    }
                    waves[index].progress += 1 / waves[index].length
                    if waves[index].progress >= 1 {
                        rearm(&waves[index], waiting: true)
                        continue
                    }

                    let progress = waves[index].progress
                    let attack = waves[index].attack
                    let shape: Float
                    if progress < attack {
                        // 砕けるまで。少し溜めてから一気に上がる
                        let rise = progress / attack
                        shape = rise * rise * (3 - 2 * rise)
                    } else {
                        // 引いていく。指数で長く尾を引かせる
                        let fall = (progress - attack) / (1 - attack)
                        shape = exp(-3.4 * fall)
                    }
                    envelope += shape * waves[index].amplitude
                }
                envelope = min(envelope, 1.6)

                // 目標音量へ滑らかに寄せる(いきなり切ると鳴り際が跳ねる)
                if level < wanted {
                    level = min(wanted, level + followStep)
                } else if level > wanted {
                    level = max(wanted, level - followStep)
                }

                // 泡の明るさを包絡に従わせる。
                // 砕ける瞬間は高い成分が出て、引くにつれて暗くなる。
                // これが無いと、音量だけ動く雑音に聞こえる
                let foamCoefficient = 0.94 - 0.40 * min(envelope, 1)

                let whiteLeft = noise()
                let whiteRight = noise()
                rumble = rumble * rumbleCoefficient + whiteLeft * (1 - rumbleCoefficient)
                foamLeft = foamLeft * foamCoefficient + whiteLeft * (1 - foamCoefficient)
                foamRight = foamRight * foamCoefficient + whiteRight * (1 - foamCoefficient)

                // 底の唸りは常に、泡は波が来たときだけ。
                // 倍率は割れない範囲で決めた(以前は最大1.157で振り切っていた)
                let bed = rumble * 4.5 * (0.5 + 0.5 * min(envelope, 1))
                let left = (bed + foamLeft * 0.9 * envelope) * level
                let right = (bed + foamRight * 0.9 * envelope) * level

                var channel = 0
                for buffer in buffers {
                    let samples = buffer.mData!.assumingMemoryBound(to: Float.self)
                    samples[frame] = channel == 0 ? left : right
                    channel += 1
                }
            }
            return noErr
        }
    }
}

/// 音声スレッドと主スレッドで受け渡す音量。
/// クラスにして参照で共有する(値型を閉包に捕まえると写しが渡ってしまう)
final class Gain {
    var value: Float = 0
}
