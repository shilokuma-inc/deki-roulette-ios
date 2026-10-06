import CoreGraphics
import Foundation

/// 盤面のフリックの解釈。指を離す直前の動きから角速度を出し、周回数に写す。
/// 止まる位置には関与しない（`RouletteMath.nextRotation` に周回数と向きとして渡すだけ）。
enum FlickSpin {
    /// ドラッグ中の指の位置と時刻。
    struct Sample: Equatable {
        var time: TimeInterval
        var location: CGPoint
    }

    /// 指を離す直前 `Config.flickSampleWindow` 秒に、盤面中心 `center` のまわりを回った角度から求めた角速度（度/秒）。
    /// 画面上の時計回りが正。`samples` は時刻順で、最後の 1 点が指を離した位置。
    ///
    /// 離した瞬間の `DragGesture.Value.velocity` は最後の数サンプルで決まり、離すタイミングで大きく揺れるので使わない。
    /// 中心に近すぎる点は角度が定まらないので除く。
    static func angularVelocity(samples: [Sample], center: CGPoint) -> Double {
        // 窓は指を離した時刻から取り、窓の中の点だけを使う。窓をまたぐ区間や、中心付近で止めていた間より前の動きを
        // 足すと、最後に止めていても手前の動きで回ってしまう
        guard let releaseTime = samples.last?.time else { return 0 }
        let windowStart = releaseTime - Config.flickSampleWindow
        let recent = samples.filter {
            $0.time >= windowStart && distance(from: center, to: $0.location) >= Config.flickDeadZoneRadius
        }
        guard let first = recent.first, let last = recent.last, last.time > first.time else { return 0 }

        var swept = 0.0
        for (from, to) in zip(recent, recent.dropFirst()) {
            swept += normalized(angle(of: to.location, around: center) - angle(of: from.location, around: center))
        }
        return swept / (last.time - first.time)
    }

    /// フリックで始めるスピンの周回数と向き。
    struct Spin: Equatable {
        var fullSpins: Int
        var direction: SpinDirection
    }

    /// 角速度（度/秒）を周回数と向きに写す。向きは角速度の符号で決め、正（画面上の時計回り）なら時計回り。
    /// 閾値未満なら nil（スピンを始めない）。周回数は `fullSpins(angularVelocity:)` と同じ。
    static func spin(angularVelocity: Double) -> Spin? {
        guard let fullSpins = fullSpins(angularVelocity: angularVelocity) else { return nil }
        return Spin(fullSpins: fullSpins, direction: angularVelocity > 0 ? .clockwise : .counterclockwise)
    }

    /// 角速度（度/秒）を周回数に写す。周回数は向きに依らず速さだけで決める（向きは `spin(angularVelocity:)` が返す）。
    /// 閾値未満なら nil（スピンを始めない）。閾値で最小、`flickMaxAngularVelocity` 以上で最大の周回数になる。
    static func fullSpins(angularVelocity: Double) -> Int? {
        let speed = abs(angularVelocity)
        let low = Config.flickMinAngularVelocity
        let high = Config.flickMaxAngularVelocity
        guard speed >= low else { return nil }
        let range = Config.fullSpinRange
        let ratio = min((speed - low) / (high - low), 1)
        return range.lowerBound + Int((ratio * Double(range.count - 1)).rounded())
    }

    /// 中心から見た向き（度）。SwiftUI は y 軸が下向きなので、値が増える向きが画面上の時計回りになる。
    private static func angle(of point: CGPoint, around center: CGPoint) -> Double {
        atan2(Double(point.y - center.y), Double(point.x - center.x)) * 180 / .pi
    }

    /// 隣り合う 2 点の角度差を -180〜180 度に収める。±180 度をまたいでも 1 周分跳ねないようにする。
    private static func normalized(_ delta: Double) -> Double {
        var value = delta.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> Double {
        hypot(Double(b.x - a.x), Double(b.y - a.y))
    }
}

/// フリック中の位置の記録。指が動くたびに足すので、書き換えても View を描き直さないよう参照型で持つ。
@MainActor
final class FlickSampleBuffer {
    private(set) var samples: [FlickSpin.Sample] = []

    func append(_ sample: FlickSpin.Sample) {
        // 前の点から間が空いたら、それより前の動きは今の勢いに関係しない（止めてから離した、前の操作の残り）
        if let previous = samples.last, sample.time - previous.time > Config.flickSampleWindow * 2 {
            samples.removeAll()
        }
        samples.append(sample)
        // 計算に使うのは直近の窓の中だけ。余裕を持たせて古いものを捨てる
        let keepFrom = sample.time - Config.flickSampleWindow * 2
        if let index = samples.firstIndex(where: { $0.time >= keepFrom }), index > 0 {
            samples.removeFirst(index)
        }
    }

    func reset() {
        samples.removeAll()
    }
}
