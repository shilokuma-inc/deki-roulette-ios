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
