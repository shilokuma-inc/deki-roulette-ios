import CoreGraphics

/// 項目の行を左にスワイプして削除するときの判定。行は `ScrollView` 内に並べていて `List` ではないので、
/// `.swipeActions` を使わずに自前で持つ。オフセットは左向きを負で表す。
enum SwipeToDelete {
    enum Outcome: Equatable {
        case closed
        /// 右端の削除ボタンを出したまま止める。
        case open
        /// 行幅の `Config.swipeDeleteRatio` を越えて引いたので、そのまま削除する。
        case delete
    }

    /// 指が動き始めた向きで、横のスワイプか縦のスクロールかを決める。斜めは縦に譲る。
    static func isHorizontal(_ width: CGFloat, _ height: CGFloat) -> Bool {
        abs(width) > abs(height)
    }

    /// 指に追従させるオフセット。右には開かず、左は行幅までで止める。
    static func offset(translation: CGFloat, wasOpen: Bool, actionWidth: CGFloat, rowWidth: CGFloat) -> CGFloat {
        let start = wasOpen ? -actionWidth : 0
        return min(0, max(-rowWidth, start + translation))
    }

    /// 指を離したときの行き先。削除は実際に引いた量だけで決め、勢いだけでは消さない。
    /// 開くか閉じるかは、離した勢いを足した予測位置が削除ボタンの半分を越えるかで決める。
    static func outcome(offset: CGFloat, predictedOffset: CGFloat, actionWidth: CGFloat, rowWidth: CGFloat) -> Outcome {
        if -offset > rowWidth * Config.swipeDeleteRatio { return .delete }
        return -predictedOffset > actionWidth / 2 ? .open : .closed
    }
}
