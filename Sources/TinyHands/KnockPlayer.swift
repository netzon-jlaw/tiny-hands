import AVFoundation

/// Plays a short toy-hand tap (bundled CC0 samples, with a synthesized fallback) as ordinary system audio,
/// so it is picked up by "share sound" in Zoom / Meet / Loom.
///
/// All engine work runs on its own serial queue, never the main thread. Starting an
/// AVAudioEngine talks to CoreAudio and can block for a long time, or fail over and over,
/// while the output device is changing (a call ending and a headset leaving call mode, for
/// example). On the main thread that stalled the pointer's tracking timer.
final class KnockPlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TinyHands.KnockPlayer", qos: .userInitiated)
    // Everything below is touched only on `queue` (or in init, before the queue is used).
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var speeds: [AVAudioUnitVarispeed] = []
    /// Recorded CC0 samples (Resources/Sounds): tap = levels 1-2, poke = 3-4, thwack = 5.
    private var pools: [String: [AVAudioPCMBuffer]] = [:]
    private var lastPick: [String: Int] = [:]
    private var next = 0
    private var buffers: [AVAudioPCMBuffer] = []
    /// When the engine last failed to start, so a device that keeps refusing is retried
    /// at most once a second rather than on every click.
    private var lastFailedStart: CFTimeInterval = -.infinity
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    init() {
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            let v = AVAudioUnitVarispeed()
            engine.attach(p)
            engine.attach(v)
            engine.connect(p, to: v, format: format)
            engine.connect(v, to: engine.mainMixerNode, format: format)
            players.append(p)
            speeds.append(v)
        }
        // A few pitch variants so rapid taps don't sound robotic.
        for pitch in [0.92, 0.97, 1.0, 1.04, 1.09] { buffers.append(makeKnock(pitch: pitch, double: false)) }
        for pitch in [0.95, 1.05] { buffers.append(makeKnock(pitch: pitch, double: true)) }

        for name in ["tap", "poke", "thwack"] { pools[name] = loadPool(name) }
        NSLog("TinyHands sounds loaded: tap=%d poke=%d thwack=%d", pools["tap"]!.count, pools["poke"]!.count, pools["thwack"]!.count)

        // The output device changed and the engine stopped. Restart it here, in the
        // background, so the next click doesn't pay for it.
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                               queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                self.lastFailedStart = -.infinity
                _ = self.ensureStarted()
            }
        }
        queue.async { _ = self.ensureStarted() }
    }

    /// Call on `queue` only.
    private func ensureStarted() -> Bool {
        if engine.isRunning { return true }
        let now = CACurrentMediaTime()
        guard now - lastFailedStart > 1 else { return false }
        do {
            engine.prepare()
            try engine.start()
            return true
        } catch {
            lastFailedStart = now
            NSLog("TinyHands audio engine failed to start: \(error)")
            return false
        }
    }

    /// level 1...5. Safe to call from any thread; returns at once.
    func knock(level: Int, volume: Double) {
        guard volume > 0 else { return }
        queue.async { self.play(level: level, volume: volume) }
    }

    private func play(level: Int, volume: Double) {
        guard ensureStarted() else { return }
        let p = players[next]
        let v = speeds[next]
        next = (next + 1) % players.count
        let poolName = level >= 5 ? "thwack" : (level >= 3 ? "poke" : "tap")
        let buffer: AVAudioPCMBuffer
        if let pool = pools[poolName], !pool.isEmpty {
            // Random variant, never the same one twice in a row.
            var i = Int.random(in: 0..<pool.count)
            if pool.count > 1 && i == lastPick[poolName] { i = (i + 1) % pool.count }
            lastPick[poolName] = i
            buffer = pool[i]
            v.rate = Float.random(in: 0.95...1.05)
        } else if level >= 5 {
            buffer = buffers[5 + Int.random(in: 0...1)]
            v.rate = 1
        } else {
            buffer = buffers[Int.random(in: 0...4)]
            v.rate = 1
        }
        let levelGain: [Double] = [0, 0.6, 0.75, 0.8, 0.9, 1.0]
        p.volume = Float(volume * levelGain[max(1, min(5, level))])
        p.stop()
        p.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        p.play()
    }

    private func loadPool(_ name: String) -> [AVAudioPCMBuffer] {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Sounds"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.lastPathComponent.hasPrefix(name + "-") && $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false),
                      file.processingFormat.sampleRate == format.sampleRate, file.processingFormat.channelCount == 1,
                      let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
                      (try? file.read(into: buf)) != nil else { return nil }
                return buf
            }
    }

    /// Fallback when the bundled samples are missing.
    private func makeKnock(pitch: Double, double: Bool) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let hitLen = 0.16
        let gap = 0.085
        let total = double ? hitLen + gap : hitLen
        let frames = AVAudioFrameCount(total * sr)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let out = buf.floatChannelData![0]
        for i in 0..<Int(frames) { out[i] = 0 }

        func addHit(at start: Double, gain: Double) {
            let f1 = 185.0 * pitch, f2 = 410.0 * pitch, f3 = 960.0 * pitch
            var seed: UInt32 = 0x1234_5678
            let s0 = Int(start * sr)
            for i in 0..<Int(hitLen * sr) where s0 + i < Int(frames) {
                let t = Double(i) / sr
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Double(Int32(bitPattern: seed)) / Double(Int32.max)
                let body = 0.62 * sin(2 * .pi * f1 * t) * exp(-t / 0.045)
                    + 0.32 * sin(2 * .pi * f2 * t) * exp(-t / 0.022)
                    + 0.14 * sin(2 * .pi * f3 * t) * exp(-t / 0.008)
                let click = 0.45 * noise * exp(-t / 0.0035)
                let attack = min(1.0, t / 0.0008)
                out[s0 + i] += Float((body + click) * attack * gain * 0.9)
            }
        }
        addHit(at: 0, gain: 1.0)
        if double { addHit(at: gap, gain: 0.8) }
        return buf
    }
}
