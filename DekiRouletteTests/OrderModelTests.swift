import Testing
@testable import DekiRoulette

@MainActor
struct OrderModelTests {
    private func makeModel(_ labels: [String] = ["A", "B", "C", "D"]) -> OrderModel {
        OrderModel(items: ItemLabel.makeItems(labels))
    }

    @Test func 長押しのたびに先頭_末尾_解除と回る() {
        let model = makeModel()
        let id = model.items[0].id
        model.cycleMark(id: id)
        #expect(model.marks == [id: .first])
        model.cycleMark(id: id)
        #expect(model.marks == [id: .last])
        model.cycleMark(id: id)
        #expect(model.marks.isEmpty)
    }

    @Test func 先頭は1項目まで() {
        let model = makeModel()
        let a = model.items[0].id
        let b = model.items[1].id
        model.cycleMark(id: a)
        model.cycleMark(id: b)
        #expect(model.marks == [b: .first])
    }

    @Test func 先頭を末尾に回すと以前の末尾は外れる() {
        let model = makeModel()
        let a = model.items[0].id
        let b = model.items[1].id
        model.cycleMark(id: b)
        model.cycleMark(id: b)  // b が末尾
        model.cycleMark(id: a)  // a が先頭
        model.cycleMark(id: a)  // a が末尾へ。b の末尾は落ちる
        #expect(model.marks == [a: .last])
    }

    @Test func 指定した項目を削除すると指定も外れる() {
        let model = makeModel()
        let id = model.items[1].id
        model.cycleMark(id: id)
        model.removeItem(id: id)
        #expect(model.marks.isEmpty)
    }

    @Test func 削除すると削除した項目と元の位置が返る() {
        let model = makeModel()
        let item = model.items[2]
        let removed = model.removeItem(id: item.id)
        #expect(removed == RemovedItem(item: item, index: 2))
        #expect(model.items.map(\.label) == ["A", "B", "D"])
        #expect(model.removeItem(id: item.id) == nil)
    }

    @Test func 元に戻すと同じIDで元の位置に入る() {
        let model = makeModel()
        let removed = model.removeItem(id: model.items[2].id)!
        model.restore(removed.item, at: removed.index)
        #expect(model.items.map(\.label) == ["A", "B", "C", "D"])
        #expect(model.items[2].id == removed.item.id)
    }

    @Test func 元に戻しても先頭末尾の指定は復元しない() {
        let model = makeModel()
        let id = model.items[0].id
        model.cycleMark(id: id)
        model.cycleMark(id: id)  // 末尾
        let removed = model.removeItem(id: id)!
        model.restore(removed.item, at: removed.index)
        #expect(model.marks.isEmpty)
    }

    @Test func 元の位置が範囲外なら末尾に戻す() {
        let model = makeModel()
        let removed = model.removeItem(id: model.items[3].id)!
        model.removeItem(id: model.items[2].id)
        model.restore(removed.item, at: removed.index)
        #expect(model.items.map(\.label) == ["A", "B", "D"])
    }

    @Test func 同じ項目が残っているか上限に達していれば戻さない() {
        let model = makeModel()
        model.restore(model.items[0], at: 0)
        #expect(model.items.count == 4)

        let full = makeModel([])
        for i in 0..<Config.maxItems { full.addItem("項目\(i)") }
        full.restore(Item(label: "E"), at: 0)
        #expect(full.items.count == Config.maxItems)
    }

    @Test func 元に戻すと結果が消える() {
        let model = makeModel()
        let removed = model.removeItem(id: model.items[0].id)!
        model.shuffleItems(reducedMotion: true)
        #expect(model.ordered != nil)
        model.restore(removed.item, at: removed.index)
        #expect(model.ordered == nil)
    }

    @Test func すべて削除すると項目も指定も結果も消える() {
        let model = makeModel()
        model.cycleMark(id: model.items[0].id)
        model.cycleMark(id: model.items[1].id)
        model.cycleMark(id: model.items[1].id)  // 1 が末尾
        model.shuffleItems(reducedMotion: true)
        model.removeAll()
        #expect(model.items.isEmpty)
        #expect(model.marks.isEmpty)
        #expect(model.ordered == nil)
        #expect(!model.canShuffle)
    }

