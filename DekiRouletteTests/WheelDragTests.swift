import CoreGraphics
import Foundation
import Testing
@testable import DekiRoulette

struct WheelDragTests {
    private let center = CGPoint(x: 160, y: 160)

    /// 中心から `radius` の円周上で、3 時を 0 度・画面上の時計回りを正とする角度 `degrees` の点。
    private func point(_ degrees: Double, radius: CGFloat = 100) -> CGPoint {
        let rad = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
    }

    @Test func 時計回りに動かすと正の角度だけ回す() {
        let delta = WheelDrag.rotationDelta(from: point(-90), to: point(-60), center: center)
        #expect(abs(delta - 30) < 1e-9)
    }

    @Test func 反時計回りに動かすと負の角度だけ回す() {
        let delta = WheelDrag.rotationDelta(from: point(10), to: point(-35), center: center)
        #expect(abs(delta + 45) < 1e-9)
    }

    @Test func 中心からの距離に依らず回った角度だけ回す() {
        let near = WheelDrag.rotationDelta(from: point(0, radius: 40), to: point(20, radius: 40), center: center)
        let far = WheelDrag.rotationDelta(from: point(0, radius: 150), to: point(20, radius: 40), center: center)
        #expect(abs(near - 20) < 1e-9)
        #expect(abs(far - 20) < 1e-9)
    }

    @Test func 九時をまたいでも一周分跳ねない() {
        // atan2 が ±180 度で折り返す位置（9 時）を時計回り・反時計回りにまたぐ
        #expect(abs(WheelDrag.rotationDelta(from: point(170), to: point(190), center: center) - 20) < 1e-9)
        #expect(abs(WheelDrag.rotationDelta(from: point(190), to: point(170), center: center) + 20) < 1e-9)
    }

    @Test func 半径方向の動きでは回さない() {
        #expect(abs(WheelDrag.rotationDelta(from: point(45, radius: 40), to: point(45, radius: 150), center: center)) < 1e-9)
    }

    @Test func 中心付近の点を含む区間では回さない() {
        let inside = Config.flickDeadZoneRadius - 1
        #expect(WheelDrag.rotationDelta(from: point(0, radius: inside), to: point(90), center: center) == 0)
        #expect(WheelDrag.rotationDelta(from: point(0), to: point(90, radius: inside), center: center) == 0)
        #expect(WheelDrag.rotationDelta(from: center, to: center, center: center) == 0)
    }

    @Test func 両端が外でも中心付近を横切る区間では回さない() {
        // 中心の左右 30pt を 1 区間で結ぶ。端だけで見ると 180 度回ったことになる
        let outside = Config.flickDeadZoneRadius + 6
        #expect(WheelDrag.rotationDelta(from: point(180, radius: outside), to: point(0, radius: outside), center: center) == 0)
    }

    @Test func 中心付近を横切らない区間は端が近くても回す() {
        // 弦が中心から不感帯の半径より離れていれば、端の点が内側に寄っていても角度どおりに回す
        let delta = WheelDrag.rotationDelta(from: point(-10, radius: 40), to: point(10, radius: 40), center: center)
        #expect(abs(delta - 20) < 1e-9)
    }

    @Test func 中心付近を通り抜けても抜けた先から追従する() {
        // 9 時から中心を通って 3 時へ抜ける。中心付近の区間は数えないので、盤面は 180 度跳ねない
        let path = [point(180), point(180, radius: 30), center, point(0, radius: 30), point(0), point(20)]
        let total = zip(path, path.dropFirst()).reduce(0.0) { sum, pair in
            sum + WheelDrag.rotationDelta(from: pair.0, to: pair.1, center: center)
        }
        #expect(abs(total - 20) < 1e-9)
    }

    @Test func 細かく動かした合計は回った角度に等しい() {
        // 時計回りに 2 周と 30 度、1 度ずつ動かす。累積で 360 度を超えても失わない
        let path = stride(from: -90.0, through: -90 + 750, by: 1).map { point($0) }
        let total = zip(path, path.dropFirst()).reduce(0.0) { sum, pair in
            sum + WheelDrag.rotationDelta(from: pair.0, to: pair.1, center: center)
        }
        #expect(abs(total - 750) < 1e-6)
    }

    // MARK: 境目

    @Test func 境目を越えた数を向きに依らず数える() {
        // 4 項目なので境目は 90 度ごと
        #expect(WheelDrag.boundaryCrossings(from: 80, to: 100, count: 4) == 1)
        #expect(WheelDrag.boundaryCrossings(from: 100, to: 80, count: 4) == 1)
        #expect(WheelDrag.boundaryCrossings(from: 10, to: 80, count: 4) == 0)
        #expect(WheelDrag.boundaryCrossings(from: 10, to: 280, count: 4) == 3)
    }

    @Test func 負の累積角でも境目を数える() {
        #expect(WheelDrag.boundaryCrossings(from: 5, to: -5, count: 4) == 1)
        #expect(WheelDrag.boundaryCrossings(from: -95, to: -85, count: 4) == 1)
        #expect(WheelDrag.boundaryCrossings(from: -1000, to: -1000 - 360, count: 6) == 6)
    }

    @Test func 項目が1件以下なら境目は無い() {
        #expect(WheelDrag.boundaryCrossings(from: 0, to: 720, count: 1) == 0)
        #expect(WheelDrag.boundaryCrossings(from: 0, to: 720, count: 0) == 0)
    }

    @Test func 詰まった境目の音と触覚を間引く() {
        var throttle = WheelDrag.FeedbackThrottle()
        let click = Config.clickMinInterval
        let haptic = Config.hapticMinInterval
        #expect(throttle.cross(at: 10) == (click: true, haptic: true))
        // 回転音の間隔は空いたが、触覚の間隔はまだ空いていない
        let afterClick = 10 + click * 1.1
        #expect(throttle.cross(at: afterClick) == (click: true, haptic: false))
        #expect(throttle.cross(at: afterClick + click * 0.5) == (click: false, haptic: false))
        // 鳴らさなかった境目は間隔の起点にしない
        #expect(throttle.cross(at: 10 + max(haptic, click * 1.1 + click) * 1.1) == (click: true, haptic: true))
    }
}
