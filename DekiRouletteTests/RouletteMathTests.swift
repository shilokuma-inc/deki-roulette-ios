import Testing
@testable import DekiRoulette

struct RouletteMathTests {
    @Test func 指定したスライスが針の下で止まる() {
        var rng = SeededGenerator(seed: 42)
        var current = 0.0
        for _ in 0..<2000 {
            let count = Int.random(in: 2...Config.maxItems, using: &rng)
            let target = Int.random(in: 0..<count, using: &rng)
            let next = RouletteMath.nextRotation(current: current, targetIndex: target, count: count, using: &rng)
            #expect(RouletteMath.indexUnderPointer(rotation: next, count: count) == target)
            #expect(next > current)
            current = next
        }
    }

    @Test func 最低でも4周と10度は回る() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<500 {
            let next = RouletteMath.nextRotation(current: 123.4, targetIndex: 0, count: 4, using: &rng)
            #expect(next - 123.4 >= 4 * 360 + 10)
            #expect(next - 123.4 < 9 * 360 + 360)
        }
    }

    @Test func 周回数を与えてもその周回数だけ回って指定したスライスで止まる() {
        var rng = SeededGenerator(seed: 11)
        var current = 0.0
        for _ in 0..<2000 {
            let count = Int.random(in: 2...Config.maxItems, using: &rng)
            let target = Int.random(in: 0..<count, using: &rng)
            let spins = Int.random(in: 0...12, using: &rng)
            let next = RouletteMath.nextRotation(
                current: current, targetIndex: target, count: count, fullSpins: spins, using: &rng
            )
            #expect(RouletteMath.indexUnderPointer(rotation: next, count: count) == target)
            // 指定の周回数に、停止位置までの差分（10 度以上 370 度未満）を足した分だけ進む
            #expect(next - current >= Double(spins) * 360 + 10)
            #expect(next - current < Double(spins) * 360 + 370)
            current = next
        }
    }

    @Test func 針の下の添字は回転0で先頭のスライス() {
        #expect(RouletteMath.indexUnderPointer(rotation: 0, count: 4) == 0)
        // 盤面を時計回りに 90 度回すと、針の下には最後のスライスが来る
        #expect(RouletteMath.indexUnderPointer(rotation: 90, count: 4) == 3)
        #expect(RouletteMath.indexUnderPointer(rotation: -90, count: 4) == 1)
        #expect(RouletteMath.indexUnderPointer(rotation: 360 * 5, count: 4) == 0)
    }
}
