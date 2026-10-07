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
    /// 重力が読めない（長さが 0）ときは nil。
    static func deviceTilt(_ gravity: DeviceGravity) -> WheelTilt? {
        let length = (gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z).squareRoot()
        guard length > 1e-6 else { return nil }
        let pitch = atan2(-gravity.y, -gravity.z) * 180 / .pi
        let roll = asin(max(-1, min(1, gravity.x / length))) * 180 / .pi
        return WheelTilt(pitch: pitch, roll: roll)
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
              let current = deviceTilt(gravity),
              let baseline,
              let origin = deviceTilt(baseline)
        else { return .zero }
        let change = WheelTilt(
            pitch: normalized(current.pitch - origin.pitch),
            roll: current.roll - origin.roll
        )
        return clamped(change, maxAngle: maxAngle)
    }

    /// 正面からの傾きが `maxAngle` を超えたら、向きを保ったまま `maxAngle` まで縮める。
    static func clamped(_ tilt: WheelTilt, maxAngle: Double) -> WheelTilt {
        let magnitude = tilt.magnitude
        guard magnitude > maxAngle, magnitude > 0 else { return tilt }
        let scale = max(0, maxAngle) / magnitude
        return WheelTilt(pitch: tilt.pitch * scale, roll: tilt.roll * scale)
    }

    /// 角度を -180 以上 180 未満に収める（裏返しをまたいだ差が一周分ずれないように）。
    private static func normalized(_ degrees: Double) -> Double {
        let wrapped = (degrees + 180).truncatingRemainder(dividingBy: 360)
        return (wrapped < 0 ? wrapped + 360 : wrapped) - 180
    }
}
