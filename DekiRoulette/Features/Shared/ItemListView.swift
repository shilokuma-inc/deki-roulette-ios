import SwiftUI

/// 項目の追加・削除・隠しジェスチャの受け口と、印の表示制御。両画面で共有する。
struct ItemListView: View {
    let items: [Item]
    let marks: Marks
    /// 演出中。入力と隠しジェスチャを止める。
    let busy: Bool
    /// 印を無条件に伏せる。演出中と結果表示中に立てる。
    let concealMarks: Bool
    let atCapacity: Bool
    /// 正規化済みのラベルをまとめて渡す。戻り値は上限に収まって追加できた件数。
    let onAdd: ([String]) -> Int
    /// 削除した項目と元の位置を返す。「元に戻す」で `onRestore` に渡す。
    let onRemove: (UUID) -> RemovedItem?
    let onRemoveAll: () -> Void
    let onRestore: (Item, Int) -> Void
    let onLongPress: (UUID) -> Void
    /// 保存したリストで項目を置き換える。
    let onLoad: ([Item]) -> Void

    @Environment(SavedListsModel.self) private var savedLists

    @State private var input = ""
    @State private var confirmingRemoveAll = false
    /// 直前に「✕」で削除した項目。トーストを出している間だけ持ち、期限が来ると確定する。
    @State private var pendingRemoval: RemovedItem?
    @State private var undoTask: Task<Void, Never>?
    @State private var pressingCount = 0
    @State private var hinting = false
    @State private var hintTask: Task<Void, Never>?
    @State private var savingList = false
    @State private var listName = ""
    @State private var listsFull = false
    @State private var managingLists = false
    @FocusState private var inputFocused: Bool
    /// 画面収録・ミラーリング中は相手側にも印が映るので伏せる。無ければ（Preview 等）キャプチャ無しとみなす。
    @Environment(ScreenCaptureMonitor.self) private var screenCapture: ScreenCaptureMonitor?
    /// 入力欄を横並びにするために最低限確保したい幅。文字と同じ比率で伸ばし、
    /// 大きい文字や狭い画面で足りなければ `ViewThatFits` が縦積みに切り替える。
    @ScaledMetric(relativeTo: .subheadline) private var inputMinWidth: CGFloat = 160

    /// 入力を行ごとに正規化したもの。改行区切りの貼り付けはここで複数件になる。
    private var lines: [String] { ItemLabel.splitLines(input) }
    private var inputDisabled: Bool { busy || atCapacity }

