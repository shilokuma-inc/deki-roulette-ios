import Foundation

/// 止まったスライスに付ける外側への光彩の色。設定の「ルーレットの詳細設定」で選び、`Config.glowStyleKey` に保存する。
/// 保存値は `rawValue` なので、名前を変えるときは保存済みの値が読めなくなる（既定に戻る）ことに注意する。
enum GlowStyle: String, CaseIterable, Sendable {
    /// 白系。縁取りと同じ色。
    case white
    /// 止まったスライスの塗りと同じ色。
    case slice
    /// スライスの 10 色を色相順に並べた虹色。新しい色は足さない。
    case rainbow

    /// 未設定のときの値。
    static let `default` = GlowStyle.white
}
