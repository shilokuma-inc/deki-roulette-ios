import Foundation
import Testing
@testable import DekiRoulette

struct HapticScheduleTests {
    private let easing = Config.spinEasing
    private let duration = Config.spinDuration

    private func crossings(from: Double, to: Double, count: Int, minInterval: Double = 0) -> [Double] {
        HapticSchedule.boundaryCrossings(
            from: from, to: to, count: count, duration: duration, easing: easing, minInterval: minInterval
        )
    }

    /// 開始からの秒 `time` における回転角。View のアニメーションと同じ曲線で補間する。
    private func rotation(at time: Double, from: Double, to: Double) -> Double {
        from + (to - from) * easing.progress(atTime: time / duration)
    }

    @Test func 境目の数は通過するスライスの数に等しい() {
        // 0 度から 2 周 + 45 度、4 スライス（90 度）なら 90, 180, ..., 720 の 8 本を越える
        #expect(crossings(from: 0, to: 765, count: 4).count == 8)
        // 開始位置がちょうど境目のときは、その境目は数えない
        #expect(crossings(from: 90, to: 765, count: 4).count == 7)
        // 終了位置がちょうど境目のときは、その境目を数える
        #expect(crossings(from: 0, to: 720, count: 4).count == 8)
    }

    @Test func 各時刻で針の下の添字が切り替わる() {
        var rng = SeededGenerator(seed: 5)
        for _ in 0..<200 {
            let count = Int.random(in: 2...Config.maxItems, using: &rng)
            let from = Double.random(in: 0..<3600, using: &rng)
            let to = RouletteMath.nextRotation(current: from, targetIndex: 0, count: count, using: &rng)
            for time in crossings(from: from, to: to, count: count) {
                let before = RouletteMath.indexUnderPointer(rotation: rotation(at: time - 1e-4, from: from, to: to), count: count)
                let after = RouletteMath.indexUnderPointer(rotation: rotation(at: time + 1e-4, from: from, to: to), count: count)
                #expect(before != after)
            }
        }
    }

    @Test func 時刻は昇順で回転時間の中に収まる() {
        let times = crossings(from: 123, to: 123 + 6 * 360 + 200, count: 7)
        #expect(!times.isEmpty)
        #expect(times == times.sorted())
        #expect(times.first! > 0)
        #expect(times.last! <= duration + 1e-9)
    }

    @Test func 終盤は減速に合わせて間隔が開く() {
        let times = crossings(from: 0, to: 6 * 360, count: 4)
        let firstGap = times[1] - times[0]
        let lastGap = times[times.count - 1] - times[times.count - 2]
        #expect(lastGap > firstGap * 5)
    }

    @Test func 最短間隔で間引く() {
        let all = crossings(from: 0, to: 8 * 360, count: 24)
        let throttled = crossings(from: 0, to: 8 * 360, count: 24, minInterval: Config.hapticMinInterval)
        #expect(throttled.count < all.count)
        for (earlier, later) in zip(throttled, throttled.dropFirst()) {
            #expect(later - earlier >= Config.hapticMinInterval - 1e-9)
        }
        // 最初の境目と、減速した終盤の境目は残る
        #expect(throttled.first == all.first)
        #expect(throttled.last == all.last)
    }

    @Test func 回らないなら何も鳴らない() {
        #expect(crossings(from: 100, to: 100, count: 4).isEmpty)
        #expect(crossings(from: 100, to: 50, count: 4).isEmpty)
        #expect(crossings(from: 0, to: 360, count: 0).isEmpty)
        // 1 スライスしか進まないうちに止まる
        #expect(crossings(from: 10, to: 80, count: 4).isEmpty)
    }

    @Test func 順番決めは行が現れる時刻に刻む() {
        let ticks = HapticSchedule.revealTicks(count: 4, reducedMotion: false)
        #expect(ticks.count == 4)
        for (index, time) in ticks.enumerated() {
            #expect(abs(time - RevealTiming.delay(index: index, reducedMotion: false)) < 1e-9)
        }
        #expect(HapticSchedule.revealTicks(count: 4, reducedMotion: true).isEmpty)
        #expect(HapticSchedule.revealTicks(count: 0, reducedMotion: false).isEmpty)
    }
}
