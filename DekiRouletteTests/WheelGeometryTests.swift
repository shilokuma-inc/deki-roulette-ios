import Foundation
import Testing
@testable import DekiRoulette

struct WheelGeometryTests {
    private func isClose(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Bool {
        abs(a.x - b.x) < 1e-9 && abs(a.y - b.y) < 1e-9
    }

    @Test func 零度は12時() {
        #expect(isClose(WheelGeometry.point(angle: 0, radius: 10), SIMD2(0, 10)))
    }

    /// 2D と同じく、手前から見て時計回りに進む（90 度で 3 時、180 度で 6 時）。
    @Test func 角度は手前から見て時計回り() {
        #expect(isClose(WheelGeometry.point(angle: 90, radius: 10), SIMD2(10, 0)))
        #expect(isClose(WheelGeometry.point(angle: 180, radius: 10), SIMD2(0, -10)))
        #expect(isClose(WheelGeometry.point(angle: 270, radius: 10), SIMD2(-10, 0)))
    }

    @Test func 外周は両端を含めて等分する() {
        let points = WheelGeometry.arc(start: 0, end: 90, radius: 10, segmentsPerTurn: 8)
        #expect(points.count == 3)
        #expect(isClose(points[0], SIMD2(0, 10)))
        #expect(isClose(points[1], WheelGeometry.point(angle: 45, radius: 10)))
        #expect(isClose(points[2], SIMD2(10, 0)))
    }

    @Test func 細いスライスでも最低1区間() {
        let points = WheelGeometry.arc(start: 10, end: 11, radius: 10, segmentsPerTurn: 8)
        #expect(points.count == 2)
    }

    @Test func 外周の点は半径の上にある() {
        for point in WheelGeometry.arc(start: 30, end: 200, radius: 7) {
            #expect(abs((point.x * point.x + point.y * point.y).squareRoot() - 7) < 1e-9)
        }
    }

    /// 2D の `rotationEffect`（時計回りが正）と同じ向きに回るよう、z 軸まわり（反時計回りが正）では符号を返す。
    @Test func 回転角はz軸まわりでは符号を返す() {
        #expect(abs(WheelGeometry.spinAngle(rotation: 90) + .pi / 2) < 1e-12)
        #expect(abs(WheelGeometry.spinAngle(rotation: -180) - .pi) < 1e-12)
        #expect(WheelGeometry.spinAngle(rotation: 0) == 0)
    }

    /// 回した盤の 12 時にあった点は、回転角だけ時計回りに進んだところへ動く。
    @Test func 回した盤の点は時計回りに進む() {
        let angle = WheelGeometry.spinAngle(rotation: 90)
        let top = WheelGeometry.point(angle: 0, radius: 10)
        let rotated = SIMD2(top.x * cos(angle) - top.y * sin(angle), top.x * sin(angle) + top.y * cos(angle))
        #expect(isClose(rotated, WheelGeometry.point(angle: 90, radius: 10)))
    }

    @Test func カメラの距離は画角に収まる長さ() {
        let distance = WheelGeometry.cameraDistance(diameter: 200, fieldOfView: 90)
        #expect(abs(distance - 100) < 1e-9)
        #expect(WheelGeometry.cameraDistance(diameter: 200, fieldOfView: 30) > distance)
    }
}
