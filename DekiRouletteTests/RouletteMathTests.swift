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

    @Test func 反時計回りでも指定したスライスが針の下で止まり累積角が減る() {
        var rng = SeededGenerator(seed: 42)
        var current = 0.0
        for _ in 0..<2000 {
            let count = Int.random(in: 2...Config.maxItems, using: &rng)
            let target = Int.random(in: 0..<count, using: &rng)
            let next = RouletteMath.nextRotation(
                current: current, targetIndex: target, count: count, direction: .counterclockwise, using: &rng
            )
            #expect(RouletteMath.indexUnderPointer(rotation: next, count: count) == target)
            #expect(next < current)
            current = next
        }
        // 累積角が大きく負に振れても positiveMod で扱える
        #expect(current < -2000 * 360)
    }

    @Test func 反時計回りでも周回数を与えるとその周回数だけ回る() {
        var rng = SeededGenerator(seed: 11)
        var current = 0.0
        for _ in 0..<2000 {
            let count = Int.random(in: 2...Config.maxItems, using: &rng)
            let target = Int.random(in: 0..<count, using: &rng)
            let spins = Int.random(in: 0...12, using: &rng)
            let next = RouletteMath.nextRotation(
                current: current, targetIndex: target, count: count, fullSpins: spins,
                direction: .counterclockwise, using: &rng
            )
            #expect(RouletteMath.indexUnderPointer(rotation: next, count: count) == target)
            #expect(current - next >= Double(spins) * 360 + 10)
            #expect(current - next < Double(spins) * 360 + 370)
            current = next
        }
    }

    @Test func 反時計回りで止まる位置が近すぎるときは1周足す() {
        // 回転 -5 のとき針の下の盤面角は 5。先頭のスライス [0, 90) のうち盤面角 5〜15 度に止まるときは、
        // 反時計回りの差分が 10 度未満になるので 1 周足す
        var addedLap = false
        for seed in 0..<200 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let next = RouletteMath.nextRotation(
                current: -5, targetIndex: 0, count: 4, fullSpins: 0, direction: .counterclockwise, using: &rng
            )
            #expect(RouletteMath.indexUnderPointer(rotation: next, count: 4) == 0)
            #expect(-5 - next >= 10)
            #expect(-5 - next < 370)
            if -5 - next >= 360 { addedLap = true }
        }
        #expect(addedLap)
    }

    @Test func 向きを省略すると時計回りと同じ結果になる() {
        var a = SeededGenerator(seed: 5)
        var b = SeededGenerator(seed: 5)
        for _ in 0..<200 {
            let implicit = RouletteMath.nextRotation(current: 37.5, targetIndex: 2, count: 5, using: &a)
            let explicit = RouletteMath.nextRotation(
                current: 37.5, targetIndex: 2, count: 5, direction: .clockwise, using: &b
            )
            #expect(implicit == explicit)
        }
    }

    @Test func 同じ乱数なら向きを変えても止まる盤面角は同じ() {
        var rng = SeededGenerator(seed: 9)
        for _ in 0..<500 {
            let count = Int.random(in: 2...Config.maxItems, using: &rng)
            let target = Int.random(in: 0..<count, using: &rng)
            let current = Double.random(in: -5000...5000, using: &rng)
            let seed = UInt64.random(in: 0...UInt64.max, using: &rng)
            var cw = SeededGenerator(seed: seed)
            var ccw = SeededGenerator(seed: seed)
            let forward = RouletteMath.nextRotation(
                current: current, targetIndex: target, count: count, fullSpins: 3, using: &cw
            )
            let backward = RouletteMath.nextRotation(
                current: current, targetIndex: target, count: count, fullSpins: 3, direction: .counterclockwise, using: &ccw
            )
            #expect(abs(RouletteMath.positiveMod(forward) - RouletteMath.positiveMod(backward)) < 1e-6
                || abs(abs(RouletteMath.positiveMod(forward) - RouletteMath.positiveMod(backward)) - 360) < 1e-6)
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
