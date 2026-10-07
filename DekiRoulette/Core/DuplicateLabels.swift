import Foundation

/// 同名の項目の判定。「同名」は `ItemLabel.normalize` を通したラベルの完全一致で、
/// 大文字小文字・全角半角の違いは別物として扱う。警告に使うだけで、追加や並びは変えない。
enum DuplicateLabels {
    /// 正規化後のラベルが他の項目と一致する項目の `id`。同名の組に属する項目をすべて含む。
    static func ids(in items: [Item]) -> Set<UUID> {
        let groups = Dictionary(grouping: items) { ItemLabel.normalize($0.label) }
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.id) })
    }

    /// 追加しようとしているラベルが、既存の項目か入力内の他の行と同名か。
    /// ラベルは比較の前に正規化し、空になるものは数えない。
    static func conflicts(adding labels: [String], to items: [Item]) -> Bool {
        var seen = Set(items.map { ItemLabel.normalize($0.label) })
        for label in labels.map(ItemLabel.normalize) where !label.isEmpty {
            if !seen.insert(label).inserted { return true }
        }
        return false
    }
}
