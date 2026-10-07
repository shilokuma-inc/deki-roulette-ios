import Foundation

/// 端末の座標系で見た重力の向き（`CMDeviceMotion.gravity` と同じ。単位は g）。
/// x は画面の右、y は画面の上、z は画面の手前が正。机に画面を上にして置くと `(0, 0, -1)`、縦に起こすと `(0, -1, 0)`。
struct DeviceGravity: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double

    /// 画面を上にして水平に置いた状態。
    static let flat = DeviceGravity(x: 0, y: 0, z: -1)
}

/// 3D の盤の傾き（度）。盤を支柱の 1 点で支えたまま、画面の 2 軸のまわりに倒す。
struct WheelTilt: Equatable, Sendable {
    /// 画面の横軸まわり。正で盤の上端（12 時側）が奥へ倒れる。
    var pitch: Double
    /// 画面の縦軸まわり。正で盤の右端が手前に起きる。
    var roll: Double

    /// 正面（傾き無し）。
    static let zero = WheelTilt(pitch: 0, roll: 0)

    /// 正面からどれだけ傾いているか（度）。
    var magnitude: Double { (pitch * pitch + roll * roll).squareRoot() }
}

/// 端末の姿勢から、3D の盤が向かう目標の傾きを求める。ばねで追従させる前の値で、時間は扱わない。
enum TiltMapping {
    /// 重力の向きから求めた端末の傾き。盤を水平（重力に直交）に保ったときに画面から見える傾きで、
    /// 水平に置くと正面、縦に起こすと `pitch` が 90 度（盤が奥へ倒れて見える）、右を下げると `roll` が正になる。
    /// 傾いた向き（画面上の重力の向き）と、水平からの角度の積で表すので、横に 90 度を超えて倒しても連続して変わる
    /// （軸ごとに `atan2` / `asin` で求めると、横倒しを越えたところで `pitch` が 180 度跳ぶ）。
    /// 重力が読めない（長さが 0）ときは nil。
    static func deviceTilt(_ gravity: DeviceGravity) -> WheelTilt? {
        guard let unit = normalized(gravity) else { return nil }
        let horizontal = (unit.x * unit.x + unit.y * unit.y).squareRoot()
        // 真上か真下を向いていて傾いた向きが定まらない。真下（画面が下向き）は奥へ倒し切った扱いにする
        guard horizontal > 1e-12 else { return unit.z < 0 ? .zero : WheelTilt(pitch: 180, roll: 0) }
        // acos(-z) は正面の近くで桁が落ちるので atan2 で求める
        let angle = atan2(horizontal, -unit.z) * 180 / .pi
        return WheelTilt(pitch: angle * -unit.y / horizontal, roll: angle * unit.x / horizontal)
    }

    /// 盤の目標の傾き。`baseline` の姿勢を正面とし、そこからの姿勢の変化で傾ける。
    /// 傾きの基準（`TiltReference`）は `baseline` で表す:
    /// - 水平に置いた状態: `DeviceGravity.flat`（重力の向きでそのまま傾く）
    /// - 画面を開いたときの持ち方: 画面を開いたときなどに取り直した重力の向き
    /// 基準がまだ無い（nil）・読めないときは正面。正面からの傾きは `maxAngle` で抑える（向きは保ったまま大きさだけを縮める）。
    /// 視差効果を減らす設定（`reduceMotion`）では常に正面。
    static func target(
        gravity: DeviceGravity,
        baseline: DeviceGravity?,
        reduceMotion: Bool,
        maxAngle: Double = Config.wheelMaxTilt
    ) -> WheelTilt {
        guard !reduceMotion,
              let baseline,
              let relative = relativeGravity(gravity, from: baseline),
              let change = deviceTilt(relative)
        else { return .zero }
        return clamped(change, maxAngle: maxAngle)
    }

    /// `baseline` を水平に置いた状態（`DeviceGravity.flat`）へ重ねる最短の回転で `gravity` を回したもの。
    /// 基準からの変化を、水平に置いた状態からの傾きとして測れる。どちらかが読めないときは nil。
    static func relativeGravity(_ gravity: DeviceGravity, from baseline: DeviceGravity) -> DeviceGravity? {
        guard let p = normalized(gravity), let a = normalized(baseline) else { return nil }
        let b = DeviceGravity.flat
        let c = dot(a, b)
        // 基準が真下（画面が下向き）だと最短の回転が定まらないので、画面の横軸まわりに半回転する
        guard c > -1 + 1e-9 else { return DeviceGravity(x: p.x, y: -p.y, z: -p.z) }
        // ロドリゲスの回転公式: R p = p + v × p + v × (v × p) / (1 + c)（v = a × b、c = a · b）
        let v = cross(a, b)
        let vp = cross(v, p)
        let vvp = cross(v, vp)
        return DeviceGravity(
            x: p.x + vp.x + vvp.x / (1 + c),
            y: p.y + vp.y + vvp.y / (1 + c),
            z: p.z + vp.z + vvp.z / (1 + c)
        )
    }

    /// 正面からの傾きが `maxAngle` を超えたら、向きを保ったまま `maxAngle` まで縮める。
    static func clamped(_ tilt: WheelTilt, maxAngle: Double) -> WheelTilt {
        let magnitude = tilt.magnitude
        guard magnitude > maxAngle, magnitude > 0 else { return tilt }
        let scale = max(0, maxAngle) / magnitude
        return WheelTilt(pitch: tilt.pitch * scale, roll: tilt.roll * scale)
    }

    private static func normalized(_ v: DeviceGravity) -> DeviceGravity? {
        let length = dot(v, v).squareRoot()
        guard length > 1e-6 else { return nil }
        return DeviceGravity(x: v.x / length, y: v.y / length, z: v.z / length)
    }

    private static func dot(_ a: DeviceGravity, _ b: DeviceGravity) -> Double {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    private static func cross(_ a: DeviceGravity, _ b: DeviceGravity) -> DeviceGravity {
        DeviceGravity(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
    }
}
