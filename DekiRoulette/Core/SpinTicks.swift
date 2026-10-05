import Foundation

/// スピン中に針がスライスの境目を越える時刻の計算。回転は `withAnimation` の補間に任せていて
/// 途中の角度は観測できないので、開始時にこの列を求めて音を鳴らす位置を決める。
enum SpinTicks {
    /// 回転角が `from` から `to` へ `duration` 秒で `easing` に沿って進むとき、針の下のスライス
    /// （`RouletteMath.indexUnderPointer`）が切り替わる時刻（開始からの秒）を昇順で返す。
    /// 直前に残した時刻から `minInterval` 未満しか離れていないものは間引く。序盤は速くて境目が密なので
    /// 間引かれ、終盤は減速に合わせて間隔が開く。
    static func boundaryCrossings(
        from: Double,
        to: Double,
        count: Int,
        duration: TimeInterval,
        easing: CubicBezierCurve,
        minInterval: TimeInterval
    ) -> [TimeInterval] {
        guard count > 0, to > from, duration > 0 else { return [] }
        let sliceAngle = 360.0 / Double(count)
        // 針の下の添字は盤面角 (360 - R) mod 360 が sliceAngle の倍数をまたぐ瞬間に変わる。
        // 360 は sliceAngle の倍数なので、回転角 R 自身が k * sliceAngle に達する瞬間と同じ
        let firstBoundary = Int((from / sliceAngle).rounded(.down)) + 1
        let lastBoundary = Int((to / sliceAngle).rounded(.down))
        guard lastBoundary >= firstBoundary else { return [] }

        var times: [TimeInterval] = []
        var lastKept = -Double.infinity
        for boundary in firstBoundary...lastBoundary {
            let progress = (Double(boundary) * sliceAngle - from) / (to - from)
            let time = easing.time(atProgress: progress) * duration
            guard time - lastKept >= minInterval else { continue }
            times.append(time)
            lastKept = time
        }
        return times
    }
}
