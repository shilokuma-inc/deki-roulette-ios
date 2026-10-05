import CoreGraphics
import Testing
@testable import DekiRoulette

struct SwipeToDeleteTests {
    private let action: CGFloat = 80
    private let row: CGFloat = 300

    @Test func 横が優勢なときだけ横のスワイプとみなす() {
        #expect(SwipeToDelete.isHorizontal(-30, 10))
        #expect(SwipeToDelete.isHorizontal(30, -10))
        #expect(!SwipeToDelete.isHorizontal(10, 30))
        #expect(!SwipeToDelete.isHorizontal(20, 20))
    }

    @Test func 閉じた行は右には開かない() {
        #expect(SwipeToDelete.offset(translation: 40, wasOpen: false, actionWidth: action, rowWidth: row) == 0)
        #expect(SwipeToDelete.offset(translation: -40, wasOpen: false, actionWidth: action, rowWidth: row) == -40)
    }

    @Test func 開いた行は削除ボタンの幅から動く() {
        #expect(SwipeToDelete.offset(translation: 0, wasOpen: true, actionWidth: action, rowWidth: row) == -80)
        #expect(SwipeToDelete.offset(translation: 50, wasOpen: true, actionWidth: action, rowWidth: row) == -30)
        #expect(SwipeToDelete.offset(translation: 200, wasOpen: true, actionWidth: action, rowWidth: row) == 0)
    }

    @Test func 左は行幅までで止める() {
        #expect(SwipeToDelete.offset(translation: -500, wasOpen: false, actionWidth: action, rowWidth: row) == -300)
    }

    @Test func 行幅の半分を越えて引いたら削除する() {
        #expect(SwipeToDelete.outcome(offset: -151, predictedOffset: -151, actionWidth: action, rowWidth: row) == .delete)
        #expect(SwipeToDelete.outcome(offset: -150, predictedOffset: -150, actionWidth: action, rowWidth: row) == .open)
    }

    @Test func 勢いだけでは削除しない() {
        #expect(SwipeToDelete.outcome(offset: -60, predictedOffset: -300, actionWidth: action, rowWidth: row) == .open)
    }

    @Test func 予測位置が削除ボタンの半分を越えれば開く() {
        #expect(SwipeToDelete.outcome(offset: -30, predictedOffset: -41, actionWidth: action, rowWidth: row) == .open)
        #expect(SwipeToDelete.outcome(offset: -30, predictedOffset: -40, actionWidth: action, rowWidth: row) == .closed)
    }

    @Test func 戻す向きに離せば閉じる() {
        #expect(SwipeToDelete.outcome(offset: -70, predictedOffset: -10, actionWidth: action, rowWidth: row) == .closed)
    }
}
