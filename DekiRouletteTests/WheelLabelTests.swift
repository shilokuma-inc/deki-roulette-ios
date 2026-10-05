import Testing
@testable import DekiRoulette

struct WheelLabelTests {
    private let reference = WheelLabel.referenceDiameter

    @Test func 基準の直径では仕様の表どおりになる() {
        for count in 2...5 {
            #expect(WheelLabel.limit(count: count, diameter: reference) == 10)
            #expect(WheelLabel.fontSize(count: count, diameter: reference) == 13)
        }
        for count in 6...8 {
            #expect(WheelLabel.limit(count: count, diameter: reference) == 7)
            #expect(WheelLabel.fontSize(count: count, diameter: reference) == 11)
        }
        for count in 9...Config.maxItems {
            #expect(WheelLabel.limit(count: count, diameter: reference) == 5)
            #expect(WheelLabel.fontSize(count: count, diameter: reference) == 9)
        }
    }

    @Test func 項目が1件のときは中央に大きく出す() {
        #expect(WheelLabel.fontSize(count: 1, diameter: reference) == 15)
        #expect(WheelLabel.limit(count: 1, diameter: reference) == 10)
    }

    @Test func 基準より小さい盤面では文字数を変えず文字サイズだけ縮める() {
        let diameter = reference * 0.875
        #expect(WheelLabel.limit(count: 4, diameter: diameter) == 10)
        #expect(WheelLabel.limit(count: 12, diameter: diameter) == 5)
        #expect(WheelLabel.fontSize(count: 4, diameter: diameter) == 13 * 0.875)
        #expect(WheelLabel.fontSize(count: 12, diameter: diameter) == 9 * 0.875)
    }

    @Test func 基準より大きい盤面では文字数と文字サイズを平方根ずつ増やす() {
        // 480pt（iPad の横並び）では倍率 1.5 の平方根 ≒ 1.22
        let diameter = 480.0
        #expect(WheelLabel.limit(count: 4, diameter: diameter) == 12)
        #expect(WheelLabel.limit(count: 7, diameter: diameter) == 8)
        #expect(WheelLabel.limit(count: 12, diameter: diameter) == 6)
        #expect(abs(WheelLabel.fontSize(count: 4, diameter: diameter) - 13 * 1.5.squareRoot()) < 1e-9)
        #expect(abs(WheelLabel.fontSize(count: 12, diameter: diameter) - 9 * 1.5.squareRoot()) < 1e-9)
    }

    @Test func 最長ラベルが盤面に占める割合は基準を超えない() {
        for count in 1...Config.maxItems {
            let baseline = Double(WheelLabel.baseLimit(count: count)) * WheelLabel.baseFontSize(count: count) / reference
            for diameter in stride(from: 80.0, through: 1200.0, by: 20.0) {
                let occupied = Double(WheelLabel.limit(count: count, diameter: diameter))
                    * WheelLabel.fontSize(count: count, diameter: diameter) / diameter
                #expect(occupied <= baseline + 1e-9, "count=\(count) diameter=\(diameter)")
            }
        }
    }

    @Test func 文字数と文字サイズは盤面が大きいほど減らない() {
        for count in [2, 6, 9] {
            var previousLimit = 0
            var previousFont = 0.0
            for diameter in stride(from: 0.0, through: 1200.0, by: 10.0) {
                let limit = WheelLabel.limit(count: count, diameter: diameter)
                let font = WheelLabel.fontSize(count: count, diameter: diameter)
                #expect(limit >= previousLimit)
                #expect(font >= previousFont)
                previousLimit = limit
                previousFont = font
            }
        }
    }

    @Test func 直径0でも落ちない() {
        #expect(WheelLabel.limit(count: 4, diameter: 0) == 10)
        #expect(WheelLabel.fontSize(count: 4, diameter: 0) == 0)
    }

    @Test func 上限を超えるラベルだけ省略記号を付ける() {
        #expect(WheelLabel.truncate("ラーメン大盛りセット", limit: 10) == "ラーメン大盛りセット")
        #expect(WheelLabel.truncate("ラーメン大盛りセット追加", limit: 10) == "ラーメン大盛りセット…")
        // 文字数は Character 単位で数える
        #expect(WheelLabel.truncate("🍜🍛🍣🍖🍕🍔", limit: 5) == "🍜🍛🍣🍖🍕…")
    }
}
