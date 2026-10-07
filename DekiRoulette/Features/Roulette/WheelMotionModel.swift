import Foundation
import Observation

/// 3D の盤を傾けるための端末の姿勢の購読。取得元（`MotionSource`）を差し替えられるようにし、
/// 購読の開始・停止と「画面を開いたときの持ち方」基準の取り直しを持つ。目標の傾きの計算は `TiltMapping` に任せる。
/// どの場面で購読するか（盤面が出ている間・揺らす場面だけ）は View が `start` / `stop` で決める。
@MainActor
@Observable
final class WheelMotionModel {
    /// 購読している最中か。
    private(set) var isRunning = false
    /// 直近に読み取った姿勢。購読を止めると捨てる（古い姿勢で傾けない）。
    private(set) var sample: MotionSample?
    /// 「画面を開いたときの持ち方」基準の正面とする重力の向き。購読を止めても残す。
    private(set) var baseline: DeviceGravity?

    @ObservationIgnored private let source: any MotionSource
    /// 次に読み取った姿勢を基準にする。
    @ObservationIgnored private var capturesNextSample = false

    init(source: any MotionSource) {
        self.source = source
    }

    /// 購読を始める。`recapturingBaseline` なら、始めて最初に読み取った姿勢を基準に取り直す。
    /// 基準がまだ無いときは、指定に依らず最初の姿勢を基準にする。既に購読していれば基準の取り直しだけを行う。
    func start(recapturingBaseline: Bool = false, interval: TimeInterval = Config.motionUpdateInterval) {
        if recapturingBaseline { recaptureBaseline() }
        guard !isRunning else { return }
        isRunning = true
        source.start(interval: interval) { [weak self] sample in
            self?.receive(sample)
        }
    }

    /// 購読を止める。基準は残す。
    func stop() {
        guard isRunning else { return }
        source.stop()
        isRunning = false
        sample = nil
    }

    /// 次に読み取った姿勢を基準にする（今の姿勢は古いことがあるので使わない）。
    func recaptureBaseline() {
        capturesNextSample = true
    }

    /// 盤の目標の傾き。姿勢をまだ読み取っていないときは正面。
    func targetTilt(reference: TiltReference, reduceMotion: Bool) -> WheelTilt {
        guard let sample else { return .zero }
        let front: DeviceGravity? = switch reference {
        case .flat: .flat
        case .grip: baseline
        }
        return TiltMapping.target(gravity: sample.gravity, baseline: front, reduceMotion: reduceMotion)
    }

    private func receive(_ sample: MotionSample) {
        guard isRunning else { return }
        if capturesNextSample || baseline == nil {
            baseline = sample.gravity
            capturesNextSample = false
        }
        self.sample = sample
    }
}
