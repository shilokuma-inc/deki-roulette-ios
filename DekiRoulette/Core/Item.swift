import Foundation

struct Item: Identifiable, Hashable, Sendable {
    let id: UUID
    let label: String

    init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }
}

/// 削除した項目と、削除前にあった位置。「元に戻す」で同じ位置に差し戻すために使う。
struct RemovedItem: Hashable, Sendable {
    let item: Item
    let index: Int
}

/// リストの行に出す印。ルーレットは当たり、順番決めは先頭・末尾を指す。
enum Mark: Sendable {
    case target
    case first
    case last
}

typealias Marks = [UUID: Mark]
