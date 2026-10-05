// スピン中に鳴らすクリック音 (WAV, 16bit / 44.1kHz / モノラル) を合成する。
// 人生ゲームのルーレットのように、仕切りが爪を弾く「カチッ」を狙って
// 減衰する高めの正弦波 3 本 + ごく短いノイズで作る。
// 使い方: swift scripts/make-click-sound.swift <出力先.wav>
// --preview を付けると、スピン 1 回分のカチカチを並べた試聴用の音を書き出す（項目数は後ろに書ける）。
import Foundation

let sampleRate = 44100.0
let duration = 0.035
let peak = 0.92

/// 弾かれた爪の鳴り。周波数と減衰の速さ（秒）と音量。
let tones: [(frequency: Double, decay: Double, gain: Double)] = [
    (1750, 0.0055, 1.00),
    (3150, 0.0032, 0.62),
    (5400, 0.0016, 0.34),
]

/// 当たった瞬間の硬い成分。正弦波だけだと「ポン」に寄るので短いノイズを足す。
let noiseDecay = 0.0009
let noiseGain = 0.55

/// 頭とお尻を丸めてプチッというノイズを防ぐ。
let attack = 0.0004
let release = 0.003

// 毎回同じ音を出すため、乱数は固定の種から作る
var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
func noise() -> Double {
    seed ^= seed << 13
    seed ^= seed >> 7
    seed ^= seed << 17
    return Double(Int64(bitPattern: seed)) / Double(Int64.max)
}

let frameCount = Int(duration * sampleRate)
var samples = [Double](repeating: 0, count: frameCount)
for i in 0..<frameCount {
    let t = Double(i) / sampleRate
    var value = noise() * noiseGain * exp(-t / noiseDecay)
    for tone in tones {
        value += sin(2 * .pi * tone.frequency * t) * tone.gain * exp(-t / tone.decay)
    }
    if t < attack { value *= t / attack }
    let remaining = duration - t
    if remaining < release { value *= remaining / release }
    samples[i] = value
}

let maxAmplitude = samples.map(abs).max() ?? 1
let scale = maxAmplitude > 0 ? peak / maxAmplitude : 0
let pcm = samples.map { Int16(max(-1, min(1, $0 * scale)) * 32767) }

/// RIFF (WAVE) のヘッダ + リトルエンディアンの 16bit PCM。
func wav(_ pcm: [Int16], sampleRate: Double) -> Data {
    var data = Data()
    func ascii(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
    func u32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

    let bytes = UInt32(pcm.count * 2)
    ascii("RIFF"); u32(36 + bytes); ascii("WAVE")
    ascii("fmt "); u32(16); u16(1); u16(1)
    u32(UInt32(sampleRate)); u32(UInt32(sampleRate) * 2); u16(2); u16(16)
    ascii("data"); u32(bytes)
    for sample in pcm { u16(UInt16(bitPattern: sample)) }
    return data
}

// MARK: 試聴用のプレビュー
// スピン 1 回分のカチカチを並べて、耳で確かめられるようにする。
// アプリでの実装は `SpinTicks`（鳴らす時刻）と `ClickTrack`（波形の合成）で、ここはその再現。

let previewSpinDuration = 4.5      // Config.spinDuration
let previewRotation = 1830.0       // 5 周 + 30 度ぶん回るスピンを想定
let previewDefaultItemCount = 8
let previewMinInterval = 0.032     // Config.clickMinInterval
let previewGain = 0.7              // Config.clickGain
let easing = (x1: 0.15, y1: 0.85, x2: 0.3, y2: 1.0)  // Config.spinEasing

/// 端点 0 と 1 を持つ 3 次ベジェの 1 成分。
func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
    let u = 1 - s
    return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
}

/// 進み具合 `progress` に達する時刻の割合を二分法で求める。
func time(atProgress progress: Double) -> Double {
    var low = 0.0
    var high = 1.0
    for _ in 0..<48 {
        let mid = (low + high) / 2
        if bezier(mid, easing.y1, easing.y2) < progress { low = mid } else { high = mid }
    }
    return bezier((low + high) / 2, easing.x1, easing.x2)
}

func previewTrack(itemCount: Int) -> [Int16] {
    let sliceAngle = 360.0 / Double(itemCount)
    var times: [Double] = []
    var lastKept = -Double.infinity
    for boundary in 1...Int(previewRotation / sliceAngle) {
        let t = time(atProgress: Double(boundary) * sliceAngle / previewRotation) * previewSpinDuration
        guard t - lastKept >= previewMinInterval else { continue }
        times.append(t)
        lastKept = t
    }

    var track = [Double](repeating: 0, count: Int(previewSpinDuration * sampleRate) + frameCount)
    for t in times {
        let offset = Int(t * sampleRate)
        for i in 0..<frameCount { track[offset + i] += Double(pcm[i]) / 32767 * previewGain }
    }
    print("プレビュー: \(itemCount) 項目で \(times.count) 回のクリック")
    return track.map { Int16(max(-1, min(1, $0)) * 32767) }
}

let arguments = CommandLine.arguments
let preview = arguments.count >= 3 && arguments[2] == "--preview"
let itemCount = arguments.count == 4 ? Int(arguments[3]) ?? previewDefaultItemCount : previewDefaultItemCount
// 項目数が 0 以下だと境目の数が 0 以下になり、範囲の生成で落ちる
guard arguments.count == 2 || (preview && arguments.count <= 4 && itemCount > 0) else {
    FileHandle.standardError.write(Data("使い方: swift scripts/make-click-sound.swift <出力先.wav> [--preview [項目数]]\n".utf8))
    exit(1)
}
let path = arguments[1]
let output = preview ? previewTrack(itemCount: itemCount) : pcm
try wav(output, sampleRate: sampleRate).write(to: URL(fileURLWithPath: path))
print("\(path) に \(output.count) サンプル (\(String(format: "%.2f", Double(output.count) / sampleRate)) 秒) を書き出した")
