import AVFAudio

/// スピン中の「カチッ」を鳴らす。止まる位置も回転角もスピン開始時に決まっているので、
/// 鳴らす時刻も先に分かる。`ClickTrack` で 1 本の波形にしてから一度に流し、リズムを揺らさない。
/// 指で盤面を動かしている間は、境目を越えるたびに `play(at: [0])` で 1 回ずつ鳴らす。
/// 音が出せない環境（素材が読めない、オーディオが使えない等）では黙って何もしない。
@MainActor
final class SpinSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var click: (samples: [Float], format: AVAudioFormat)?
    /// セッションを `.ambient` にして有効化する処理。成功したかを返す。
    /// 終わる前にエンジンを起動すると既定のカテゴリで有効化され、他のアプリの音を止めてしまう。
    private var sessionSetup: Task<Bool, Never>?
    /// `stop()` や次の `play(at:)` のあとに、待っていた古い再生が始まらないようにする。
    private var generation = 0

    /// 素材の読み込みとオーディオの準備。画面が出たところで呼んでおく。
    /// セッションの有効化はメインスレッドで待つと UI が固まるので、別スレッドで行い `play(at:)` はその完了を待つ。
    func prepare() {
        if click == nil {
            guard let loaded = loadClick() else { return }
            click = loaded
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: loaded.format)
        }
        // 前回の準備に失敗していれば nil に戻してあるので、ここでやり直す
        guard sessionSetup == nil else { return }
        sessionSetup = Task.detached(priority: .utility) {
            let session = AVAudioSession.sharedInstance()
            do {
                // 消音（マナー）スイッチに従い、他のアプリで鳴っている音も止めない
                try session.setCategory(.ambient, mode: .default)
                try session.setActive(true)
                return true
            } catch {
                return false
            }
        }
    }

    /// `times`（スピン開始からの秒）にクリック音を鳴らす。呼んだ時点が 0 秒。
    func play(at times: [TimeInterval]) {
        prepare()
        guard !times.isEmpty, let click, let sessionSetup else { return }

        generation += 1
        let current = generation
        let requested = ContinuousClock.now
        Task { [weak self] in
            // セッションの準備が済むまでエンジンは起動しない。失敗していれば鳴らさず、次の再生で準備し直す
            let ready = await sessionSetup.value
            guard let self else { return }
            if !ready, self.sessionSetup == sessionSetup { self.sessionSetup = nil }
            guard ready, self.generation == current else { return }
            // 待った分だけ遅れて鳴り始めるので、時刻をずらして過ぎたものは捨てる
            let waited = requested.duration(to: .now) / .seconds(1)
            let remaining = times.map { $0 - waited }.filter { $0 >= 0 }
            self.start(remaining, click: click)
        }
    }

    /// 画面から離れるときなど、鳴らしている途中で止める。
    func stop() {
        guard click != nil else { return }
        generation += 1
        player.stop()
        engine.stop()
    }

    private func start(_ times: [TimeInterval], click: (samples: [Float], format: AVAudioFormat)) {
        guard !times.isEmpty else { return }
        let track = ClickTrack.render(
            click: click.samples,
            sampleRate: click.format.sampleRate,
            times: times,
            gain: Config.clickGain
        )
        guard let buffer = makeBuffer(track, format: click.format) else { return }
        // 中断のあとはエンジンが止まっているので、鳴らすたびに確かめる
        guard engine.isRunning || (try? engine.start()) != nil else { return }

        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    private func loadClick() -> (samples: [Float], format: AVAudioFormat)? {
        guard let url = Bundle.main.url(forResource: "click", withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length)
              ),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData?.pointee
        else { return nil }

        return (Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))), file.processingFormat)
    }

    private func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?.pointee
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }
}
