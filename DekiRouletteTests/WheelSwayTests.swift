import Foundation
import Testing
@testable import DekiRoulette

struct WheelSwayTests {
    private let spring = SpringParameters(response: 0.6, dampingRatio: 0.3)

    /// `seconds` 秒ぶん、60Hz の更新で進める。
    private func run(_ axis: inout SpringAxis, toward target: Double, seconds: Double, spring: SpringParameters) {
        for _ in 0..<Int((seconds * 60).rounded()) {
            axis.step(toward: target, duration: 1.0 / 60, spring: spring)
        }
    }

    // MARK: ばね

    @Test func 目標へ近づいて止まる() {
        var axis = SpringAxis()
        run(&axis, toward: 20, seconds: 5, spring: spring)
        #expect(axis.isAtRest(at: 20))
    }

    @Test func 減衰比が小さいと目標を行き過ぎて揺り返す() {
        var axis = SpringAxis()
        var peak = 0.0
        for _ in 0..<120 {
            axis.step(toward: 20, duration: 1.0 / 60, spring: spring)
            peak = max(peak, axis.position)
        }
        #expect(peak > 20)
    }

    @Test func 減衰比が1なら行き過ぎない() {
        let critical = SpringParameters(response: 0.6, dampingRatio: 1)
        var axis = SpringAxis()
        var peak = 0.0
        for _ in 0..<300 {
            axis.step(toward: 20, duration: 1.0 / 60, spring: critical)
            peak = max(peak, axis.position)
        }
        #expect(peak <= 20 + 1e-6)
        #expect(axis.isAtRest(at: 20))
    }

    @Test func 揺れは時間とともに小さくなる() {
        var axis = SpringAxis(position: 0, velocity: 100)
        run(&axis, toward: 0, seconds: 0.5, spring: spring)
        let early = abs(axis.position) + abs(axis.velocity) / 10
        run(&axis, toward: 0, seconds: 1.5, spring: spring)
        let late = abs(axis.position) + abs(axis.velocity) / 10
        #expect(late < early)
    }

    /// 更新の間隔（30Hz / 60Hz）が違っても、同じ時間が経てばほぼ同じ傾きになる。
    @Test func 更新の頻度に依らない() {
        var at60 = SpringAxis(position: 0, velocity: 80)
        var at30 = at60
        for _ in 0..<60 { at60.step(toward: 10, duration: 1.0 / 60, spring: spring) }
        for _ in 0..<30 { at30.step(toward: 10, duration: 1.0 / 30, spring: spring) }
        #expect(abs(at60.position - at30.position) < 0.05)
    }

    @Test func 間が空いても進める時間は上限で抑える() {
        var long = SpringAxis()
        var capped = SpringAxis()
        long.step(toward: 20, duration: 5, spring: spring)
        capped.step(toward: 20, duration: SpringAxis.maxStepDuration, spring: spring)
        #expect(long == capped)
    }

    @Test func 時間が進まなければ動かない() {
        var axis = SpringAxis(position: 3, velocity: 7)
        axis.step(toward: 20, duration: 0, spring: spring)
        axis.step(toward: 20, duration: -1, spring: spring)
        #expect(axis == SpringAxis(position: 3, velocity: 7))
    }

    /// 周期が刻みより短いばねでも、刻みを細かくして発散させない。
    @Test func 硬いばねでも発散しない() {
        let stiff = SpringParameters(response: 0.01, dampingRatio: 0.3)
        var axis = SpringAxis()
        var peak = 0.0
        for _ in 0..<300 {
            axis.step(toward: 20, duration: 1.0 / 60, spring: stiff)
            peak = max(peak, abs(axis.position))
        }
        #expect(peak < 40)
        #expect(axis.isAtRest(at: 20))
    }

    /// 減衰が強すぎても、行き過ぎたり振動したりせずに目標へ寄っていく（強い減衰では寄り方が遅い）。
    @Test func 強い減衰でも発散しない() {
        let heavy = SpringParameters(response: 0.6, dampingRatio: 20)
        var axis = SpringAxis()
        var previous = 0.0
        for _ in 0..<300 {
            axis.step(toward: 20, duration: 1.0 / 60, spring: heavy)
            #expect(axis.position >= previous - 1e-9)
            #expect(axis.position <= 20 + 1e-9)
            previous = axis.position
        }
        #expect(previous > 0)
    }

    @Test(arguments: [Double.infinity, -Double.infinity, Double.nan, 0, -1, 1e9])
    func 範囲外のばねの値は範囲に寄せる(value: Double) {
        let spring = SpringParameters(response: value, dampingRatio: value)
        #expect(spring.stiffness.isFinite && spring.stiffness > 0)
        #expect(spring.damping.isFinite && spring.damping >= 0)
        #expect(spring.stableStep > 0)
        var axis = SpringAxis()
        axis.step(toward: 20, duration: 1.0 / 60, spring: spring)
        #expect(axis.position.isFinite && axis.velocity.isFinite)
    }

    @Test func 範囲の端のばねでも繰り返しは上限に収まる() {
        let extreme = SpringParameters(
            response: SpringParameters.responseRange.lowerBound,
            dampingRatio: SpringParameters.dampingRatioRange.upperBound
        )
        let iterations = (SpringAxis.maxStepDuration / extreme.stableStep).rounded(.up)
        #expect(iterations <= Double(SpringAxis.maxIterations))
    }

    @Test func 勢いを足すと目標にいても揺れる() {
        var axis = SpringAxis(position: 10, velocity: 0)
        #expect(axis.isAtRest(at: 10))
        axis.kick(60)
        #expect(!axis.isAtRest(at: 10))
        axis.step(toward: 10, duration: 1.0 / 60, spring: spring)
        #expect(axis.position > 10)
    }

