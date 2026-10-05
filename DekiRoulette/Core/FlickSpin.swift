import CoreGraphics
import Foundation

/// 盤面のフリックの解釈。指を離した時点の速度から角速度を出し、周回数に写す。
/// 止まる位置には関与しない（`RouletteMath.nextRotation` に周回数として渡すだけ）。
enum FlickSpin {
    /// 盤面中心 `center` を軸に見た、`location` で `velocity`（pt/秒）で動く指の角速度（度/秒）。
    /// 画面上の時計回りが正。中心に近すぎる位置は角速度が発散するので 0 を返す。
    static func angularVelocity(location: CGPoint, velocity: CGSize, center: CGPoint) -> Double {
        let rx = Double(location.x - center.x)
        let ry = Double(location.y - center.y)
        let radiusSquared = rx * rx + ry * ry
        guard radiusSquared >= Config.flickDeadZoneRadius * Config.flickDeadZoneRadius else { return 0 }
        // 半径ベクトルと速度の外積が接線方向の成分。SwiftUI は y 軸が下向きなので、
        // 正の値がそのまま画面上の時計回りになる
        let cross = rx * Double(velocity.height) - ry * Double(velocity.width)
        return cross / radiusSquared * 180 / .pi
    }

    /// 角速度（度/秒）を周回数に写す。回す向きは常に時計回りなので、向きは見ず速さだけを使う。
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
}
