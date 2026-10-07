import Testing
@testable import DekiRoulette

struct GlowStyleTests {
    @Test func 既定は白系() {
        #expect(GlowStyle.default == .white)
    }

    /// 保存値が変わると、保存済みの設定が読めなくなって既定に戻る。
    @Test func 保存値は変えない() {
        #expect(GlowStyle.allCases.map(\.rawValue) == ["white", "slice", "rainbow"])
    }

    @Test func 読めない保存値は扱わない() {
        #expect(GlowStyle(rawValue: "gold") == nil)
    }
}
