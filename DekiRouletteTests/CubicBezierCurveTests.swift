import Testing
@testable import DekiRoulette

struct CubicBezierCurveTests {
    private let spin = Config.spinEasing
    private let linear = CubicBezierCurve(0.25, 0.25, 0.75, 0.75)

    @Test func 端点は0と1() {
        #expect(abs(spin.progress(atTime: 0)) < 1e-9)
        #expect(abs(spin.progress(atTime: 1) - 1) < 1e-9)
        #expect(abs(spin.time(atProgress: 0)) < 1e-9)
        #expect(abs(spin.time(atProgress: 1) - 1) < 1e-9)
    }

    @Test func 対角線上の制御点なら恒等写像() {
        for step in 0...20 {
            let t = Double(step) / 20
            #expect(abs(linear.progress(atTime: t) - t) < 1e-6)
            #expect(abs(linear.time(atProgress: t) - t) < 1e-6)
        }
    }

    @Test func スピンの曲線は前半で大きく進んで減速する() {
        // 半分の時刻で 9 割以上進んでいる（cubic-bezier(0.15, 0.85, 0.3, 1) は強いイーズアウト）
        #expect(spin.progress(atTime: 0.5) > 0.9)
        // 序盤の傾きは終盤より大きい
        let early = spin.progress(atTime: 0.1) - spin.progress(atTime: 0)
        let late = spin.progress(atTime: 1) - spin.progress(atTime: 0.9)
        #expect(early > late * 10)
    }

    @Test func 進み具合は時刻に対して単調増加() {
        var previous = -1.0
        for step in 0...100 {
            let value = spin.progress(atTime: Double(step) / 100)
            #expect(value >= previous)
            previous = value
        }
    }

    @Test func 時刻と進み具合は互いに逆関数() {
        for step in 1..<20 {
            let t = Double(step) / 20
            #expect(abs(spin.time(atProgress: spin.progress(atTime: t)) - t) < 1e-6)
        }
    }

    @Test func 範囲外の入力は端に丸める() {
        #expect(abs(spin.progress(atTime: -0.5)) < 1e-9)
        #expect(abs(spin.progress(atTime: 1.5) - 1) < 1e-9)
    }
}
