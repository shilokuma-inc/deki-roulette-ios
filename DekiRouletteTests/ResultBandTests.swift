import Testing
@testable import DekiRoulette

struct ResultBandTests {
    @Test func 基準の直径では基準の文字サイズになる() {
        #expect(ResultBand.fontSize(diameter: WheelLabel.referenceDiameter) == ResultBand.baseFontSize)
    }

    @Test func 文字サイズと幅は直径に比例する() {
        #expect(ResultBand.fontSize(diameter: 480) == ResultBand.baseFontSize * 1.5)
        #expect(ResultBand.maxWidth(diameter: 480) == 480 * ResultBand.maxWidthRatio)
    }

    @Test(arguments: [200.0, 320, 480])
    func 帯は沈んだ針の先より下に置く(diameter: Double) {
        let bounce = 4.0
        #expect(ResultBand.top(diameter: diameter, pointerBounce: bounce) > ResultBand.pointerBottom + bounce)
    }

    @Test func 帯は盤面のラベルより大きい文字で出す() {
        for count in 1...Config.maxItems {
            #expect(ResultBand.fontSize(diameter: 320) > WheelLabel.fontSize(count: count, diameter: 320))
        }
    }

    @Test func 負の直径は0として扱う() {
        #expect(ResultBand.fontSize(diameter: -10) == 0)
        #expect(ResultBand.maxWidth(diameter: -10) == 0)
    }
}
