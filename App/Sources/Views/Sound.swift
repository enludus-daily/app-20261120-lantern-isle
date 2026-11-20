import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 島の昼と夜：拾うと貝の鳴る音、作ると木づち、届けると鈴、夜はもやがはじける音、夜明けは和音。
/// 消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap, pick, bonus, build, deliver, short, dusk, hurt, pop, bell, shade, levelUp, dawn, fall
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階（五十音マインスイーパーの段階にならう：触る 0.4・開く 0.6・当たり 0.8）
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap, .pop: 0.4
        case .pick, .dusk, .bell: 0.6
        case .short, .hurt, .shade: 0.7
        case .bonus, .build, .deliver, .levelUp, .dawn, .fall: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    // MARK: - 音を作る

    private struct Partial {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var sweepTo: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            // 小さな木のコツッ
            return synth(0.08, noise: 0.15, noiseDecay: 90, partials: [Partial(freq: 1500, amp: 0.25, decay: 70), Partial(freq: 520, amp: 0.3, decay: 55)])
        case .pick:
            // 貝がからんと鳴る
            return synth(0.35, noise: 0.05, noiseDecay: 40, partials: [Partial(freq: 1760, amp: 0.3, decay: 14), Partial(freq: 2640, amp: 0.12, decay: 18)])
        case .bonus:
            // 潮の恵み：2 音が上がる
            return synth(0.55, noise: 0, partials: [Partial(freq: 1318.5, amp: 0.3, decay: 8), Partial(freq: 1975.5, amp: 0.3, decay: 7, delay: 0.09)])
        case .build:
            // 木づちを 2 回
            return synth(0.45, noise: 0.25, noiseDecay: 50, partials: [Partial(freq: 240, amp: 0.5, decay: 30), Partial(freq: 260, amp: 0.45, decay: 30, delay: 0.16), Partial(freq: 1046.5, amp: 0.18, decay: 6, delay: 0.2)])
        case .deliver:
            // 鈴が 3 つ
            let notes = [1046.5, 1318.5, 1568.0]
            return synth(0.8, noise: 0, partials: notes.enumerated().map { i, f in Partial(freq: f, amp: 0.28, decay: 6, delay: Double(i) * 0.08) })
        case .short:
            // 足りない：低いぽすっ
            return synth(0.3, noise: 0.1, noiseDecay: 30, partials: [Partial(freq: 200, amp: 0.45, decay: 16, sweepTo: 150)])
        case .dusk:
            // 日が沈む：下がる音
            return synth(1.0, noise: 0.05, noiseDecay: 3, partials: [Partial(freq: 523.3, amp: 0.25, decay: 3, sweepTo: 261.6), Partial(freq: 392, amp: 0.2, decay: 3, delay: 0.15, sweepTo: 196)])
        case .hurt:
            return synth(0.22, noise: 0.2, noiseDecay: 25, partials: [Partial(freq: 150, amp: 0.5, decay: 18, sweepTo: 90)])
        case .pop:
            // もやがはじける
            return synth(0.12, noise: 0.22, noiseDecay: 60, partials: [Partial(freq: 880, amp: 0.2, decay: 40, sweepTo: 1400)])
        case .bell:
            return synth(1.0, noise: 0, partials: [Partial(freq: 587.3, amp: 0.35, decay: 3), Partial(freq: 1621, amp: 0.12, decay: 5)])
        case .shade:
            // 大もや：低いうなり
            return synth(1.2, noise: 0.15, noiseDecay: 2, partials: [Partial(freq: 70, amp: 0.55, decay: 1.5, sweepTo: 55), Partial(freq: 104, amp: 0.3, decay: 2)])
        case .levelUp:
            let notes = [784.0, 987.8, 1174.7, 1568.0]
            return synth(0.7, noise: 0, partials: notes.enumerated().map { i, f in Partial(freq: f, amp: 0.25, decay: 6, delay: Double(i) * 0.06) })
        case .dawn:
            // 夜明け：和音
            let notes = [523.3, 659.3, 784.0, 1046.5]
            return synth(1.8, noise: 0.03, noiseDecay: 4, partials: notes.enumerated().flatMap { i, f in
                [Partial(freq: f, amp: 0.3, decay: 2.2, delay: Double(i) * 0.12), Partial(freq: f * 2, amp: 0.06, decay: 4, delay: Double(i) * 0.12)]
            })
        case .fall:
            return synth(1.0, noise: 0.08, noiseDecay: 4, partials: [Partial(freq: 392, amp: 0.3, decay: 3, sweepTo: 196), Partial(freq: 311.1, amp: 0.25, decay: 3, delay: 0.2, sweepTo: 155.6)])
        }
    }

    private func synth(_ seconds: Double, noise: Double, noiseDecay: Double = 60, partials: [Partial]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRandom(seed: 42)
        var phases = Array(repeating: 0.0, count: partials.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in partials.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.sweepTo { f = p.freq + (to - p.freq) * min(1, local / seconds) }
                phases[k] += 2 * .pi * f / rate
                // 立ち上がりを 3ms でならす（ぷつっと鳴らない）
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = Double(rng.next() % 20_000) / 10_000 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            // 終わりを 10ms でならす
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
