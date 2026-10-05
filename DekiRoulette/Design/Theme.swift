import SwiftUI
import UIKit

/// 配色・書体・アニメーション。Web 版 `tailwind.config.ts` の `theme.extend` に対応する。
///
/// 色は端末の外観設定に従う。トークン名は Web 版のまま据え置き、ライトでは役割ごとに値を反転させる
/// （`ink` 系は「地の側」、`ivory` と `muted` は「文字の側」として読む）。
/// 盤面だけは外観に依らず同じ見た目にする（`MARK: 盤面` を参照）。
enum Theme {
    /// 画面の背景。スライスの区切り線とラベルには使わない（`onSlice` を使う）。
    /// ローンチ画面の `LaunchBackground`（`Assets.xcassets`）にも同じ 2 値を置いているので、変えるときは両方を合わせる。
    static let ink900 = Color(light: 0xFAF7F2, dark: 0x17111F)
    /// カード・入力欄・タブバーの背景。
    static let ink800 = Color(light: 0xFFFFFF, dark: 0x1F1829)
    /// 枠線、無効ボタンの背景。
    static let ink700 = Color(light: 0xE6DFD5, dark: 0x2A2138)
    /// 入力欄の枠、破線枠。
    static let ink600 = Color(light: 0xD5CBBE, dark: 0x3A2F4C)
    /// 指定中の行の枠。
    static let ink500 = Color(light: 0xB6A9C6, dark: 0x4C3F62)
    /// 削除ボタン。
    static let ink400 = Color(light: 0x7A6C90, dark: 0x7D6D96)
    /// 本文。
    static let ivory = Color(light: 0x241C30, dark: 0xF5EFE6)
    /// 補助テキスト。
    static let muted = Color(light: 0x655877, dark: 0xA99BBD)

    /// 順番決めの 1 位とフォーカスリング専用。ルーレットの結果は `sliceAccent(at:)` を使う。
    static let gold = Color(light: 0x8A6410, dark: 0xFFC94A)

    /// スピン・並べ替えの操作専用。塗りは両モードで同じ色。
    static let flare = Color(hex: 0xFF4E63)
    /// `flare` を文字に使うときの色。ライトの地では塗りのままだと読めないため濃くする。
    static let flareText = Color(light: 0xC81E37, dark: 0xFF4E63)
    /// `flare` の塗りに乗る文字。塗りが固定なので文字も固定。
    static let onFlare = Color(hex: 0x17111F)
    /// 開始ボタンの光。ライトの地では強く出すぎるため弱める。
    static let flareGlow = Color(light: 0xFF4E63, dark: 0xFF4E63, lightAlpha: 0.3, darkAlpha: 0.45)

    // MARK: 盤面

    // 盤面は外観設定に依らず同じ見た目にする。スライスは「明るい塗り + 暗い文字」でコントラストを
    // 取っているため、地の側だけ反転させると成り立たなくなる。

    /// スライスの区切り線とラベル。
    static let onSlice = Color(hex: 0x17111F)
    /// 盤面の縁。
    static let wheelRim = Color(hex: 0x2A2138)
    /// 盤面の外周線。
    static let wheelEdge = Color(hex: 0x4C3F62)
    /// 中心のハブ。
    static let wheelHub = Color(hex: 0x1F1829)
    /// ハブの枠と中心の点。
    static let wheelHubMark = Color(hex: 0xF5EFE6)
    /// 盤面の影。ライトの地では濃く出すぎるため弱める。
    static let wheelShadow = Color(light: 0x000000, dark: 0x000000, lightAlpha: 0.2, darkAlpha: 0.5)
    /// 針の影。
    static let pointerShadow = Color(light: 0x000000, dark: 0x000000, lightAlpha: 0.25, darkAlpha: 0.55)

    // MARK: スライスの色

