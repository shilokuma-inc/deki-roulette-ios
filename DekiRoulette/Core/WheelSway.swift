import Foundation

/// 3D の盤の傾き 1 軸ぶんのばね（減衰振動）。目標の傾き（`TiltMapping.target`）へ追従させ、
/// 端末を動かした勢い（`SwayKick`）を速度に足して余分に揺らす。時間は引数で受け、自分では測らない。
struct SpringAxis: Equatable, Sendable {
    /// 今の傾き（度）。
    var position: Double = 0
    /// 今の角速度（度/秒）。
    var velocity: Double = 0

    /// 1 回の `step` で進める時間の上限（秒）。バックグラウンドから戻ったときなどに間が空いても、揺れが飛ばないようにする。
    static let maxStepDuration: TimeInterval = 0.1
    /// 数値計算の刻み（秒）の上限。ばねが硬い・減衰が強いときは `SpringParameters.stableStep` まで細かくする。
    static let substep: TimeInterval = 1.0 / 240

    /// 1 回の `step` で計算を繰り返す回数の上限。刻みが細かくなりすぎても更新が長く止まらないようにする。
    static let maxIterations = 2048

    /// `target` へ向けて `duration` 秒だけ進める（半陰的オイラー法）。`duration` は `maxStepDuration` で抑える。
    mutating func step(toward target: Double, duration: TimeInterval, spring: SpringParameters = .wheelSway) {
        let total = min(max(duration, 0), Self.maxStepDuration)
        guard total > 0 else { return }
        let step = min(Self.substep, spring.stableStep)
        let count = min(Int((total / step).rounded(.up)), Self.maxIterations)
        let dt = total / Double(count)
        for _ in 0..<count {
            let acceleration = -spring.stiffness * (position - target) - spring.damping * velocity
            velocity += acceleration * dt
            position += velocity * dt
        }
    }

    /// 角速度を `velocityChange`（度/秒）だけ足す。
    mutating func kick(_ velocityChange: Double) {
        velocity += velocityChange
    }

    /// `target` で止まったとみなせるか。結果表示中に正面へ戻したあと、姿勢の購読を止める判定に使う。
    func isAtRest(at target: Double, positionTolerance: Double = 0.05, velocityTolerance: Double = 0.5) -> Bool {
        abs(position - target) <= positionTolerance && abs(velocity) <= velocityTolerance
    }
}

/// ばねの強さと減衰。周期（`response`）と減衰比（`dampingRatio`）で決める（SwiftUI の `spring(response:dampingFraction:)` と同じ考え方）。
struct SpringParameters: Equatable, Sendable {
    /// ばね定数（1/秒²）。
    var stiffness: Double
    /// 減衰係数（1/秒）。
    var damping: Double

    /// 受け付ける周期（秒）。短すぎると刻みが細かくなりすぎ、長すぎると目標へ戻らないのと変わらない。
    static let responseRange: ClosedRange<TimeInterval> = 0.05...10
    /// 受け付ける減衰比。大きすぎると刻みが細かくなりすぎる（10 で既に目標へほとんど寄らない）。
    static let dampingRatioRange: ClosedRange<Double> = 0...10