    @Test func 並べ替えは指定を反映する() {
        for _ in 0..<50 {
            let model = makeModel()
            let first = model.items[2].id
            let last = model.items[0].id
            // 末尾を先に確定させる。未指定の項目を長押しすると先頭になり、前の先頭を上書きするため
            model.cycleMark(id: last)
            model.cycleMark(id: last)
            model.cycleMark(id: first)
            model.shuffleItems(reducedMotion: true)
            #expect(model.revealing)
            #expect(model.ordered?.first?.id == first)
            #expect(model.ordered?.last?.id == last)
            #expect(model.ordered.map { Set($0) } == Set(model.items))
        }
    }

    @Test func 演出中は並べ替えられず時間が経つと終わる() async throws {
        let model = makeModel()
        model.shuffleItems(reducedMotion: true)
        #expect(!model.canShuffle)
        try await Task.sleep(for: .seconds(Config.reducedMotionRevealDuration + 0.3))
        #expect(!model.revealing)
        #expect(model.canShuffle)
    }

    @Test func 項目を触ると結果が消える() {
        let model = makeModel()
        model.shuffleItems(reducedMotion: true)
        #expect(model.ordered != nil)
        model.cycleMark(id: model.items[0].id)
        #expect(model.ordered == nil)
    }

    @Test func 複数のラベルをまとめて追加できる() {
        let model = makeModel([])
        let added = model.addItems(["A", "  B  C ", "   ", "D"])
        #expect(added == 3)
        #expect(model.items.map(\.label) == ["A", "B C", "D"])
    }

    @Test func まとめて追加しても上限を超えた分は切り捨てる() {
        let model = makeModel(["A", "B"])
        let added = model.addItems((0..<30).map { "項目\($0)" })
        #expect(added == Config.maxItems - 2)
        #expect(model.items.count == Config.maxItems)
        #expect(model.addItems(["E"]) == 0)
    }

    @Test func まとめて追加すると結果が消える() {
        let model = makeModel()
        model.shuffleItems(reducedMotion: true)
        #expect(model.ordered != nil)
        model.addItems(["E", "F"])
        #expect(model.ordered == nil)
    }

    // MARK: 永続化

    private func makeStore(_ storage: InMemoryStorage) -> ItemStore {
        ItemStore(key: .order, storage: storage, defaultLabels: { ["A", "B", "C", "D"] })
    }

    @Test func まとめて追加したときも保存する() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = OrderModel(store: store)
        model.addItems(["E", "F"])
        #expect(store.loadSaved()?.map(\.label) == ["A", "B", "C", "D", "E", "F"])
    }

    @Test func 追加と削除のたびに保存する() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = OrderModel(store: store)
        #expect(store.loadSaved() == nil)
        model.addItem("E")
        #expect(store.loadSaved()?.map(\.label) == ["A", "B", "C", "D", "E"])
        model.removeItem(id: model.items[0].id)
        #expect(store.loadSaved()?.map(\.label) == ["B", "C", "D", "E"])
    }

    @Test func すべて削除したときも保存する() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = OrderModel(store: store)
        model.removeAll()
        #expect(store.loadSaved()?.isEmpty == true)
        #expect(OrderModel(store: makeStore(storage)).items.isEmpty)
    }

    @Test func 保存した項目から始まるが指定は残らない() {
        let storage = InMemoryStorage()
        let first = OrderModel(store: makeStore(storage))
        first.addItem("E")
        first.cycleMark(id: first.items[0].id)
        first.cycleMark(id: first.items[1].id)
        first.cycleMark(id: first.items[1].id)

        let second = OrderModel(store: makeStore(storage))
        #expect(second.items == first.items)
        #expect(second.marks.isEmpty)
    }

    @Test func 初期状態に戻すと指定と結果も消え保存データも消える() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = OrderModel(store: store)
        model.addItem("E")
        model.cycleMark(id: model.items[0].id)
        model.shuffleItems(reducedMotion: true)

        model.resetItems()
        #expect(model.items.map(\.label) == ["A", "B", "C", "D"])
        #expect(model.marks.isEmpty)
        #expect(model.ordered == nil)
        #expect(store.loadSaved() == nil)
    }
}
