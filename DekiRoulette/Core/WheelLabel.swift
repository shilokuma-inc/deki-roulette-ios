import Foundation

/// 盤面ラベルの省略と文字サイズ。Web 版 `RouletteWheel.tsx` の `maxLabelLen` / `fontSize` に対応し、
/// 盤面が基準より大きいとき（iPad の横並び）の緩め方を加えている。
///
/// ラベルは半径方向に置くので、収まる長さは直径に比例する。文字サイズも直径に比例させると
/// 収まる文字数は変わらず、文字数だけ増やすと縁からはみ出す。そこで基準より大きい盤面では
/// 増えた分を文字サイズと文字数に等分し（それぞれ倍率の平方根）、最長のラベルが盤面に占める
/// 割合を基準と同じに保つ。基準より小さい盤面は従来どおり文字サイズだけを縮める。
enum WheelLabel {
    /// 基準になる盤面の直径（pt）。Web 版の 320px で、この大きさのとき §5.1 の表どおりになる。
    static let referenceDiameter: Double = 320

    /// 基準の直径での最大表示文字数（§5.1 の表）。
    static func baseLimit(count: Int) -> Int {
        count > 8 ? 5 : count > 5 ? 7 : 10
    }

    /// 基準の直径でのフォントサイズ（§5.1 の表）。1 件だけのときは中央に大きく出す。
    static func baseFontSize(count: Int) -> Double {
        count == 1 ? 15 : count > 8 ? 9 : count > 5 ? 11 : 13
    }

    /// 盤面の直径に応じた最大表示文字数。基準以下では表のまま、基準より大きいと平方根で増やす。
    static func limit(count: Int, diameter: Double) -> Int {
        let ratio = max(0, diameter) / referenceDiameter
        return Int((Double(baseLimit(count: count)) * max(1, ratio).squareRoot()).rounded(.down))
    }

    /// 盤面の直径に応じたフォントサイズ。基準以下では直径に比例して縮め、基準より大きいと平方根で増やす。
    static func fontSize(count: Int, diameter: Double) -> Double {
        let ratio = max(0, diameter) / referenceDiameter
        return baseFontSize(count: count) * min(ratio, ratio.squareRoot())
    }

    /// `limit` 文字を超えるラベルを切って省略記号を付ける。Web 版 `truncate` と同じ。
    static func truncate(_ label: String, limit: Int) -> String {
        label.count > limit ? String(label.prefix(limit)) + "…" : label
    }
}
