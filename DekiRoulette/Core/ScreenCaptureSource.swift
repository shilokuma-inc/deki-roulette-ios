import Foundation

/// 画面がキャプチャ（画面収録・AirPlay ミラーリング・QuickTime への出力）されているかの取得元。
/// 実体は `UIScreen` だが、シミュレータでは再現しづらいのでテストでは差し替える。
@MainActor
protocol ScreenCaptureSource: AnyObject {
    /// 今キャプチャされているか。
    var isCaptured: Bool { get }
}