    /// 範囲外の値は範囲の端に、数でない値（NaN）は範囲の下端に寄せる。
    init(response: TimeInterval, dampingRatio: Double) {
        let omega = 2 * Double.pi / Self.clamp(response, to: Self.responseRange)
        stiffness = omega * omega
        damping = 2 * Self.clamp(dampingRatio, to: Self.dampingRatioRange) * omega
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        guard !value.isNaN else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// 半陰的オイラー法が発散しない刻み（秒）。固有角振動数と減衰係数の大きい方に対して 0.2 に収まる長さにする
    /// （どちらかとの積が 2 を超えると、1 回の更新で目標を大きく行き過ぎて揺れが増え続ける）。
    var stableStep: TimeInterval {
        0.2 / max(stiffness.squareRoot(), damping, 1e-9)
    }

    /// 3D の盤の揺れ。
    static let wheelSway = SpringParameters(response: Config.wheelSwayResponse, dampingRatio: Config.wheelSwayDampingRatio)
}

/// 端末を動かした勢いを、盤の揺れに足す角速度に写す。
enum SwayKick {
    /// 端末の座標系の `userAcceleration`（重力を除いた加速度、g。x は画面の右、y は画面の上、z は画面の手前）から、
    /// 盤の傾き（`pitch` は正で上端が奥へ、`roll` は正で右端が手前へ）に足す角速度（度/秒）を求める。
    /// 盤は支柱の 1 点で支えられているので、端末を動かした向きに対して遅れて傾く（慣性）:
    /// - 手前へ引く（z が正）・上へ振る（y が正）と、上端が奥へ倒れる（`pitch` が正）
    /// - 右へ振る（x が正）と、右端が手前に起きる（`roll` が正）
    /// `threshold` 未満の勢いは手の震えとみなして 0、各軸は `limit` で抑える。視差効果を減らす設定では常に 0。
    static func velocity(
        x: Double,
        y: Double,
        z: Double,
        reduceMotion: Bool,
        gain: Double = Config.wheelSwayKickGain,
        limit: Double = Config.wheelSwayMaxKick,
        threshold: Double = Config.wheelSwayKickThreshold
    ) -> (pitch: Double, roll: Double) {
        guard !reduceMotion, (x * x + y * y + z * z).squareRoot() >= threshold else { return (0, 0) }
        func clamp(_ value: Double) -> Double { max(-limit, min(limit, value)) }
        return (pitch: clamp(gain * (y + z)), roll: clamp(gain * x))
    }
}

/// 3D の盤の揺れ（2 軸のばね）。姿勢を読み取るたびに `advance` で、読み取りの時刻の差だけ進める。
struct WheelSway: Equatable, Sendable {
    var pitch = SpringAxis()
    var roll = SpringAxis()
    /// 直前に進めた読み取りの時刻。nil なら次の 1 回は時間を進めない（最初の読み取り・購読を止めたあと）。
    var lastTimestamp: TimeInterval?

    /// 今の盤の傾き。
    var tilt: WheelTilt { WheelTilt(pitch: pitch.position, roll: roll.position) }

    /// 勢い `kick`（度/秒、`SwayKick.velocity`）を足し、時刻 `timestamp` まで目標 `target` へ向けて進める。
    /// `kick` は `nominalInterval`（姿勢を読む間隔）ごとに足す量なので、前の読み取りからの経過時間の割合を掛けて足す
    /// （読み取りが詰まっても間引かれても、同じ勢いなら同じだけ揺れる）。経過時間はばねと同じ `SpringAxis.maxStepDuration` で抑える。
    /// 最初の読み取りと時刻が戻ったときは、時間も勢いも進めない。
    mutating func advance(
        toward target: WheelTilt,
        kick: (pitch: Double, roll: Double) = (0, 0),
        at timestamp: TimeInterval,
        spring: SpringParameters = .wheelSway,
        nominalInterval: TimeInterval = Config.motionUpdateInterval
    ) {
        let duration = min(lastTimestamp.map { max(0, timestamp - $0) } ?? 0, SpringAxis.maxStepDuration)
        lastTimestamp = timestamp
        let share = nominalInterval > 0 ? duration / nominalInterval : 0
        pitch.kick(kick.pitch * share)
        roll.kick(kick.roll * share)
        pitch.step(toward: target.pitch, duration: duration, spring: spring)
        roll.step(toward: target.roll, duration: duration, spring: spring)
    }

    /// `target` で止まったとみなせるか。
    func isAtRest(at target: WheelTilt) -> Bool {
        pitch.isAtRest(at: target.pitch) && roll.isAtRest(at: target.roll)
    }

    /// 購読を止めた。傾きと速度は残し、間が空いた分の時間は進めない。
    mutating func pause() {
        lastTimestamp = nil
    }
}

/// 3D の盤をどう揺らすか。揺らす場面は待機中と回転中だけで、結果表示中は正面に戻して止める。
enum SwayMode: Equatable, Sendable {
    /// 端末の傾きに追従し、動かした勢いで揺れる（待機中・回転中）。
    case follow
    /// 正面へばねで戻し、止まったら姿勢の購読も止める（結果表示中）。
    case settle
    /// 揺らさず正面に置く（視差効果を減らす）。
    case still

    static func mode(showingResult: Bool, reduceMotion: Bool) -> SwayMode {
        if reduceMotion { return .still }
        return showingResult ? .settle : .follow
    }

    /// 姿勢を購読するか。盤面が画面に出ていてアプリが前面にある（`active`）間で、揺らす場面か、正面へ戻している途中だけ。
    func subscribes(active: Bool, atRest: Bool) -> Bool {
        guard active else { return false }
        switch self {
        case .follow: return true
        case .settle: return !atRest
        case .still: return false
        }
    }
}
