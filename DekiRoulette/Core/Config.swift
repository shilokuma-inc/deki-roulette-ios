import Foundation

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

    /// 盤面中心からこの半径（pt）の内側では角速度が発散するので、フリックとして扱わない。
    static let flickDeadZoneRadius: Double = 24

    /// 削除した項目を「元に戻す」で戻せる時間。過ぎると削除が確定する。
    static let undoDuration: TimeInterval = 5
}
