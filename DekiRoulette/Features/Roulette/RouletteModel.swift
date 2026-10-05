import Foundation
import Observation

/// スピンの結果。結果表示の色を止まったスライスに合わせるため、
/// ラベルだけでなく盤面上の添字も持つ（同じラベルの項目があっても色が一意に決まる）。
struct SpinOutcome: Equatable {
    let index: Int
    let label: String
}

/// 項目・当たり指定・回転・結果のステートとスピンロジック。Web 版 `useRoulette` に対応する。
@MainActor
@Observable
final class RouletteModel {
    private(set) var items: [Item]
    private(set) var targetId: UUID?
    private(set) var spinning = false
    private(set) var outcome: SpinOutcome?

    /// 累積の回転角（度）。View がアニメーションの中で書き込む。
    var rotation: Double = 0

    private var pendingOutcome: SpinOutcome?
    private var fallbackTask: Task<Void, Never>?

    /// 項目の保存先。nil のときは保存しない（プレビューやテスト向け）。
    private let store: ItemStore?

    init(items: [Item]) {
        self.items = items
        store = nil
    }

    /// 保存済みの項目から始める。無ければ初期項目。
    init(store: ItemStore) {
        self.store = store
        items = store.load()
    }

    var canSpin: Bool { !spinning && items.count >= Config.minItems }
    var atCapacity: Bool { items.count >= Config.maxItems }

    var result: String? { outcome?.label }

    var marks: Marks {
        guard let targetId else { return [:] }
        return [targetId: .target]
    }

    func addItem(_ raw: String) {
        let label = ItemLabel.normalize(raw)
        guard !label.isEmpty, !atCapacity else { return }
        items.append(Item(label: label))
        outcome = nil
        persist()
    }

    /// 複数のラベルをまとめて追加する。上限に収まらない分は切り捨て、追加できた件数を返す。
    @discardableResult
    func addItems(_ raws: [String]) -> Int {
        let labels = raws.map(ItemLabel.normalize).filter { !$0.isEmpty }
        let accepted = Array(labels.prefix(max(0, Config.maxItems - items.count)))
        guard !accepted.isEmpty else { return 0 }
        items.append(contentsOf: ItemLabel.makeItems(accepted))
        outcome = nil
        persist()
        return accepted.count
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        if targetId == id { targetId = nil }
        outcome = nil
        persist()
    }

    /// 項目を丸ごと入れ替える。指定と結果は前のリストのものなので捨てる。
    func replaceItems(_ next: [Item]) {
        items = next
        targetId = nil
        outcome = nil
        persist()
    }

    /// 項目を初期状態に戻す。保存データも消すので、以降は言語設定に応じた初期項目に追従する。
    func resetItems() {
        guard let store else { return }
        replaceItems(store.defaultItems)
        store.clear()
    }

    private func persist() {
        store?.save(items)
    }

    /// 長押しで当たりの指定と解除を切り替える。
    func toggleTarget(id: UUID) {
        targetId = targetId == id ? nil : id
        outcome = nil
    }

    /// スピンを開始し、盤面が止まるべき累積回転角を返す。回せないときは nil。
    /// 呼び出し側はこの値を `rotation` にアニメーション付きで反映し、
    /// アニメーション完了時に `finishSpin()` を呼ぶ。
    /// `fullSpins` を渡すと周回数だけをその値にする（フリックの強さの反映）。止まる位置の決め方は変わらない。
    func beginSpin(reducedMotion: Bool, fullSpins: Int? = nil) -> Double? {
        guard canSpin else { return nil }

        let targetIndex: Int
        if let targetId {
            guard let found = items.firstIndex(where: { $0.id == targetId }) else { return nil }
            targetIndex = found
        } else {
            targetIndex = Int.random(in: 0..<items.count)
        }

        let next = if let fullSpins {
            RouletteMath.nextRotation(current: rotation, targetIndex: targetIndex, count: items.count, fullSpins: fullSpins)
        } else {
            RouletteMath.nextRotation(current: rotation, targetIndex: targetIndex, count: items.count)
        }
        pendingOutcome = SpinOutcome(index: targetIndex, label: items[targetIndex].label)
        outcome = nil
        spinning = true

        // 完了コールバックが来ない環境（バックグラウンド等）向けの保険
        fallbackTask?.cancel()
        let wait = reducedMotion ? Config.reducedMotionSpinDuration : Config.spinFallback
        fallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.finishSpin()
        }
        return next
    }

    func finishSpin() {
        fallbackTask?.cancel()
        fallbackTask = nil
        spinning = false
        guard let pendingOutcome else { return }
        outcome = pendingOutcome
        self.pendingOutcome = nil
    }
}
