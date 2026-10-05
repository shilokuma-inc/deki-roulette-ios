import Foundation
import Observation

/// 名前を付けて保存した項目リストの一覧。ルーレットと順番決めで 1 つを共有する。
@MainActor
@Observable
final class SavedListsModel {
    private(set) var lists: [SavedList]

    private let store: SavedListStore?

    init(lists: [SavedList]) {
        self.lists = lists
        store = nil
    }

    init(store: SavedListStore) {
        self.store = store
        lists = store.load()
    }

    var atCapacity: Bool { lists.atCapacity }

    func list(id: UUID) -> SavedList? {
        lists.first { $0.id == id }
    }

    /// いまの項目を名前を付けて保存する。名前が空、または上限に達しているときは保存せず false。
    @discardableResult
    func save(name: String, items: [Item]) -> Bool {
        guard let next = lists.adding(name: name, items: items) else { return false }
        lists = next
        persist()
        return true
    }

    @discardableResult
    func rename(id: UUID, to name: String) -> Bool {
        guard let next = lists.renaming(id: id, to: name) else { return false }
        lists = next
        persist()
        return true
    }

    func delete(id: UUID) {
        lists = lists.deleting(id: id)
        persist()
    }

    private func persist() {
        store?.save(lists)
    }
}
