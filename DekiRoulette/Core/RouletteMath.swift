import Foundation

/// スピンの回転角の計算。針は盤面の真上（0 度）に固定され、盤面が回る。画面上の時計回りが正。
/// スライス i は角度 [i * slice, (i + 1) * slice) を占め、回転 R のとき針の下に来る盤面角は (360 - R) mod 360。
enum RouletteMath {
    static func nextRotation(
        current: Double,
        targetIndex: Int,
        count: Int,
        direction: SpinDirection = .clockwise
    ) -> Double {
        var rng = SystemRandomNumberGenerator()
        return nextRotation(current: current, targetIndex: targetIndex, count: count, direction: direction, using: &rng)
    }

    /// `targetIndex` のスライスが針の下で止まる、次の累積回転角を返す。
    /// 見た目をランダムにするため、スライス内の停止位置と周回数は乱数で散らす。
    static func nextRotation<G: RandomNumberGenerator>(
        current: Double,
        targetIndex: Int,
        count: Int,
        direction: SpinDirection = .clockwise,
        using rng: inout G
    ) -> Double {
        let fullSpins = Int.random(in: Config.fullSpinRange, using: &rng)
        return nextRotation(
            current: current, targetIndex: targetIndex, count: count, fullSpins: fullSpins, direction: direction, using: &rng
        )
    }

    static func nextRotation(
        current: Double,
        targetIndex: Int,
        count: Int,
        fullSpins: Int,
        direction: SpinDirection = .clockwise
    ) -> Double {
        var rng = SystemRandomNumberGenerator()
        return nextRotation(
            current: current, targetIndex: targetIndex, count: count, fullSpins: fullSpins, direction: direction, using: &rng
        )
    }

    /// 周回数を外から与える版。フリックの強さを周回数にだけ反映するために使う。
    /// スライス内の停止位置の決め方は乱数のまま変えない。
    ///
    /// `direction` が反時計回りのときは累積角を減らす向きに決める。停止位置までの差分 `delta` を逆向きに測るだけで、
    /// 近すぎるとき 1 周足す処理と周回数の扱いは時計回りと同じ。
    static func nextRotation<G: RandomNumberGenerator>(
        current: Double,
        targetIndex: Int,
        count: Int,
        fullSpins: Int,
        direction: SpinDirection = .clockwise,
        using rng: inout G
    ) -> Double {
        precondition(count > 0 && (0..<count).contains(targetIndex) && fullSpins >= 0)
        let sliceAngle = 360.0 / Double(count)
        let rawAngle = Double(targetIndex) * sliceAngle + Double.random(in: 0..<1, using: &rng) * sliceAngle
        let desiredMod = positiveMod(360 - rawAngle)
        let currentMod = positiveMod(current)
        var delta = switch direction {
        case .clockwise: positiveMod(desiredMod - currentMod)
        case .counterclockwise: positiveMod(currentMod - desiredMod)
        }
        // 止まる位置がほぼ同じだと回った感じが出ないので、1 周足す
        if delta < 10 { delta += 360 }

        switch direction {
        case .clockwise: return current + Double(fullSpins) * 360 + delta
        case .counterclockwise: return current - Double(fullSpins) * 360 - delta
        }
    }

    /// 回転角 `rotation` のとき針の下にあるスライスの添字。
    static func indexUnderPointer(rotation: Double, count: Int) -> Int {
        precondition(count > 0)
        let wheelAngle = positiveMod(360 - positiveMod(rotation))
        let index = Int(wheelAngle / (360.0 / Double(count)))
        return min(index, count - 1)
    }

    static func positiveMod(_ value: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
