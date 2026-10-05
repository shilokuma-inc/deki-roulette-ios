import SwiftUI

struct RouletteScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    let model: RouletteModel

    var body: some View {
        PageFrame(
            title: L10n.title,
            tagline: L10n.tagline,
            busy: model.spinning,
            useCases: L10n.useCases
        ) {
            Text(L10n.helpBasic)
            HelpHeading(text: L10n.helpAimTitle)
            Text(L10n.helpAim)
            Text(L10n.helpAimStealth)
            Text(L10n.helpAimRandom)
        } content: {
            AdaptiveStack(horizontal: regular, alignment: .center, spacing: Theme.Layout.columnSpacing) {
                wheelSection
                ItemListView(
                    items: model.items,
                    marks: model.marks,
                    busy: model.spinning,
                    concealMarks: model.spinning,
                    atCapacity: model.atCapacity,
                    onAdd: { model.addItems($0) },
                    onRemove: { model.removeItem(id: $0) },
                    onLongPress: { model.toggleTarget(id: $0) }
                )
                .frame(maxWidth: regular ? Theme.Layout.listWidthRegular : .infinity)
            }
        }
        .onChange(of: model.result) { _, result in
            if let result {
                AccessibilityNotification.Announcement(L10n.resultAnnounce(result)).post()
            }
        }
    }

    private var regular: Bool { sizeClass == .regular }

    private var wheelSection: some View {
        VStack(spacing: 24) {
            RouletteWheelView(items: model.items, rotation: model.rotation)
                .frame(maxWidth: regular ? Theme.Layout.wheelMaxWidthRegular : Theme.Layout.wheelMaxWidthCompact)

            // 結果の有無で下のボタンが動かないよう高さを固定する。大きい文字では枠からはみ出るので最小高さだけ残す
            resultStatus
                .frame(minHeight: 56, maxHeight: TypeLayout.growsFixedAreas(for: typeSize) ? nil : 56)

            PrimaryActionButton(
                title: model.spinning ? L10n.spinning : L10n.spin,
                busy: model.spinning,
                enabled: model.canSpin,
                action: spin
            )

            ZStack {
                // 結果が出ている間だけ出す。順番決めと同じ位置・同じ見た目
                if let outcome = model.outcome, !model.spinning {
                    let text = ResultText.roulette(label: outcome.label, heading: L10n.resultHeading)
                    ResultActions(copyText: text, shareText: ResultText.share(text, appName: L10n.appName))
                        .id(outcome.label + "\(model.rotation)")
                }
            }
            .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var resultStatus: some View {
        if let outcome = model.outcome {
            // 止まったスライスと同じ色で出す
            let color = Theme.sliceAccent(at: outcome.index)
            Text(outcome.label)
                .font(.title3.weight(.black))
                .foregroundStyle(color)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(color.opacity(0.1), in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.6), lineWidth: 1))
                .revealOnAppear(reducedMotion: reduceMotion)
                .id(outcome.label + "\(model.rotation)")
        } else {
            Text(model.spinning ? L10n.spinning : L10n.resultPlaceholder)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private func spin() {
        guard let next = model.beginSpin(reducedMotion: reduceMotion) else { return }
        if reduceMotion {
            // 動きを減らす設定では回さずに止まる。終了は保険のタイマーが担う
            model.rotation = next
        } else {
            withAnimation(Theme.spinAnimation) {
                model.rotation = next
            } completion: {
                model.finishSpin()
            }
        }
    }
}

#Preview {
    RouletteScreen(model: RouletteModel(items: ItemLabel.makeItems(L10n.defaultItems)))
}

#Preview("AX5") {
    RouletteScreen(model: RouletteModel(items: ItemLabel.makeItems(L10n.defaultItems)))
        .dynamicTypeSize(.accessibility5)
}
