import Foundation

/// クリック音を指定の時刻に重ねた 1 本の波形を作る。
/// 1 発ずつタイマーで鳴らすとスケジューリングの揺れでリズムが乱れるので、
/// 鳴らす位置を先に波形へ焼いてしまい、サンプル単位でずれないようにする。
enum ClickTrack {
    /// `click` を `times`（開始からの秒）の位置に `gain` を掛けて足し合わせた波形を返す。
    /// 重なった部分は加算され、-1...1 に収める。鳴らす時刻が無ければ空。
    static func render(
        click: [Float],
        sampleRate: Double,
        times: [TimeInterval],
        gain: Float
    ) -> [Float] {
        guard !click.isEmpty, !times.isEmpty, sampleRate > 0 else { return [] }
        let offsets = times.map { Int(max(0, $0) * sampleRate) }
        guard let last = offsets.max() else { return [] }

        var track = [Float](repeating: 0, count: last + click.count)
        for offset in offsets {
            for (i, sample) in click.enumerated() {
                track[offset + i] += sample * gain
            }
        }
        for i in track.indices {
            track[i] = min(max(track[i], -1), 1)
        }
        return track
    }
}
