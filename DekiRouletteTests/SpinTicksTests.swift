import Testing
@testable import DekiRoulette

struct SpinTicksTests {
    private let easing = Config.spinEasing

    private func crossings(
        from: Double = 0,
        to: Double,
        count: Int,
        duration: Double = Config.spinDuration,
        minInterval: Double = 0
    ) -> [Double] {
        SpinTicks.boundaryCrossings(
            from: from,
            to: to,
            count: count,
            duration: duration,
            easing: easing,
            minInterval: minInterval
        )
    }

    @Test func またいだ境目の数だけ鳴る() {
        #expect(crossings(to: 360, count: 4).count == 4)
        #expect(crossings(to: 720, count: 4).count == 8)
        #expect(crossings(from: 45, to: 405, count: 4).count == 4)
    }

    @Test func 時刻は昇順で回転時間に収まる() {
        let times = crossings(to: 1830, count: 8)
        #expect(times == times.sorted())
        #expect(times.first! > 0)
        #expect(times.last! <= Config.spinDuration)
    }

    @Test func 鳴る瞬間に針の下のスライスが切り替わる() {
        let to = 1830.0
        let count = 8
        for time in crossings(to: to, count: count) {
            let angle = easing.progress(atTime: time / Config.spinDuration) * to
            let before = RouletteMath.indexUnderPointer(rotation: angle - 0.05, count: count)
            let after = RouletteMath.indexUnderPointer(rotation: angle + 0.05, count: count)
            #expect(before != after)
        }
    }

    @Test func 減速に合わせて間隔が開く() {
        let times = crossings(to: 1830, count: 8, minInterval: Config.clickMinInterval)
        let gaps = zip(times.dropFirst(), times).map(-)
        #expect(gaps.count > 10)
        #expect(gaps.first! < gaps.last!)
        // 序盤は間引きの下限まで詰まり、終盤はそれよりはっきり開く
        #expect(gaps.first! >= Config.clickMinInterval)
        #expect(gaps.last! > Config.clickMinInterval * 4)
    }

    @Test func 最短間隔より詰まった時刻は間引かれる() {
        let dense = crossings(to: 1830, count: 24)
        let thinned = crossings(to: 1830, count: 24, minInterval: Config.clickMinInterval)
        #expect(thinned.count < dense.count)
        for gap in zip(thinned.dropFirst(), thinned).map(-) {
            #expect(gap >= Config.clickMinInterval)
        }
    }

    @Test func 回らないときや項目が無いときは鳴らない() {
        #expect(crossings(to: 0, count: 4).isEmpty)
        #expect(crossings(from: 100, to: 50, count: 4).isEmpty)
        #expect(crossings(to: 360, count: 0).isEmpty)
        #expect(crossings(to: 10, count: 4).isEmpty)
        #expect(crossings(to: 360, count: 4, duration: 0).isEmpty)
    }
}
