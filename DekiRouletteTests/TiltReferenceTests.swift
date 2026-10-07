import Testing
@testable import DekiRoulette

struct TiltReferenceTests {
    @Test func 既定は水平に置いた状態() {
        #expect(TiltReference.default == .flat)
    }

    /// 保存値が変わると、保存済みの設定が読めなくなって既定に戻る。
    @Test func 保存値は変えない() {
        #expect(TiltReference.allCases.map(\.rawValue) == ["flat", "grip"])
    }

    @Test func 読めない保存値は扱わない() {
        #expect(TiltReference(rawValue: "device") == nil)
    }
}
