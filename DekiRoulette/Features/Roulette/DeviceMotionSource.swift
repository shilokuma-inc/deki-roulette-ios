import CoreMotion

/// `CMMotionManager.deviceMotion` を取得元にする。許可ダイアログも Info.plist の追加も要らない。
/// 姿勢を読めない端末（シミュレータなど）では何も渡さない。
@MainActor
final class DeviceMotionSource: MotionSource {
    private let manager = CMMotionManager()

    func start(interval: TimeInterval, handler: @escaping @MainActor (MotionSample) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = interval
        // メインキューに届けるので、受け取ったその場でメインアクタの handler を呼べる
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let sample = MotionSample(
                gravity: DeviceGravity(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z),
                userAcceleration: DeviceGravity(
                    x: motion.userAcceleration.x,
                    y: motion.userAcceleration.y,
                    z: motion.userAcceleration.z
                ),
                timestamp: motion.timestamp
            )
            MainActor.assumeIsolated { handler(sample) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
