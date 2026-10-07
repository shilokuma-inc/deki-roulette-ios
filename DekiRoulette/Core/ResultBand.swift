import Foundation

/// 結果が出ている間、盤面の針のすぐ下に重ねる帯の寸法。盤面と同じく Dynamic Type には追従させず、直径に比例させる。
///
/// 針は盤面の上端から一定の大きさ（`pointerBottom`）で垂れ下がり、停止の瞬間に `pointerBounce` だけ沈む。
/// 帯はその下に `gap` を空けて置き、針と重ならないようにする。
enum ResultBand {
    /// 基準の直径での文字サイズ（pt）。盤面のラベル（最大 15pt）より大きくして結果を読ませる。
    static let baseFontSize: Double = 17
    /// 収まらないときに縮める下限の倍率。それでも収まらなければ末尾を省略する。
    static let minimumScaleFactor: Double = 0.5
    /// 帯の幅の上限（直径に対する割合）。12 時付近の盤面の幅に収める。
    static let maxWidthRatio: Double = 0.72
    /// 盤面の上端から針の先までの高さ（pt）。`RouletteWheelView` の針（高さ 26pt、上に 6pt はみ出す）と同じ。
    static let pointerBottom: Double = 20
    /// 帯と針の先の間隔（基準の直径での pt）。
    static let baseGap: Double = 8

    private static func ratio(_ diameter: Double) -> Double {
        max(0, diameter) / WheelLabel.referenceDiameter
    }

    /// 文字サイズ（pt）。
    static func fontSize(diameter: Double) -> Double {
        baseFontSize * ratio(diameter)
    }

    /// 帯の幅の上限（pt）。
    static func maxWidth(diameter: Double) -> Double {
        max(0, diameter) * maxWidthRatio
    }

    /// 盤面の上端から帯の上端までの距離（pt）。針が沈んだときの先端（`pointerBounce` 込み）より下に置く。
    static func top(diameter: Double, pointerBounce: Double) -> Double {
        pointerBottom + pointerBounce + baseGap * ratio(diameter)
    }
}