    /// 盤面のスライスを塗る 10 色。彩度と明度を揃えてあり、ラベルとセパレータを `onSlice` で描くため、
    /// どのスライスも暗色テキストで 4.5:1 を超える明るさに寄せてある。外観設定では変えない。
    private static let slicePaints: [UInt32] = [
        0xFF8080, 0xFFA366, 0xF2CE5C, 0xA3DB6B, 0x5FD6A8,
        0x5CC9E0, 0x7BAEF5, 0xA48CF0, 0xCE8CEE, 0xFF85C0,
    ]

    /// ライトの地に文字や細い枠として置くための、同じ色相のまま暗くした 10 色。
    /// 明るい塗りのままでは白地で読めないため用意している。
    private static let sliceInks: [UInt32] = [
        0xD92323, 0xAF571D, 0x856D20, 0x557B30, 0x327C60,
        0x2F7A8A, 0x2F6FC8, 0x785CD0, 0x9E48C8, 0xD32278,
    ]

    /// 盤面の塗り。
    static let sliceColors: [Color] = slicePaints.map { Color(hex: $0) }

    /// 文字・色見本・細い枠に使うスライス色。指定中の印にも専用色は使わずこれを流用する。
    static let sliceAccents: [Color] = zip(sliceInks, slicePaints).map { Color(light: $0, dark: $1) }

    static func sliceColor(at index: Int) -> Color {
        sliceColors[index % sliceColors.count]
    }

    static func sliceAccent(at index: Int) -> Color {
        sliceAccents[index % sliceAccents.count]
    }

    static let spinAnimation = Animation.timingCurve(0.15, 0.85, 0.3, 1, duration: Config.spinDuration)

    /// 結果が現れる演出。両画面で使い回す。
    static let revealAnimation = Animation.timingCurve(0.2, 0.9, 0.3, 1, duration: Config.revealAnimationDuration)

    // MARK: レイアウト

    /// 画面の寸法。Web 版では Tailwind のユーティリティ（`max-w-3xl` / `w-[min(320px,78vw)]`）だったもの。
    /// 横並び（`horizontalSizeClass == .regular`、主に iPad）では盤面を基準より大きく描く。
    enum Layout {
        /// 縦積みでの盤面の上限。ラベルの省略と文字サイズの基準（`WheelLabel.referenceDiameter`）と同じ大きさ。
        static let wheelMaxWidthCompact = CGFloat(WheelLabel.referenceDiameter)
        /// 横並びでの盤面の上限。13 インチ iPad の横向きで余白が目立たない大きさ。
        static let wheelMaxWidthRegular: CGFloat = 480
        /// 横並びでの項目リストの幅。
        static let listWidthRegular: CGFloat = 360
        /// 横並びの 2 列の間隔。縦積みでは上下の間隔に使う。
        static let columnSpacing: CGFloat = 48
        /// ページの左右の余白。
        static let pageHorizontalPadding: CGFloat = 20
        /// ページ全体の上限。横並びの 2 列 + 間隔 + 左右の余白がちょうど収まる幅。
        /// compact の端末はこれより狭いので、縦積みの見え方には影響しない。
        static let pageMaxWidth = wheelMaxWidthRegular + columnSpacing + listWidthRegular + pageHorizontalPadding * 2
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 端末の外観設定に追従する色。
    init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

/// 結果が現れる演出。Web 版の `animate-reveal` に対応する。
struct RevealModifier: ViewModifier {
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .scaleEffect(shown ? 1 : 0.96)
    }
}

/// 表示された時点から `delay` 後に現れる。`reducedMotion` のときは即座に出す。
struct RevealOnAppear: ViewModifier {
    let delay: TimeInterval
    let reducedMotion: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .modifier(RevealModifier(shown: shown))
            .onAppear {
                if reducedMotion {
                    shown = true
                } else {
                    withAnimation(Theme.revealAnimation.delay(delay)) { shown = true }
                }
            }
    }
}

extension View {
    func revealOnAppear(delay: TimeInterval = 0, reducedMotion: Bool) -> some View {
        modifier(RevealOnAppear(delay: delay, reducedMotion: reducedMotion))
    }
}
