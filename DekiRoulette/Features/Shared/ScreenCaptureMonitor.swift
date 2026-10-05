import Combine
import Observation
import UIKit

/// 画面がキャプチャされているかを追いかけて View に配る。`Environment` で両画面へ渡す。
/// キャプチャ中は印を伏せる（`ItemListView`）。判定そのものは `ScreenCaptureSource` に任せる。
@MainActor
@Observable
final class ScreenCaptureMonitor {
    private(set) var isCaptured: Bool

    private let source: any ScreenCaptureSource
    @ObservationIgnored private var subscription: AnyCancellable?

    /// - Parameters:
    ///   - source: キャプチャ状態の取得元。
    ///   - notificationCenter: 変化の通知を受け取る先。テストでは専用のインスタンスを渡す。
    ///   - notificationName: 変化を知らせる通知名。既定は `UIScreen.capturedDidChangeNotification`。
    init(
        source: any ScreenCaptureSource,
        notificationCenter: NotificationCenter = .default,
        notificationName: Notification.Name = UIScreen.capturedDidChangeNotification
    ) {
        self.source = source
        self.isCaptured = source.isCaptured
        // 通知は取得元が変わったことだけを知らせるので、値は毎回読み直す
        subscription = notificationCenter.publisher(for: notificationName)
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refresh() }
    }

    /// 取得元の値を読み直す。通知を待たずに同期したいときにも使う。
    func refresh() {
        isCaptured = source.isCaptured
    }
}

/// `UIScreen` を取得元にする。`UIScreen.main` は非推奨なので、接続中のシーンの画面から読む。
/// どれか 1 つでもキャプチャされていれば「キャプチャ中」とみなす。
@MainActor
final class UIScreenCaptureSource: ScreenCaptureSource {
    var isCaptured: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .contains { $0.isCaptured }
    }
}
