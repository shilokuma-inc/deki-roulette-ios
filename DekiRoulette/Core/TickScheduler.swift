import Foundation

/// あらかじめ決めた時刻（開始からの秒）に順に `tick` を呼ぶ。触覚のトリガを刻むために使う。
/// 返した `Task` をキャンセルすると以降は呼ばれない。時刻が無ければ何もせず nil。
@MainActor
enum TickScheduler {
    static func run(at times: [TimeInterval], tick: @escaping @MainActor () -> Void) -> Task<Void, Never>? {
        guard !times.isEmpty else { return nil }
        return Task { @MainActor in
            let start = ContinuousClock.now
            for time in times {
                try? await Task.sleep(until: start + .seconds(time), clock: .continuous)
                guard !Task.isCancelled else { return }
                tick()
            }
        }
    }
}