    @Test func 速度が残っていれば止まったとみなさない() {
        #expect(!SpringAxis(position: 0, velocity: 5).isAtRest(at: 0))
        #expect(!SpringAxis(position: 1, velocity: 0).isAtRest(at: 0))
    }

    @Test func 既定のばねはConfigの値() {
        #expect(SpringParameters.wheelSway == SpringParameters(response: Config.wheelSwayResponse, dampingRatio: Config.wheelSwayDampingRatio))
    }

    // MARK: 動かした勢い

    @Test func 右へ振ると右端が手前に起きる() {
        let kick = SwayKick.velocity(x: 0.2, y: 0, z: 0, reduceMotion: false, gain: 100, limit: 1000, threshold: 0)
        #expect(abs(kick.roll - 20) < 1e-9)
        #expect(kick.pitch == 0)
    }

    @Test func 手前へ引くと上端が奥へ倒れる() {
        let kick = SwayKick.velocity(x: 0, y: 0, z: 0.3, reduceMotion: false, gain: 100, limit: 1000, threshold: 0)
        #expect(abs(kick.pitch - 30) < 1e-9)
        #expect(kick.roll == 0)
    }

    @Test func 上へ振ると上端が奥へ倒れる() {
        let kick = SwayKick.velocity(x: 0, y: 0.1, z: 0, reduceMotion: false, gain: 100, limit: 1000, threshold: 0)
        #expect(abs(kick.pitch - 10) < 1e-9)
    }

    @Test func 強く振っても上限で抑える() {
        let kick = SwayKick.velocity(x: -3, y: 3, z: 0, reduceMotion: false, gain: 100, limit: 50, threshold: 0)
        #expect(kick.pitch == 50)
        #expect(kick.roll == -50)
    }

    @Test func 手の震えほどの勢いは足さない() {
        let kick = SwayKick.velocity(x: 0.01, y: 0.01, z: 0, reduceMotion: false, gain: 100, limit: 1000, threshold: 0.03)
        #expect(kick.pitch == 0 && kick.roll == 0)
    }

    @Test func 視差効果を減らす設定では足さない() {
        let kick = SwayKick.velocity(x: 1, y: 1, z: 1, reduceMotion: true)
        #expect(kick.pitch == 0 && kick.roll == 0)
    }
}

struct WheelSwayStateTests {
    @Test func 最初の読み取りでは時間を進めない() {
        var sway = WheelSway()
        sway.advance(toward: WheelTilt(pitch: 20, roll: 0), at: 5)
        #expect(sway.tilt == .zero)
        #expect(sway.lastTimestamp == 5)
    }

    @Test func 読み取りの時刻の差だけ目標へ寄る() {
        var sway = WheelSway()
        let target = WheelTilt(pitch: 20, roll: -10)
        sway.advance(toward: target, at: 0)
        for step in 1...120 {
            sway.advance(toward: target, at: Double(step) / 60)
        }
        // 周期 0.6 秒・減衰比 0.3 なら 2 秒でほぼ収まる
        #expect(abs(sway.tilt.pitch - 20) < 1)
        #expect(abs(sway.tilt.roll + 10) < 1)
    }

    @Test func 勢いで目標を越えて揺れる() {
        var sway = WheelSway()
        sway.advance(toward: .zero, kick: (pitch: 100, roll: 0), at: 0)
        sway.advance(toward: .zero, at: 0.05)
        #expect(sway.tilt.pitch > 0)
        #expect(!sway.isAtRest(at: .zero))
    }

    @Test func 止めたあとの最初の読み取りでは間の時間を進めない() {
        var sway = WheelSway()
        sway.advance(toward: WheelTilt(pitch: 20, roll: 0), at: 0)
        sway.advance(toward: WheelTilt(pitch: 20, roll: 0), at: 0.05)
        let before = sway.tilt
        sway.pause()
        sway.advance(toward: WheelTilt(pitch: 20, roll: 0), at: 100)
        #expect(sway.tilt == before)
    }

    @Test func 時刻が戻っても進めない() {
        var sway = WheelSway()
        sway.advance(toward: WheelTilt(pitch: 20, roll: 0), at: 1)
        sway.advance(toward: WheelTilt(pitch: 20, roll: 0), at: 0.5)
        #expect(sway.tilt == .zero)
    }
}

struct SwayModeTests {
    @Test func 待機中と回転中は揺らし結果表示中は正面へ戻す() {
        #expect(SwayMode.mode(showingResult: false, reduceMotion: false) == .follow)
        #expect(SwayMode.mode(showingResult: true, reduceMotion: false) == .settle)
    }

    @Test func 視差効果を減らす設定では揺らさない() {
        #expect(SwayMode.mode(showingResult: false, reduceMotion: true) == .still)
        #expect(SwayMode.mode(showingResult: true, reduceMotion: true) == .still)
    }

    @Test func 購読するのは揺らす場面と戻している途中だけ() {
        #expect(SwayMode.follow.subscribes(active: true, atRest: true))
        #expect(SwayMode.settle.subscribes(active: true, atRest: false))
        #expect(!SwayMode.settle.subscribes(active: true, atRest: true))
        #expect(!SwayMode.still.subscribes(active: true, atRest: false))
    }

    @Test func 画面に出ていないか前面でなければ購読しない() {
        for mode in [SwayMode.follow, .settle, .still] {
            #expect(!mode.subscribes(active: false, atRest: false))
        }
    }
}
