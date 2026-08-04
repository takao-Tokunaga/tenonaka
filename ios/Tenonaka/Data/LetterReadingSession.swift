import Foundation
import SwiftUI

/// 手紙を読んでいる最中の状態。
///
/// 握られている間だけインクが現れる。置くと止まる。飛ばせない。
/// まだ現れていない文字は描画もされないので、先を覗くことも、
/// スクリーンショットで先取りすることもできない。
@MainActor
final class LetterReadingSession: ObservableObject {
    /// 現れている文字数
    @Published private(set) var revealedCount = 0
    @Published private(set) var isHeld = false
    /// 生きた手が握っていた合計秒数
    @Published private(set) var heldSeconds: Double = 0
    /// 途中で置かれた回数
    @Published private(set) var releaseCount = 0
    /// 最後まで現れたか
    @Published private(set) var isFinished = false
    /// 置かれてから少し経ったか(案内を出すかどうかの判断に使う)
    @Published private(set) var isPausedVisibly = false

    let letter: Letter
    private let characters: [Character]
    private let tremor = TremorSensor()

    /// 現れる速さ。日本語の黙読は毎秒8〜12文字あたり
    private let charactersPerSecond: Double = 10
    /// 置かれてから案内を出すまでの間
    private let pauseNoticeDelay: Double = 1.2

    private var progress: Double = 0
    private var ticker: Task<Void, Never>?
    private var unheldSince: Date?

    init(letter: Letter) {
        self.letter = letter
        self.characters = Array(letter.body)
    }

    var revealedText: String {
        String(characters.prefix(revealedCount))
    }

    /// 進み具合。長さそのものは読み手に見せないが、内部では持っている
    var fraction: Double {
        guard !characters.isEmpty else { return 1 }
        return Double(revealedCount) / Double(characters.count)
    }

    /// 流した人に返す記録。読み終えて封をしていれば、自分の脈も添える
    func receipt(readerBpm: Double?) -> ReadReceipt {
        ReadReceipt(
            heldSeconds: heldSeconds,
            releaseCount: releaseCount,
            completed: isFinished,
            readerBpm: readerBpm,
            readAt: Date()
        )
    }

    func start() {
        guard ticker == nil else { return }
        tremor.start()
        // まだ一度も握られていない状態から数えはじめる。
        // 握ってから離したときだけ案内を出す作りだと、
        // 開いた直後は何をすればいいか分からないまま白紙が続いてしまう
        unheldSince = Date()

        ticker = Task { @MainActor [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self else { return }

                let now = Date()
                let elapsed = now.timeIntervalSince(last)
                last = now

                // 検証時は握らなくても進める(シミュレータに加速度センサーが無いため)
                let held = self.tremor.isHeld || DebugFlags.revealWithoutHolding
                if held != self.isHeld {
                    // 握っていた状態から離れたときだけ数える
                    if !held { self.releaseCount += 1 }
                    self.isHeld = held
                    self.unheldSince = held ? nil : now
                    if held { self.isPausedVisibly = false }
                }

                if !held {
                    if let since = self.unheldSince,
                       now.timeIntervalSince(since) > self.pauseNoticeDelay {
                        self.isPausedVisibly = true
                    }
                    continue
                }

                guard !self.isFinished else { continue }

                self.heldSeconds += elapsed
                self.progress += elapsed * self.charactersPerSecond
                self.revealedCount = min(self.characters.count, Int(self.progress))
                if self.revealedCount >= self.characters.count {
                    self.isFinished = true
                }
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        tremor.stop()
    }
}
