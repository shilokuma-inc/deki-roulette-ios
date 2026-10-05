import SwiftUI

struct OrderScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let model: OrderModel

    var body: some View {
        PageFrame(
            title: L10n.orderTitle,
            tagline: L10n.orderTagline,
            busy: model.revealing,
            useCases: L10n.orderUseCases
        ) {
            Text(L10n.orderHelpBasic)
            HelpHeading(text: L10n.orderHelpAimTitle)
            Text(L10n.orderHelpAim)
            Text(L10n.orderHelpAimStealth)
            Text(L10n.orderHelpAimRandom)
        } content: {
            AdaptiveStack(horizontal: regular, alignment: .center, spacing: Theme.Layout.columnSpacing) {
                resultSection
                ItemListView(
                    items: model.items,
                    marks: model.marks,
                    busy: model.revealing,
                    concealMarks: model.revealing || model.ordered != nil,
                    atCapacity: model.atCapacity,
                    onAdd: { model.addItems($0) },
                    onRemove: { model.removeItem(id: $0) },
                    onLongPress: { model.cycleMark(id: $0) }
                )
                .frame(maxWidth: regular ? Theme.Layout.listWidthRegular : .infinity)
            }
        }
    }

    private var regular: Bool { sizeClass == .regular }

    private var resultSection: some View {
        VStack(spacing: 24) {
            OrderResultView(
                ordered: model.ordered,
                resultId: model.resultId,
                revealing: model.revealing,
                reducedMotion: reduceMotion
            )

            PrimaryActionButton(
                title: model.revealing ? L10n.orderShuffling : L10n.orderShuffle,
                busy: model.revealing,
                enabled: model.canShuffle,
                action: { model.shuffleItems(reducedMotion: reduceMotion) }
            )

            ZStack {
                // 演出が終わって結果が出ている間だけ出す。結果が変わると作り直されるので
                // 「コピーしました」も自然に戻る
                if let ordered = model.ordered, !model.revealing {
                    let text = ResultText.order(ordered.map(\.label))
                    ResultActions(copyText: text, shareText: ResultText.share(text, appName: L10n.appName))
                        .id(model.resultId)
                }
            }
            // コピーボタンの有無で上のボタンが動かないよう高さを固定する。大きい文字では最小高さだけ残す
            .frame(minHeight: 32, maxHeight: TypeLayout.growsFixedAreas(for: typeSize) ? nil : 32)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OrderScreen(model: OrderModel(items: ItemLabel.makeItems(L10n.orderDefaultItems)))
}

#Preview("AX5") {
    OrderScreen(model: OrderModel(items: ItemLabel.makeItems(L10n.orderDefaultItems)))
        .dynamicTypeSize(.accessibility5)
}
