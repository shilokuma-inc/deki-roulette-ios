import Foundation
import Testing
@testable import DekiRoulette

@MainActor
private final class FakeCaptureSource: ScreenCaptureSource {
    var isCaptured: Bool
    init(isCaptured: Bool) { self.isCaptured = isCaptured }
}

@MainActor
struct ScreenCaptureMonitorTests {
    private let center = NotificationCenter()
    private let name = Notification.Name("test.capturedDidChange")

    private func makeMonitor(source: FakeCaptureSource) -> ScreenCaptureMonitor {
        ScreenCaptureMonitor(source: source, notificationCenter: center, notificationName: name)
    }

    /// 通知は `RunLoop.main` 経由で届くので、1 周回してから読む。
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(50))
    }

    @Test func 初期値は取得元の値() {
        #expect(makeMonitor(source: FakeCaptureSource(isCaptured: false)).isCaptured == false)
        #expect(makeMonitor(source: FakeCaptureSource(isCaptured: true)).isCaptured == true)
    }

    @Test func 通知が来ると取得元の値を読み直す() async throws {
        let source = FakeCaptureSource(isCaptured: false)
        let monitor = makeMonitor(source: source)

        source.isCaptured = true
        center.post(name: name, object: nil)
        try await settle()
        #expect(monitor.isCaptured == true)

        source.isCaptured = false
        center.post(name: name, object: nil)
        try await settle()
        #expect(monitor.isCaptured == false)
    }

    @Test func 別の通知では変わらない() async throws {
        let source = FakeCaptureSource(isCaptured: false)
        let monitor = makeMonitor(source: source)
        source.isCaptured = true
        center.post(name: Notification.Name("test.other"), object: nil)
        try await settle()
        #expect(monitor.isCaptured == false)
    }

    @Test func 通知を待たずに読み直せる() {
        let source = FakeCaptureSource(isCaptured: false)
        let monitor = makeMonitor(source: source)
        source.isCaptured = true
        monitor.refresh()
        #expect(monitor.isCaptured == true)
    }
}
