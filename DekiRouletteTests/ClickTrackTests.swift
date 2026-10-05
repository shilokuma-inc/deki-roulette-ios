import Testing
@testable import DekiRoulette

struct ClickTrackTests {
    private let rate = 1000.0
    private let click: [Float] = [1, -0.5, 0.25]

    @Test func 鳴らす時刻が無ければ空() {
        #expect(ClickTrack.render(click: click, sampleRate: rate, times: [], gain: 1).isEmpty)
        #expect(ClickTrack.render(click: [], sampleRate: rate, times: [0], gain: 1).isEmpty)
    }

    @Test func 指定した位置にクリック音が入る() {
        let track = ClickTrack.render(click: click, sampleRate: rate, times: [0, 0.1], gain: 1)
        #expect(track.count == 100 + click.count)
        #expect(Array(track[0..<3]) == click)
        #expect(Array(track[100..<103]) == click)
        #expect(track[50] == 0)
    }

    @Test func 音量を掛ける() {
        let track = ClickTrack.render(click: click, sampleRate: rate, times: [0], gain: 0.5)
        #expect(track == click.map { $0 * 0.5 })
    }

    @Test func 重なった分は足し合わされて範囲に収まる() {
        let track = ClickTrack.render(click: [1, 1], sampleRate: rate, times: [0, 0.001], gain: 1)
        #expect(track == [1, 1, 1])
    }
}
