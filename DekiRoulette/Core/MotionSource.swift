import Foundation

/// 端末の姿勢の 1 回分の読み取り（`CMDeviceMotion` から必要な値だけを写したもの）。
struct MotionSample: Equatable, Sendable {
    /// 重力の向き（g）。傾きの写像（`TiltMapping`）に使う。
    var gravity: DeviceGravity
    /// 重力を除いた加速度（g）。端末を動かした勢い（`SwayKick`）に使う。座標系は `gravity` と同じ。
    var userAcceleration: DeviceGravity
    /// 読み取った時刻（秒）。更新の間隔からばねを進める時間を求める。
    var timestamp: TimeInterval
}

/// 端末の姿勢の取得元。実機は `CMMotionManager`（`DeviceMotionSource`）だが、
/// シミュレータにはジャイロが無いので、Simulator・テストでは `ManualMotionSource` に差し替えて姿勢を流し込む。
@MainActor
protocol MotionSource: AnyObject {
    /// `interval` 秒ごとに `handler` へ姿勢を渡し始める。既に始めていれば何もしない。
    func start(interval: TimeInterval, handler: @escaping @MainActor (MotionSample) -> Void)
    /// 姿勢を渡すのをやめる。
    func stop()
}

/// 姿勢を手で流し込む取得元。シミュレータでの確認とテストに使う。
@MainActor
final class ManualMotionSource: MotionSource {
    private var handler: (@MainActor (MotionSample) -> Void)?
    /// 直近の `start` で渡された更新間隔。
    private(set) var interval: TimeInterval?

    /// 姿勢を渡している最中か。
    var isRunning: Bool { handler != nil }

    func start(interval: TimeInterval, handler: @escaping @MainActor (MotionSample) -> Void) {
        guard self.handler == nil else { return }
        self.interval = interval
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    /// 姿勢を 1 回分流し込む。止まっている間は捨てる。
    func send(_ sample: MotionSample) {
        handler?(sample)
    }
}
