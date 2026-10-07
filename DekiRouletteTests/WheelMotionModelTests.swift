import Foundation
import Testing
@testable import DekiRoulette

@MainActor
struct WheelMotionModelTests {
    private let source = ManualMotionSource()

    /// 画面の横軸まわりに `degrees` だけ起こした姿勢（0 で水平、90 で縦）。
    private func raised(_ degrees: Double, at timestamp: TimeInterval = 0) -> MotionSample {
        let rad = degrees * .pi / 180
        return MotionSample(
            gravity: DeviceGravity(x: 0, y: -sin(rad), z: -cos(rad)),
            userAcceleration: DeviceGravity(x: 0, y: 0, z: 0),
            timestamp: timestamp
        )
    }

    private func pitch(_ model: WheelMotionModel, _ reference: TiltReference) -> Double {
        model.targetTilt(reference: reference, reduceMotion: false).pitch
    }

    // MARK: 購読の開始・停止

    @Test func 始めるまでは購読しない() {
        let model = WheelMotionModel(source: source)
        #expect(!model.isRunning)
        #expect(!source.isRunning)
        source.send(raised(10))
        #expect(model.sample == nil)
    }

    @Test func 始めると取得元から姿勢を受け取る() {
        let model = WheelMotionModel(source: source)
        model.start()
        #expect(model.isRunning)
        #expect(source.isRunning)
        #expect(source.interval == Config.motionUpdateInterval)
        source.send(raised(10, at: 1))
        #expect(model.sample == raised(10, at: 1))
    }

    @Test func 止めると取得元も止めて姿勢を捨てる() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(10))
        model.stop()
        #expect(!model.isRunning)
        #expect(!source.isRunning)
        #expect(model.sample == nil)
        #expect(model.targetTilt(reference: .flat, reduceMotion: false) == .zero)
    }

    @Test func 二重に始めても取得元は一度だけ始める() {
        let model = WheelMotionModel(source: source)
        model.start(interval: 0.5)
        model.start(interval: 0.1)
        #expect(source.interval == 0.5)
    }

    // MARK: 目標の傾き

    @Test func 姿勢を読むまでは正面() {
        let model = WheelMotionModel(source: source)
        model.start()
        #expect(model.targetTilt(reference: .flat, reduceMotion: false) == .zero)
        #expect(model.targetTilt(reference: .grip, reduceMotion: false) == .zero)
    }

    @Test func 水平基準では重力の向きで傾く() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(10))
        #expect(abs(pitch(model, .flat) - 10) < 1e-9)
    }

    @Test func 視差効果を減らす設定では正面() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(10))
        #expect(model.targetTilt(reference: .flat, reduceMotion: true) == .zero)
    }

    // MARK: 基準の取り直し

    @Test func 最初に読んだ姿勢を持ち方の基準にする() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(60))
        #expect(abs(pitch(model, .grip)) < 1e-9)
        source.send(raised(70))
        #expect(abs(pitch(model, .grip) - 10) < 1e-9)
    }

    @Test func 止めても基準は残す() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(60))
        model.stop()
        model.start()
        source.send(raised(70))
        #expect(model.baseline == raised(60).gravity)
        #expect(abs(pitch(model, .grip) - 10) < 1e-9)
    }

    @Test func 取り直して始めると次の姿勢を基準にする() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(60))
        model.stop()
        model.start(recapturingBaseline: true)
        source.send(raised(30))
        #expect(model.baseline == raised(30).gravity)
        #expect(abs(pitch(model, .grip)) < 1e-9)
    }

    @Test func 購読中に取り直すと次の姿勢を基準にする() {
        let model = WheelMotionModel(source: source)
        model.start()
        source.send(raised(60))
        model.recaptureBaseline()
        #expect(model.baseline == raised(60).gravity)
        source.send(raised(45))
        #expect(model.baseline == raised(45).gravity)
        source.send(raised(50))
        #expect(model.baseline == raised(45).gravity)
        #expect(abs(pitch(model, .grip) - 5) < 1e-9)
    }
}
