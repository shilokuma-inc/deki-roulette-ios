import Foundation
import SwiftUI

/// ドメイン定数。Web 版 `src/config.ts` に対応する。
enum Config {
    static let spinDuration: TimeInterval = 4.5

    /// アニメーション完了コールバックが呼ばれない環境（バックグラウンド等）向けの保険。
    static let spinFallback: TimeInterval = spinDuration + 0.6
    static let reducedMotionSpinDuration: TimeInterval = 0.32

    static let minItems = 2
    static let maxItems = 24
    static let maxLabelLength = 20

    /// 当たり指定の隠しジェスチャ。短すぎると通常のタップで誤爆する。
    static let longPressDuration: TimeInterval = 0.6

    /// 指定直後だけ印を見せる時間。以降はリストに触れない限り痕跡を残さない。
    static let targetHintDuration: TimeInterval = 1.6

    /// 順番の結果を 1 件ずつ出すときの間隔。
    static let orderRevealStep: TimeInterval = 0.16

    /// 結果 1 件が現れるアニメーションの長さ。演出の終了時刻の計算に使う。
    static let revealAnimationDuration: TimeInterval = 0.36

    /// 視差効果を減らす設定のときは 1 件ずつ出さないので、演出はこの時間で終わる。
    static let reducedMotionRevealDuration: TimeInterval = 0.2

    /// コピーできたことを伝える表示を出しておく時間。
    static let copyFeedbackDuration: TimeInterval = 1.8

    /// スピンのイージング（Web 版 `SPIN_EASING`）。`Theme.spinAnimation` と、触覚とクリック音の時刻の逆算で使う。
    static let spinEasing = CubicBezierCurve(0.15, 0.85, 0.3, 1)

    /// 追加の入力欄が伸びる行数の上限。改行区切りの貼り付けはこの行数を超えるとスクロールする。
    static let bulkInputVisibleLines = 5
    /// 名前を付けて保存できる項目リストの数。
    static let maxSavedLists = 20
    /// 保存するリストの名前の最大文字数（正規化後）。
    static let maxSavedListNameLength = 30

    /// スピンの周回数の範囲。フリックの強さもこの範囲の中に写す。
    static let fullSpinRange: ClosedRange<Int> = 4...8

    /// 盤面のフリックをスピンとみなす角速度（度/秒）の下限。これ未満では何もしない。
    static let flickMinAngularVelocity: Double = 240

    /// 周回数が上限に達する角速度（度/秒）。これ以上はすべて最大の周回数になる。
    static let flickMaxAngularVelocity: Double = 1800

    /// 盤面中心からこの半径（pt）の内側では角度が定まらないので、フリックの計算に使わない。
    static let flickDeadZoneRadius: Double = 24

    /// フリックの角速度を、指を離す直前のこの時間（秒）に回った角度から求める。
    static let flickSampleWindow: TimeInterval = 0.15

    /// 削除した項目を「元に戻す」で戻せる時間。過ぎると削除が確定する。
    static let undoDuration: TimeInterval = 5

    // MARK: スワイプ削除

    /// 行のスワイプを始めるまでに指が動く距離（pt）。長押しが不成立になる 10pt より大きくして、
    /// 長押しの途中でスワイプが始まらないようにする。
    static let swipeMinimumDistance: CGFloat = 20
    /// 行幅に対してこれより多く左に引いたら、指を離した時点で削除する。
    static let swipeDeleteRatio: CGFloat = 0.5

    // MARK: 触覚

    /// 触覚フィードバックの ON/OFF を保存する `UserDefaults` のキー。未設定なら ON。
    static let hapticsEnabledKey = "hapticsEnabled"

    /// スピン開始の手応え。
    static let hapticSpinStartWeight: SensoryFeedback.Weight = .medium

    /// 長押しで指定が切り替わった瞬間の、本人の指にだけ伝わる軽い手応え。
    static let hapticMarkToggleWeight: SensoryFeedback.Weight = .light

    /// 盤面を指で動かしている間に境目を越えた手応え。スピン中の刻み（`.selection`）より強くする。
    static let hapticDragBoundaryWeight: SensoryFeedback.Weight = .medium

    /// スピン中に境目を越える触覚を鳴らす最短間隔。序盤は境目を越える間隔がこれより短いので間引く。
    static let hapticMinInterval: TimeInterval = 0.06

    // MARK: 停止の強調

    /// 止まったスライスの光彩の色（`GlowStyle.rawValue`）を保存する `UserDefaults` のキー。未設定なら `GlowStyle.default`。
    static let glowStyleKey = "glowStyle"

    // MARK: 効果音

    /// 効果音の ON/OFF を保存する `UserDefaults` のキー。未設定なら ON。
    static let soundEnabledKey = "soundEnabled"

    /// スピン中にクリック音を鳴らす最短間隔。序盤は境目を越える間隔がこれより短いので間引く。
    static let clickMinInterval: TimeInterval = 0.032

    /// クリック音の音量。密に重なっても耳に刺さらないところまで下げてある。
    static let clickGain: Float = 0.7

    // MARK: 3D の盤の傾き

    /// 3D の盤を端末の姿勢に合わせて倒す最大角（度）。これより大きく傾けても盤はここで止める。
    static let wheelMaxTilt: Double = 25
}
