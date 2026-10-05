import SwiftUI

/// ヘッダ右上のアイコンから開く設定。触覚フィードバックの切替、項目の初期化、著作権の項目を置く。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Config.hapticsEnabledKey) private var hapticsEnabled = true
    // 両画面のモデルは RootView が environment に流している。どちらのタブから開いても両方を戻せる。
    @Environment(RouletteModel.self) private var rouletteModel
    @Environment(OrderModel.self) private var orderModel

    /// 確認ダイアログを出している対象。
    private enum ResetTarget: Identifiable {
        case roulette
        case order

        var id: Self { self }
    }

    @State private var resetTarget: ResetTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 文言はこの見出しだけ。何に使うかの説明は置かない（長押しの存在を示唆しないため）
                    SettingsToggle(title: L10n.hapticsTitle, isOn: $hapticsEnabled)

                    SettingsSection(title: L10n.resetItemsTitle) {
                        Text(L10n.resetItemsDescription)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(3)
                        resetButton(L10n.resetItemsRoulette, target: .roulette)
                        resetButton(L10n.resetItemsOrder, target: .order)
                    }
                    SettingsSection(title: L10n.copyrightTitle) {
                        Text(L10n.copyrightOwner)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ivory)
                            .lineSpacing(3)
                        Text(L10n.copyright)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Theme.ink900.ignoresSafeArea())
            .navigationTitle(L10n.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                        .foregroundStyle(Theme.ivory)
                }
            }
            .toolbarBackground(Theme.ink800, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .confirmationDialog(
                L10n.resetItemsConfirm(screenName(resetTarget)),
                isPresented: Binding(
                    get: { resetTarget != nil },
                    set: { if !$0 { resetTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: resetTarget
            ) { target in
                Button(L10n.resetItemsAction, role: .destructive) { reset(target) }
            } message: { _ in
                Text(L10n.resetItemsMessage)
            }
        }
    }

    private func resetButton(_ title: String, target: ResetTarget) -> some View {
        Button {
            resetTarget = target
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ivory)
                Spacer(minLength: 0)
                Image(systemName: "arrow.counterclockwise")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.ink700, in: .rect(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func screenName(_ target: ResetTarget?) -> String {
        switch target {
        case .roulette, nil: L10n.rouletteNavLabel
        case .order: L10n.orderNavLabel
        }
    }

    private func reset(_ target: ResetTarget) {
        switch target {
        case .roulette: rouletteModel.resetItems()
        case .order: orderModel.resetItems()
        }
    }
}

/// 設定の ON/OFF 1 項目。枠の中に見出しとスイッチを並べる。
private struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(Theme.ivory)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Theme.ink800, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.ink700, lineWidth: 1)
        }
    }
}

/// 設定の 1 項目。見出しと、枠で囲んだ中身。
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(Theme.ivory)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.ink800, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.ink700, lineWidth: 1)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(RouletteModel(items: ItemLabel.makeItems(L10n.defaultItems)))
        .environment(OrderModel(items: ItemLabel.makeItems(L10n.orderDefaultItems)))
        .fontDesign(.rounded)
}
