import SwiftUI

struct RouletteScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(Config.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(Config.soundEnabledKey) private var soundEnabled = true
    @AppStorage(Config.glowStyleKey) private var glowStyle = GlowStyle.default
    let model: RouletteModel
    @State private var sound = SpinSoundPlayer()

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
                    onRemoveAll: { model.removeAll() },
                    onRestore: { model.restore($0, at: $1) },
                    onLongPress: { model.toggleTarget(id: $0) },
                    onLoad: { model.replaceItems($0) }
                )
                .frame(maxWidth: regular ? Theme.Layout.listWidthRegular : .infinity)
            }
        }
        .onChange(of: model.result) { _, result in
            if let result {
                AccessibilityNotification.Announcement(L10n.resultAnnounce(result)).post()
            }
        }
        // 触覚: 開始の手応え、境目ごとの刻み、止まった手応え。設定で OFF にできる
        .sensoryFeedback(trigger: model.spinning) { _, spinning in
            hapticsEnabled && spinning ? .impact(weight: Config.hapticSpinStartWeight) : nil
        }
        .sensoryFeedback(trigger: model.boundaryTick) { _, _ in
            hapticsEnabled ? .selection : nil
        }
        // 指で動かしている間の境目は、スピン中の刻みより強く返す
        .sensoryFeedback(trigger: model.dragBoundaryTick) { _, _ in
            hapticsEnabled ? .impact(weight: Config.hapticDragBoundaryWeight) : nil
        }
        .sensoryFeedback(trigger: model.outcome) { _, outcome in
            hapticsEnabled && outcome != nil ? .success : nil
        }
        .onAppear { if soundEnabled { sound.prepare() } }
        .onDisappear { sound.stop() }
    }

    private var regular: Bool { sizeClass == .regular }

    private var wheelSection: some View {
        VStack(spacing: 24) {
            RouletteWheelView(
                items: model.items,
                rotation: model.rotation,
                // 結果が出ている間だけ止まったスライスを強調する。項目を触って結果が消えれば強調も解ける
                highlightedIndex: model.outcome?.index,
                interactive: !model.spinning,
                spinEasing: model.spinEasing,
                glowStyle: glowStyle,
                onBoundaryCross: dragCrossedBoundary,
                onRelease: release
            )
            // 帯は回転しない層に置く（盤面の `rotationEffect` の外側）。盤面のフリックを妨げないよう触れられなくする
            .overlay(alignment: .top) { resultBand }
            .frame(maxWidth: regular ? Theme.Layout.wheelMaxWidthRegular : Theme.Layout.wheelMaxWidthCompact)

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
                        .id(outcome.label + "\(model.spinCount)")
                }
            }
            .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    /// 針のすぐ下に重ねる結果の帯。盤面の下に結果の領域は持たず、結果のラベルはここで全文を出す（盤面のラベルは省略される）。
    /// 出し直しは `spinCount` 基準で、指で盤面を動かしても出し直さない。
    /// 盤面と同じく装飾扱いで読み上げない（結果は Announcement で伝える）。
    @ViewBuilder
    private var resultBand: some View {
        if let outcome = model.outcome, !model.spinning {
            GeometryReader { proxy in
                let diameter = Double(min(proxy.size.width, proxy.size.height))
                let scale = diameter / WheelLabel.referenceDiameter
                Text(outcome.label)
                    .font(.system(size: ResultBand.fontSize(diameter: diameter), weight: .black))
                    .foregroundStyle(Theme.resultBandInk)
                    .lineLimit(1)
                    .minimumScaleFactor(ResultBand.minimumScaleFactor)
                    .truncationMode(.tail)
                    .padding(.horizontal, 14 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(Theme.resultBandFill, in: .capsule)
                    // 項目を変えると `outcome` は消えるので、件数はスピン開始時と同じ
                    .overlay(
                        Capsule().strokeBorder(Theme.sliceColor(at: outcome.index, count: model.items.count), lineWidth: 2 * scale)
                    )
                    .shadow(color: Theme.resultBandShadow, radius: 4 * scale, y: 2 * scale)
                    .frame(maxWidth: ResultBand.maxWidth(diameter: diameter))
                    .frame(maxWidth: .infinity)
                    .padding(.top, ResultBand.top(diameter: diameter, pointerBounce: Theme.pointerBounceOffset))
                    .revealOnAppear(reducedMotion: reduceMotion)
                    .id(outcome.label + "\(model.spinCount)")
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 「スピン」ボタン。直前のフリックの向きで回す。
    private func spin() {
        spin(fullSpins: nil, direction: nil, releaseVelocity: nil)
    }

    /// 指で動かしている盤面の針が境目を越えた。触覚はモデルの刻みで鳴り、回転音はここで 1 回鳴らす（間引きはモデル）。
    private func dragCrossedBoundary(at time: TimeInterval) {
        if model.crossDragBoundary(at: time), soundEnabled { sound.playClick() }
    }

    /// 盤面から指を離した。追従で回した角度を取り込み、その角度からフリックのスピンを始める。
    /// `dragRotation` の取り込みとスピンの開始は同じ更新に入れる（盤面が離した位置から回り出す）。
    /// 指を離さずにジェスチャが取り消されたとき（`angularVelocity` が nil）は、追従した角度を残すだけで回さない。
    private func release(angularVelocity: Double?, dragRotation: Double) {
        model.rotate(by: dragRotation)
        guard let angularVelocity else { return }
        flick(angularVelocity: angularVelocity, dragRotation: dragRotation)
    }

    /// 盤面のフリック。強さは周回数にだけ反映し、フリックした向きに回す。盤面は離した瞬間の速さで回り出し、そこから減速する。
    /// 閾値未満の弱いドラッグでも、最小の周回数で動かした向きに回す（`FlickSpin.releaseSpin`）。
    private func flick(angularVelocity: Double, dragRotation: Double) {
        let flick = FlickSpin.releaseSpin(
            angularVelocity: angularVelocity, dragRotation: dragRotation, fallback: model.lastDirection
        )
        spin(fullSpins: flick.fullSpins, direction: flick.direction, releaseVelocity: angularVelocity)
    }

    private func spin(fullSpins: Int?, direction: SpinDirection?, releaseVelocity: Double?) {
        guard let next = model.beginSpin(
            reducedMotion: reduceMotion, fullSpins: fullSpins, direction: direction, releaseVelocity: releaseVelocity
        ) else { return }
        if soundEnabled { sound.play(at: model.clickTimes) }
        if reduceMotion {
            // 動きを減らす設定では回さずに止まる。終了は保険のタイマーが担う
            model.rotation = next
        } else {
            withAnimation(Theme.spinAnimation(easing: model.spinEasing)) {
                model.rotation = next
            } completion: {
                model.finishSpin()
            }
        }
    }
}

#Preview {
    RouletteScreen(model: RouletteModel(items: ItemLabel.makeItems(L10n.defaultItems)))
        .environment(SavedListsModel(lists: []))
}

#Preview("AX5") {
    RouletteScreen(model: RouletteModel(items: ItemLabel.makeItems(L10n.defaultItems)))
        .dynamicTypeSize(.accessibility5)
}
