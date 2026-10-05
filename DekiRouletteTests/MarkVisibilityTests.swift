import Testing
@testable import DekiRoulette

struct MarkVisibilityTests {
    @Test func 押している間か指定直後だけ出す() {
        #expect(MarkVisibility.reveals(concealed: false, captured: false, pressing: true, hinting: false))
        #expect(MarkVisibility.reveals(concealed: false, captured: false, pressing: false, hinting: true))
        #expect(!MarkVisibility.reveals(concealed: false, captured: false, pressing: false, hinting: false))
    }

    @Test func 伏せているときは押していても出さない() {
        #expect(!MarkVisibility.reveals(concealed: true, captured: false, pressing: true, hinting: true))
    }

    @Test func キャプチャ中は押していても指定直後でも出さない() {
        #expect(!MarkVisibility.reveals(concealed: false, captured: true, pressing: true, hinting: false))
        #expect(!MarkVisibility.reveals(concealed: false, captured: true, pressing: false, hinting: true))
    }
}