    /// 指定した本人だけが確認できればよいので、印は項目に触れている間と
    /// 指定直後だけ出す。演出中と結果表示中、画面がキャプチャされている間は無条件で伏せる。
    private var revealMarks: Bool {
        MarkVisibility.reveals(
            concealed: concealMarks,
            captured: screenCapture?.isCaptured ?? false,
            pressing: pressingCount > 0,
            hinting: hinting
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            addForm
            if items.isEmpty {
                emptyState
            } else {
                rows
            }
            if let pendingRemoval {
                undoToast(for: pendingRemoval)
            }
            footnotes
        }
        .onDisappear {
            hintTask?.cancel()
            // タイマーだけ止めるとトーストが残り、期限を過ぎても戻せてしまうので、取り消し自体を閉じる
            dismissUndo()
        }
        // 上限に達したり演出が始まったりして入力できなくなったら、開いたままのキーボードを閉じる
        .onChange(of: inputDisabled) { _, disabled in
            if disabled { inputFocused = false }
        }
        .alert(L10n.saveListTitle, isPresented: $savingList) {
            TextField(L10n.saveListNamePlaceholder, text: $listName)
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.save) { savedLists.save(name: listName, items: items) }
                .disabled(SavedListName.normalize(listName).isEmpty)
        } message: {
            Text(L10n.saveListMessage)
        }
        .alert(L10n.savedListsFullTitle, isPresented: $listsFull) {
            Button(L10n.close, role: .cancel) {}
        } message: {
            Text(L10n.savedListsFullMessage(Config.maxSavedLists))
        }
        .sheet(isPresented: $managingLists) { SavedListsView() }
        // スピン／並べ替えを始めたら取り消せなくする。結果と項目リストの整合を保つため
        .onChange(of: busy) { _, isBusy in
            if isBusy { dismissUndo() }
        }
        .confirmationDialog(L10n.removeAllConfirmTitle, isPresented: $confirmingRemoveAll, titleVisibility: .visible) {
            Button(L10n.removeAll, role: .destructive) {
                dismissUndo()
                onRemoveAll()
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(L10n.itemListTitle)
                .font(.callout.weight(.bold))
                .foregroundStyle(Theme.ivory)
            Spacer()
            if !items.isEmpty && !busy {
                Button(L10n.removeAll) { confirmingRemoveAll = true }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
            }
            Text(L10n.itemCount(items.count, Config.maxItems))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.muted)
            listMenu
        }
    }

    /// 見出し行のメニュー。保存・読み込み・管理だけを置き、行本体の挙動には触れない。
    private var listMenu: some View {
        Menu {
            Button(action: beginSaveList) {
                Label(L10n.saveListAction, systemImage: "square.and.arrow.down")
            }
            .disabled(items.isEmpty)

            Menu {
                if savedLists.lists.isEmpty {
                    Text(L10n.noSavedLists)
                } else {
                    ForEach(savedLists.lists) { list in
                        Button {
                            onLoad(list.items)
                        } label: {
                            Text(list.name)
                            Text(L10n.savedListItemCount(list.items.count))
                        }
                    }
                }
            } label: {
                Label(L10n.loadListAction, systemImage: "tray.and.arrow.up")
            }

            Button {
                managingLists = true
            } label: {
                Label(L10n.manageListsAction, systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(busy)
        .accessibilityLabel(L10n.listMenuLabel)
    }

    private var addForm: some View {
        // 入力欄に `inputMinWidth` を確保できる間は横並び、できなければ縦積みにする。
        // 横並び側の入力欄は伸縮するので、最小幅を明示しないと常に「収まる」と判定されてしまう。
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                inputField
                    .frame(minWidth: inputMinWidth)
                addButton
            }
            VStack(alignment: .leading, spacing: 8) {
                inputField
                addButton
            }
        }
    }

    private var inputField: some View {
        // 複数行の入力欄にして、改行区切りの貼り付けをそのまま受ける。1 行の入力欄では
        // 改行が見えず、何件になるのか分からない。
        TextField(L10n.addPlaceholder, text: $input, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...Config.bulkInputVisibleLines)
            .focused($inputFocused)
            .submitLabel(.return)
            .onSubmit(handleAdd)
            .onChange(of: input) { _, newValue in
                // 複数行の入力欄では Return が改行として入る。末尾の改行を送信の合図として扱い、
                // 追加したあともキーボードは開いたままにする
                if newValue.last?.isNewline == true {
                    if lines.isEmpty { input = "" } else { handleAdd() }
                    return
                }
                // 上限の文字数は行ごとに掛ける。入力欄全体で切ると 2 行目以降が消える
                let clamped = ItemLabel.clampLines(newValue)
                if clamped != newValue { input = clamped }
            }
            .disabled(inputDisabled)
            .font(.subheadline)
            .foregroundStyle(Theme.ivory)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.ink800, in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(inputFocused ? Theme.ink400 : Theme.ink600, lineWidth: 1)
            )
            .opacity(inputDisabled ? 0.4 : 1)
    }

    private var addButton: some View {
        Button(action: handleAdd) {
            Text(lines.count > 1 ? L10n.addItemsButton(lines.count) : L10n.addButton)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(inputDisabled || lines.isEmpty ? Theme.muted.opacity(0.6) : Theme.ivory)
        .background(inputDisabled || lines.isEmpty ? Theme.ink800 : Theme.ink700, in: .rect(cornerRadius: 12))
        .disabled(inputDisabled || lines.isEmpty)
    }

    private var emptyState: some View {
        Text(L10n.emptyList)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.ink600, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
    }

    private var rows: some View {
        // LazyVStack だと末尾の行を消したときに直後のトースト（`undoToast`）が配置されないため
        // 通常の VStack にしている。行は最大 24 なので遅延生成は要らない
        VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let mark = marks[item.id]
                ItemRow(
                    item: item,
                    color: Theme.sliceAccent(at: index),
                    mark: mark,
                    showMark: revealMarks && mark != nil,
                    busy: busy,
                    onPressingChanged: { pressing in pressingCount += pressing ? 1 : -1 },
                    onLongPress: { handleLongPress(item.id) },
                    onRemove: { handleRemove(item.id) }
                )
            }
        }
    }

    /// 「✕」で削除した直後に出す、元に戻すための帯。
    private func undoToast(for removed: RemovedItem) -> some View {
        HStack(spacing: 12) {
            Text(L10n.removedToast(removed.item.label))
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button(L10n.undo) { restorePending() }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.ivory)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.ink800, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink600, lineWidth: 1))
        // 削除のたびに作り直し、置き換えでも新しく現れたように見せる
        .id(removed.item.id)
        .transition(.opacity)
    }

    @ViewBuilder
    private var footnotes: some View {
        if items.count < Config.minItems {
            Text(L10n.needMoreItems)
                .font(.caption)
                .foregroundStyle(Theme.flareText)
        }
        if atCapacity {
            Text(L10n.atCapacity(Config.maxItems))
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private func handleAdd() {
        let lines = lines
        guard !lines.isEmpty, !inputDisabled else { return }
        let added = onAdd(lines)
        input = ""
        // 続けて次の項目を入力できるようにフォーカスを保つ。キーボードは下スワイプで閉じられる
        inputFocused = true
        // 上限で切り捨てた分があれば、画面の「項目は N 個までです」と同じ内容を読み上げる
        if added < lines.count {
            AccessibilityNotification.Announcement(L10n.atCapacity(Config.maxItems)).post()
        }
    }

    /// 上限に達していれば保存に進まず、その旨だけ伝える。
    private func beginSaveList() {
        if savedLists.atCapacity {
            listsFull = true
        } else {
            listName = ""
            savingList = true
        }
    }

    private func handleRemove(_ id: UUID) {
        guard let removed = onRemove(id) else { return }
        // 直前の削除が残っていればそれは確定し、新しい削除に置き換える（多段 Undo は持たない）
        withAnimation(Theme.undoToastAnimation) { pendingRemoval = removed }
        AccessibilityNotification.Announcement(L10n.removedToast(removed.item.label)).post()
        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(for: .seconds(Config.undoDuration))
            guard !Task.isCancelled else { return }
            withAnimation(Theme.undoToastAnimation) { pendingRemoval = nil }
        }
    }

    private func restorePending() {
        guard let pendingRemoval else { return }
        dismissUndo()
        onRestore(pendingRemoval.item, pendingRemoval.index)
    }

    private func dismissUndo() {
        undoTask?.cancel()
        undoTask = nil
        withAnimation(Theme.undoToastAnimation) { pendingRemoval = nil }
    }

    private func handleLongPress(_ id: UUID) {
        onLongPress(id)
        hinting = true
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .seconds(Config.targetHintDuration))
            guard !Task.isCancelled else { return }
            hinting = false
        }
    }
}

