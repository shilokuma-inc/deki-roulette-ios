import Testing
@testable import DekiRoulette

@MainActor
struct RouletteModelTests {
    private func makeModel(_ labels: [String] = ["A", "B", "C", "D"]) -> RouletteModel {
        RouletteModel(items: ItemLabel.makeItems(labels))
    }

    @Test func 項目は上限まで追加できる() {
        let model = makeModel([])
        for i in 0..<30 { model.addItem("項目\(i)") }
        #expect(model.items.count == Config.maxItems)
        #expect(model.atCapacity)
    }

    @Test func 空のラベルは追加されない() {
        let model = makeModel([])
        model.addItem("   ")
        #expect(model.items.isEmpty)
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
        #expect(model.items.last?.label == "項目\(Config.maxItems - 3)")
        #expect(model.addItems(["E"]) == 0)
    }

    @Test func まとめて追加すると結果が消える() {
        let model = makeModel()
        model.rotation = model.beginSpin(reducedMotion: false)!
        model.finishSpin()
        #expect(model.result != nil)
        model.addItems(["E", "F"])
        #expect(model.result == nil)
    }

    @Test func 項目が2つ未満なら回せない() {
        let model = makeModel(["A"])
        #expect(!model.canSpin)
        #expect(model.beginSpin(reducedMotion: false) == nil)
    }

    @Test func 当たり指定はトグルする() {
        let model = makeModel()
        let id = model.items[1].id
        model.toggleTarget(id: id)
        #expect(model.targetId == id)
        #expect(model.marks == [id: .target])
        model.toggleTarget(id: id)
        #expect(model.targetId == nil)
    }

    @Test func 指定した項目を削除すると指定も外れる() {
        let model = makeModel()
        let id = model.items[2].id
        model.toggleTarget(id: id)
        model.removeItem(id: id)
        #expect(model.targetId == nil)
        #expect(model.items.count == 3)
    }

    @Test func 指定があれば結果はその項目になる() {
        for _ in 0..<50 {
            let model = makeModel()
            model.toggleTarget(id: model.items[3].id)
            let next = model.beginSpin(reducedMotion: false)
            #expect(next != nil)
            #expect(model.spinning)
            #expect(model.result == nil)
            model.rotation = next!
            model.finishSpin()
            #expect(!model.spinning)
            #expect(model.result == "D")
            #expect(RouletteMath.indexUnderPointer(rotation: model.rotation, count: 4) == 3)
        }
    }

    @Test func 指定がなければ結果は針の下の項目と一致する() {
        for _ in 0..<50 {
            let model = makeModel()
            let next = model.beginSpin(reducedMotion: false)!
            model.rotation = next
            model.finishSpin()
            let index = RouletteMath.indexUnderPointer(rotation: next, count: 4)
            #expect(model.result == model.items[index].label)
        }
    }

    @Test func スピン中は二重に始められない() {
        let model = makeModel()
        #expect(model.beginSpin(reducedMotion: false) != nil)
        #expect(model.beginSpin(reducedMotion: false) == nil)
    }

    @Test func 結果の添字は針の下のスライスと一致する() throws {
        for _ in 0..<50 {
            let model = makeModel()
            let next = model.beginSpin(reducedMotion: false)!
            model.rotation = next
            model.finishSpin()
            let outcome = try #require(model.outcome)
            #expect(outcome.index == RouletteMath.indexUnderPointer(rotation: next, count: 4))
            #expect(outcome.label == model.items[outcome.index].label)
        }
    }

    @Test func 同じラベルが並んでいても結果の添字は指定した項目を指す() {
        let model = makeModel(["A", "A", "A", "A"])
        model.toggleTarget(id: model.items[2].id)
        model.rotation = model.beginSpin(reducedMotion: false)!
        model.finishSpin()
        #expect(model.outcome == SpinOutcome(index: 2, label: "A"))
    }

    @Test func フリックの周回数を渡しても結果は針の下の項目と一致する() throws {
        for spins in Config.fullSpinRange {
            let model = makeModel()
            model.toggleTarget(id: model.items[1].id)
            let before = model.rotation
            let next = try #require(model.beginSpin(reducedMotion: false, fullSpins: spins))
            #expect(next - before >= Double(spins) * 360 + 10)
            #expect(next - before < Double(spins) * 360 + 370)
            model.rotation = next
            model.finishSpin()
            #expect(model.outcome == SpinOutcome(index: 1, label: "B"))
        }
    }

    @Test func 項目を触ると結果が消える() {
        let model = makeModel()
        model.rotation = model.beginSpin(reducedMotion: false)!
        model.finishSpin()
        #expect(model.result != nil)
        model.addItem("E")
        #expect(model.result == nil)
    }


    // MARK: 永続化

    private func makeStore(_ storage: InMemoryStorage) -> ItemStore {
        ItemStore(key: .roulette, storage: storage, defaultLabels: { ["A", "B", "C", "D"] })
    }

    @Test func まとめて追加したときも保存する() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = RouletteModel(store: store)
        model.addItems(["E", "F"])
        #expect(store.loadSaved()?.map(\.label) == ["A", "B", "C", "D", "E", "F"])
    }

    @Test func 追加と削除のたびに保存する() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = RouletteModel(store: store)
        #expect(store.loadSaved() == nil)
        model.addItem("E")
        #expect(store.loadSaved()?.map(\.label) == ["A", "B", "C", "D", "E"])
        model.removeItem(id: model.items[0].id)
        #expect(store.loadSaved()?.map(\.label) == ["B", "C", "D", "E"])
    }

    @Test func 保存した項目から始まるが指定は残らない() {
        let storage = InMemoryStorage()
        let first = RouletteModel(store: makeStore(storage))
        first.addItem("E")
        first.toggleTarget(id: first.items[4].id)

        let second = RouletteModel(store: makeStore(storage))
        #expect(second.items == first.items)
        #expect(second.targetId == nil)
    }

    @Test func 初期状態に戻すと指定と結果も消え保存データも消える() {
        let storage = InMemoryStorage()
        let store = makeStore(storage)
        let model = RouletteModel(store: store)
        model.addItem("E")
        model.toggleTarget(id: model.items[0].id)
        model.rotation = model.beginSpin(reducedMotion: false)!
        model.finishSpin()

        model.resetItems()
        #expect(model.items.map(\.label) == ["A", "B", "C", "D"])
        #expect(model.targetId == nil)
        #expect(model.result == nil)
        #expect(store.loadSaved() == nil)
    }

    @Test func 保存先が無いときは初期状態に戻しても何もしない() {
        let model = makeModel(["A", "B"])
        model.resetItems()
        #expect(model.items.map(\.label) == ["A", "B"])
    }
}
