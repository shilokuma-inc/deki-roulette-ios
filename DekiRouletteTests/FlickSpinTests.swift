import CoreGraphics
import Testing
@testable import DekiRoulette

struct FlickSpinTests {
    private let center = CGPoint(x: 160, y: 160)

    // MARK: 角速度

    @Test func 右側で下向きに動かすと時計回りで正になる() {
        // 半径 100pt の位置で接線方向に 100pt/秒 → 1 rad/秒
        let velocity = FlickSpin.angularVelocity(
            location: CGPoint(x: 260, y: 160),
            velocity: CGSize(width: 0, height: 100),
            center: center
        )
        #expect(abs(velocity - 180 / .pi) < 1e-9)
    }

    @Test func 上側で左向きに動かすと反時計回りで負になる() {
        let velocity = FlickSpin.angularVelocity(
            location: CGPoint(x: 160, y: 60),
            velocity: CGSize(width: -100, height: 0),
            center: center
        )
        #expect(abs(velocity + 180 / .pi) < 1e-9)
    }

    @Test func 半径方向の動きは角速度にならない() {
        let velocity = FlickSpin.angularVelocity(
            location: CGPoint(x: 260, y: 160),
            velocity: CGSize(width: 500, height: 0),
            center: center
        )
        #expect(velocity == 0)
    }

    @Test func 中心付近は無視する() {
        let inside = CGPoint(x: center.x + Config.flickDeadZoneRadius - 1, y: center.y)
        let velocity = FlickSpin.angularVelocity(location: inside, velocity: CGSize(width: 0, height: 3000), center: center)
        #expect(velocity == 0)
    }

    @Test func 同じ速さなら半径が小さいほど角速度が大きい() {
        let near = FlickSpin.angularVelocity(location: CGPoint(x: 210, y: 160), velocity: CGSize(width: 0, height: 100), center: center)
        let far = FlickSpin.angularVelocity(location: CGPoint(x: 310, y: 160), velocity: CGSize(width: 0, height: 100), center: center)
        #expect(near > far)
        #expect(abs(near / far - 3) < 1e-9)
    }

    // MARK: 周回数

    @Test func 閾値未満では回さない() {
        #expect(FlickSpin.fullSpins(angularVelocity: 0) == nil)
        #expect(FlickSpin.fullSpins(angularVelocity: Config.flickMinAngularVelocity - 1) == nil)
        #expect(FlickSpin.fullSpins(angularVelocity: -(Config.flickMinAngularVelocity - 1)) == nil)
    }

    @Test func 閾値ちょうどで最小の周回数になる() {
        #expect(FlickSpin.fullSpins(angularVelocity: Config.flickMinAngularVelocity) == Config.fullSpinRange.lowerBound)
    }

    @Test func 上限以上は最大の周回数で頭打ちになる() {
        #expect(FlickSpin.fullSpins(angularVelocity: Config.flickMaxAngularVelocity) == Config.fullSpinRange.upperBound)
        #expect(FlickSpin.fullSpins(angularVelocity: Config.flickMaxAngularVelocity * 10) == Config.fullSpinRange.upperBound)
    }

    @Test func 反時計回りのフリックでも速さだけを見る() {
        for speed in stride(from: Config.flickMinAngularVelocity, through: Config.flickMaxAngularVelocity, by: 100) {
            #expect(FlickSpin.fullSpins(angularVelocity: speed) == FlickSpin.fullSpins(angularVelocity: -speed))
        }
    }

    @Test func 速いほど周回数は減らない() throws {
        var previous = Config.fullSpinRange.lowerBound
        for speed in stride(from: Config.flickMinAngularVelocity, through: Config.flickMaxAngularVelocity + 500, by: 10) {
            let spins = try #require(FlickSpin.fullSpins(angularVelocity: speed))
            #expect(Config.fullSpinRange.contains(spins))
            #expect(spins >= previous)
            previous = spins
        }
    }
}
