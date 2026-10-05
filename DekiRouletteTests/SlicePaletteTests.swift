import Testing
@testable import DekiRoulette

struct SlicePaletteTests {
    private static let maxCount = 24

    private func indices(count: Int, paletteSize: Int) -> [Int] {
        (0..<count).map { SlicePalette.index(at: $0, count: count, paletteSize: paletteSize) }
    }

    @Test(arguments: [10, 12])
    func どの件数でも隣り合うスライスは同じ色にならない(paletteSize: Int) {
        for count in 2...Self.maxCount {
            let colors = indices(count: count, paletteSize: paletteSize)
            for i in 1..<count {
                #expect(colors[i] != colors[i - 1], "count=\(count) i=\(i)")
            }
            if count >= 3 {
                #expect(colors[count - 1] != colors[0], "count=\(count) の継ぎ目")
            }
        }
    }

    @Test(arguments: [10, 12])
    func ずらすのは継ぎ目が重なる件数の末尾だけ(paletteSize: Int) {
        for count in 1...Self.maxCount {
            let colors = indices(count: count, paletteSize: paletteSize)
            for i in 0..<count {
                let shifted = count > 1 && count % paletteSize == 1 && i == count - 1
                if shifted {
                    #expect(colors[i] != i % paletteSize, "count=\(count) i=\(i)")
                } else {
                    #expect(colors[i] == i % paletteSize, "count=\(count) i=\(i)")
                }
            }
        }
    }

    @Test func 十色では11件と21件の末尾をずらす() {
        #expect(indices(count: 11, paletteSize: 10).last == 4)
        #expect(indices(count: 21, paletteSize: 10).last == 4)
        #expect(indices(count: 12, paletteSize: 10).last == 1)
    }

    @Test func 戻り値はパレットの範囲に収まる() {
        for count in 1...Self.maxCount {
            #expect(indices(count: count, paletteSize: 10).allSatisfy { (0..<10).contains($0) })
        }
    }

    @Test func 盤面の塗りと色見本は継ぎ目で同じようにずらす() {
        let paletteSize = Theme.sliceColors.count
        let seam = paletteSize + 1
        let last = seam - 1
        let shifted = SlicePalette.index(at: last, count: seam, paletteSize: paletteSize)
        #expect(Theme.sliceColor(at: last, count: seam) == Theme.sliceColors[shifted])
        #expect(Theme.sliceAccent(at: last, count: seam) == Theme.sliceAccents[shifted])
        #expect(Theme.sliceColor(at: last, count: seam) != Theme.sliceColor(at: 0, count: seam))
        #expect(Theme.sliceColor(at: last, count: seam + 1) == Theme.sliceColor(at: 0, count: seam + 1))
    }

    @Test func 塗りと文字用の色は同じ数だけある() {
        #expect(Theme.sliceColors.count == Theme.sliceAccents.count)
        #expect(Theme.sliceColors.count == 12)
    }

    @Test func 二十四件でも同じ色は二回までしか出ない() {
        let paletteSize = Theme.sliceColors.count
        for count in 1...Self.maxCount {
            let colors = indices(count: count, paletteSize: paletteSize)
            let most = Dictionary(grouping: colors, by: { $0 }).values.map(\.count).max() ?? 0
            #expect(most <= 2, "count=\(count)")
        }
    }
}
