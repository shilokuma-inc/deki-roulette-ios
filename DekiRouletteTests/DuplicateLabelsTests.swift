import Foundation
import Testing
@testable import DekiRoulette

struct DuplicateLabelsTests {
    @Test func 重複がなければ空になる() {
        let items = ItemLabel.makeItems(["A", "B", "C"])
        #expect(DuplicateLabels.ids(in: items).isEmpty)
    }

    @Test func 空配列なら空になる() {
        #expect(DuplicateLabels.ids(in: []).isEmpty)
    }

    @Test func 同名の2件を両方返す() {
        let items = ItemLabel.makeItems(["A", "B", "A"])
        #expect(DuplicateLabels.ids(in: items) == [items[0].id, items[2].id])
    }

    @Test func 同名の3件以上をすべて返す() {
        let items = ItemLabel.makeItems(["A", "A", "B", "A"])
        #expect(DuplicateLabels.ids(in: items) == [items[0].id, items[1].id, items[3].id])
    }

    @Test func 複数の組をまとめて返す() {
        let items = ItemLabel.makeItems(["A", "B", "C", "B", "A"])
        #expect(DuplicateLabels.ids(in: items) == [items[0].id, items[1].id, items[3].id, items[4].id])
    }

    @Test func 大文字小文字の違いは同名でない() {
        let items = ItemLabel.makeItems(["Ramen", "ramen", "RAMEN"])
        #expect(DuplicateLabels.ids(in: items).isEmpty)
    }

    @Test func 全角半角の違いは同名でない() {
        let items = ItemLabel.makeItems(["ABC", "ＡＢＣ", "ｶﾚｰ", "カレー"])
        #expect(DuplicateLabels.ids(in: items).isEmpty)
    }

    @Test func 正規化すると一致するラベルは同名とみなす() {
        let items = [Item(label: "佐藤 太郎"), Item(label: " 佐藤   太郎 ")]
        #expect(DuplicateLabels.ids(in: items) == Set(items.map(\.id)))
    }

    @Test func 追加するラベルが既存と同名なら衝突する() {
        let items = ItemLabel.makeItems(["A", "B"])
        #expect(DuplicateLabels.conflicts(adding: ["B"], to: items))
        #expect(DuplicateLabels.conflicts(adding: ["  B "], to: items))
    }

    @Test func 追加するラベルが既存と違えば衝突しない() {
        let items = ItemLabel.makeItems(["A", "B"])
        #expect(!DuplicateLabels.conflicts(adding: ["C"], to: items))
        #expect(!DuplicateLabels.conflicts(adding: ["a", "Ｂ"], to: items))
    }

    @Test func 入力内の行同士が同名なら衝突する() {
        #expect(DuplicateLabels.conflicts(adding: ["C", "D", "C"], to: ItemLabel.makeItems(["A"])))
        #expect(DuplicateLabels.conflicts(adding: ["C", "C"], to: []))
    }

    @Test func 複数行の一部だけが既存と同名でも衝突する() {
        let items = ItemLabel.makeItems(["A", "B"])
        #expect(DuplicateLabels.conflicts(adding: ["C", "A", "D"], to: items))
    }

    @Test func 空のラベルは数えない() {
        #expect(!DuplicateLabels.conflicts(adding: ["", "  ", "C"], to: []))
        #expect(!DuplicateLabels.conflicts(adding: [], to: ItemLabel.makeItems(["A", "A"])))
    }
}
