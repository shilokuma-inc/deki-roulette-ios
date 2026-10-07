import Foundation
import Observation

/// 3D の盤を傾けるための端末の姿勢の購読。取得元（`MotionSource`）を差し替えられるようにし、
/// 購読の開始・停止と「画面を開いたときの持ち方」基準の取り直しを持つ。目標の傾きの計算は `TiltMapping` に任せる。
/// 盤の揺れ（`WheelSway`）も持ち、読み取るたびに進めて `tilt` に出す。どの場面で購読するかは View が `update` で
/// 渡す状態（盤面が画面に出ているか・揺らし方 `SwayMode`）から決める。
@MainActor
@Observable
final class WheelMotionModel {
    /// 購読している最中か。
    private(set) var isRunning = false
    /// 直近に読み取った姿勢。購読を止めると捨てる（古い姿勢で傾けない）。
    private(set) var sample: MotionSample?
    /// 「画面を開いたときの持ち方」基準の正面とする重力の向き。購読を止めても残す。
    private(set) var baseline: DeviceGravity?
    /// 盤の今の傾き（ばねで追従・揺れた後）。3D の盤面はこれで傾ける。
    private(set) var tilt = WheelTilt.zero

    @ObservationIgnored private let source: any MotionSource
    @ObservationIgnored private var sway = WheelSway()
    @ObservationIgnored private var mode = SwayMode.follow
    @ObservationIgnored private var reference = TiltReference.default
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

    /// 購読を止める。基準と盤の傾きは残す（再開したら間の時間は進めない）。
    func stop() {
        guard isRunning else { return }
        source.stop()
        isRunning = false
        sample = nil
        sway.pause()
    }

    /// 盤面の状態を渡し、揺らし方と購読の要否を決める。`active` は盤面が画面に出ていてアプリが前面にあること。
    /// 揺らさない（`still`）なら盤を即座に正面に置き、正面へ戻している（`settle`）なら止まるまで購読を続ける。
    func update(active: Bool, mode: SwayMode, reference: TiltReference) {
        self.mode = mode
        self.reference = reference
        if mode == .still {
            sway = WheelSway()
            setTilt(.zero)
        }
        if mode.subscribes(active: active, atRest: sway.isAtRest(at: .zero)) {
            start()
        } else {
            stop()
        }
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
        advanceSway(with: sample)
    }

    private func advanceSway(with sample: MotionSample) {
        switch mode {
        case .follow:
            let kick = SwayKick.velocity(
                x: sample.userAcceleration.x, y: sample.userAcceleration.y, z: sample.userAcceleration.z,
                reduceMotion: false
            )
            sway.advance(toward: targetTilt(reference: reference, reduceMotion: false), kick: kick, at: sample.timestamp)
            setTilt(sway.tilt)
        case .settle:
            sway.advance(toward: .zero, at: sample.timestamp)
            if sway.isAtRest(at: .zero) {
                // 正面で止まったら、正面に揃えて購読も止める（次のスピンか結果が消えたときに再開する）
                sway = WheelSway()
                setTilt(.zero)
                stop()
            } else {
                setTilt(sway.tilt)
            }
        case .still:
            setTilt(.zero)
        }
    }

    /// 変わったときだけ書く（同じ値で盤面を描き直させない）。
    private func setTilt(_ value: WheelTilt) {
        if tilt != value { tilt = value }
    }
}
