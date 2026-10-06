import CoreGraphics
import Foundation

/// ドラッグ中に盤面を指に追従させる角度の計算。フリックの角速度（`FlickSpin`）と同じ角度の測り方を使う。
enum WheelDrag {
    /// 指が `from` から `to` へ動いたとき、盤面中心 `center` のまわりに盤面を回す角度（度、画面上の時計回りが正）。
    /// 中心から `Config.flickDeadZoneRadius` 未満の点は角度が定まらないので、どちらかが入っていれば 0（盤面は動かさない）。
    /// 中心付近を通って反対側へ抜けても、抜けた先から改めて追従するだけで盤面は跳ねない。
    static func rotationDelta(from: CGPoint, to: CGPoint, center: CGPoint) -> Double {
        let deadZone = Config.flickDeadZoneRadius
        guard distance(from: center, to: from) >= deadZone, distance(from: center, to: to) >= deadZone else { return 0 }
        return normalized(angle(of: to, around: center) - angle(of: from, around: center))
    }

    /// 中心から見た向き（度）。SwiftUI は y 軸が下向きなので、値が増える向きが画面上の時計回りになる。
    static func angle(of point: CGPoint, around center: CGPoint) -> Double {
        atan2(Double(point.y - center.y), Double(point.x - center.x)) * 180 / .pi
    }

    /// 隣り合う 2 点の角度差を -180〜180 度に収める。±180 度をまたいでも 1 周分跳ねないようにする。
    static func normalized(_ delta: Double) -> Double {
        var value = delta.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }

    static func distance(from a: CGPoint, to b: CGPoint) -> Double {
        hypot(Double(b.x - a.x), Double(b.y - a.y))
    }
}