private struct ItemRow: View {
    let item: Item
    let color: Color
    let mark: Mark?
    let showMark: Bool
    let busy: Bool
    let onPressingChanged: (Bool) -> Void
    let onLongPress: () -> Void
    let onRemove: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                MarkDot(color: color, mark: showMark ? mark : nil)
                Text(item.label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(TypeLayout.labelLineLimit(for: typeSize))
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            // 通常のタップでは何も起きない。長押しだけを拾うので、見ている人には
            // 「ただ項目に触れただけ」にしか映らない。
            .onLongPressGesture(
                minimumDuration: Config.longPressDuration,
                perform: { if !busy { onLongPress() } },
                onPressingChanged: onPressingChanged
            )
            // 印を伏せている間は選択中の読み上げも落とす。残すと指定先が伝わる。
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(showMark ? .isSelected : [])
            .accessibilityValue(showMark ? (mark.flatMap(L10n.markLabel) ?? "") : "")

            // アイコンの大きさと中心位置は従来（32×40 + 右余白 6）のまま、押せる範囲だけ 44×44 に広げる
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink400)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel(L10n.removeAccessibilityLabel(item.label))
        }
        .background(Theme.ink800, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(showMark ? Theme.ink500 : Theme.ink700, lineWidth: 1)
        )
    }
}

#Preview("Marks visible") {
    ItemListView(
        items: ItemLabel.makeItems(["ラーメン", "カレー", "寿司", "焼肉"]),
        marks: [:],
        busy: false,
        concealMarks: false,
        atCapacity: false,
        onAdd: { $0.count },
        onRemove: { _ in nil },
        onRemoveAll: {},
        onRestore: { _, _ in },
        onLongPress: { _ in },
        onLoad: { _ in }
    )
    .environment(SavedListsModel(lists: []))
    .padding()
    .background(Theme.ink900)
}

#Preview("Marks visible AX5") {
    ItemListView(
        items: ItemLabel.makeItems(["ラーメン", "カレー", "寿司", "焼肉"]),
        marks: [:],
        busy: false,
        concealMarks: false,
        atCapacity: false,
        onAdd: { $0.count },
        onRemove: { _ in nil },
        onRemoveAll: {},
        onRestore: { _, _ in },
        onLongPress: { _ in },
        onLoad: { _ in }
    )
    .environment(SavedListsModel(lists: []))
    .padding()
    .background(Theme.ink900)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Empty") {
    ItemListView(
        items: [],
        marks: [:],
        busy: false,
        concealMarks: false,
        atCapacity: false,
        onAdd: { $0.count },
        onRemove: { _ in nil },
        onRemoveAll: {},
        onRestore: { _, _ in },
        onLongPress: { _ in },
        onLoad: { _ in }
    )
    .environment(SavedListsModel(lists: []))
    .padding()
    .background(Theme.ink900)
}
