import Foundation

/// 3D 表示の盤をどの姿勢を基準に傾けるか。設定の「ルーレットの詳細設定」で選び、`Config.tiltReferenceKey` に保存する。
/// 保存値は `rawValue` なので、名前を変えるときは保存済みの値が読めなくなる（既定に戻る）ことに注意する。
enum TiltReference: String, CaseIterable, Sendable {
    /// 机に水平に置いた状態を正面とし、重力の向きで傾ける。手で起こすと盤が奥へ倒れて見える。
    case flat
    /// 画面を開いたときの持ち方を正面とし、そこからの姿勢の変化で傾ける。
    case grip

    /// 未設定のときの値。
    static let `default` = TiltReference.flat
}
