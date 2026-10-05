import Foundation

/// 印を出すかどうかの判定。Web 版 `ItemList` の `revealMarks` に対応する。
enum MarkVisibility {
    /// 印は「伏せていない」「画面がキャプチャされていない」を満たしたうえで、
    /// 行を押している間か指定直後だけ出す。
    static func reveals(concealed: Bool, captured: Bool, pressing: Bool, hinting: Bool) -> Bool {
        !concealed && !captured && (pressing || hinting)
    }
}
