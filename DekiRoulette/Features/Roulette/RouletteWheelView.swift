import SwiftUI

/// 盤面の描画。回転は親が `rotation` を書き換え、このビューは `rotationEffect` で受ける（補間の曲線はこのビューが保証する）。
/// 角度は 12 時を 0 度として時計回りに数える。針は 12 時に固定。
///
/// `highlightedIndex` を渡すと、そのスライスを止まった位置として強調する（他を強く暗くし、止まったスライスに
/// 縁取りと光彩を付け、渡された瞬間に短く押し出して針を跳ねさせ、そのあとも少し大きいまま前に出しておく）。
/// nil に戻すと強調も解ける。
/// ドラッグ中は盤面を指に追従させ（`WheelDrag`）、指を離したら、追従で回した角度と、離す直前の動きから出した
/// 角速度（度/秒、時計回りが正）を `onRelease` に伝える。指を離さずにジェスチャが取り消されたときは角速度を nil で伝える。
/// 追従した角度は親が `rotation` に取り込むまでこのビューが持つ。
/// `interactive` が false の間（演出中）は追従もフリックもしない。
/// 追従で針がスライスの境目を越えたら、その時刻（秒）を `onBoundaryCross` に伝える（親が回転音と触覚を鳴らす）。
/// `spinEasing` はスピンの曲線。フリックでは離した瞬間の速さに合わせて親が決める（ボタンでは `Config.spinEasing`）。
struct RouletteWheelView: View {
    let items: [Item]
    let rotation: Double
    var highlightedIndex: Int? = nil
    var interactive = true
    var spinEasing = Config.spinEasing
    /// 止まったスライスの光彩の色（設定の「ルーレットの詳細設定」）。
    var glowStyle = GlowStyle.default
    var onBoundaryCross: ((_ time: TimeInterval) -> Void)? = nil
    var onRelease: ((_ angularVelocity: Double?, _ dragRotation: Double) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    @State private var flickSamples = FlickSampleBuffer()
    /// 追従で回した角度。指を離すと親に渡して 0 に戻す。親の `rotation` と違ってスピンの曲線で補間しない
    @State private var dragRotation = 0.0
    /// 結果が出たあとに盤面を指で動かした。止まったスライスが針の下から外れるので強調を解く
    @State private var displacedByDrag = false
    @State private var dragSession = WheelDragSession()
    @GestureState private var dragging = false

    /// 強調するスライス。結果が出たあとに指で動かしたら解く（結果の表示は残る）。
    private var effectiveHighlight: Int? { displacedByDrag ? nil : highlightedIndex }

    /// 線幅・縁・ハブはこの直径を 1 として `scale` で比例させる。ラベルの文字サイズと省略は `WheelLabel` に任せる。
    private static let referenceSize = CGFloat(WheelLabel.referenceDiameter)
    private static let ink = Theme.onSlice

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                wheel(side: side)
                    .frame(width: side, height: side)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            // 追従の角度は足すだけにする。ドラッグ中は `rotation` が変わらないので下の `.animation` は掛からず、指にそのまま付いてくる。
            // 指を離した更新では、親が追従の角度を `rotation` に取り込むのと `dragRotation` を 0 に戻すのが同じ更新に入るので、
            // 見た目の角度は離した位置から続く
            .rotationEffect(.degrees(rotation + dragRotation))
            // キーボードが出た状態で始めると、演出開始で入力欄が無効になってキーボードが閉じ、その安全領域の変化が
            // `withAnimation` の更新に重なって補間が落ちる（盤面が最終角度へ飛び、音だけが鳴る）。回転の値の変化だけは
            // 外側のトランザクションに依らずスピンの曲線で補間させる。曲線は親の `withAnimation` と同じ `spinEasing`。
            // 動きを減らす設定では親が値を直接書くので付けない
            .animation(reduceMotion ? nil : Theme.spinAnimation(easing: spinEasing), value: rotation)
            .shadow(color: Theme.wheelShadow, radius: 15, y: 10)

            pointer
                .offset(y: -6 + (pulsing ? Theme.pointerBounceOffset : 0))
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            // ドラッグ中は盤面を指に追従させ、指を離したらその角度からスピンを始める（結果は開始時に決まり、そこから止める）
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .highPriorityGesture(flickGesture(center: CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)))
            }
        }
        .onChange(of: dragging) { _, isDragging in
            // 指を離さずにジェスチャが取り消されたときも、追従した角度を親に渡して残す（盤面がその角度で止まり、回さない）。
            // 指を離したときは `onEnded` が先に片付けるので、次のランループで残っているときだけ扱う
            guard !isDragging else { return }
            Task { @MainActor in release(angularVelocity: nil) }
        }
        .onChange(of: highlightedIndex) { _, index in
            // 新しい結果（または結果なし）になったら、指で動かした分の強調の解除を戻す
            displacedByDrag = false
            // 止まった瞬間だけ押し出す。動きを減らす設定では暗くするだけにする
            guard index != nil, !reduceMotion else {
                pulsing = false
                return
            }
            withAnimation(Theme.stopPulseAnimation) {
                pulsing = true
            } completion: {
                withAnimation(Theme.stopSettleAnimation) { pulsing = false }
            }
        }
        .accessibilityHidden(true)
    }

    private var pointer: some View {
        Triangle()
            .fill(Theme.flare)
            .frame(width: 22, height: 26)
            .shadow(color: Theme.pointerShadow, radius: 3, y: 3)
    }

    private func flickGesture(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                // 演出中に触り始めたドラッグは、指を離すまで追従もフリックもしない（途中で演出が終わっても拾わない）
                if !dragSession.started {
                    dragSession.started = true
                    dragSession.ignored = !interactive
                }
                guard !dragSession.ignored else { return }
                follow(
                    to: value.location, from: dragSession.lastLocation ?? value.startLocation, center: center,
                    time: value.time.timeIntervalSinceReferenceDate
                )
                flickSamples.append(FlickSpin.Sample(time: value.time.timeIntervalSinceReferenceDate, location: value.location))
            }
            .onEnded { value in
                guard dragSession.started, !dragSession.ignored else {
                    dragSession.reset()
                    return
                }
                follow(
                    to: value.location, from: dragSession.lastLocation ?? value.startLocation, center: center,
                    time: value.time.timeIntervalSinceReferenceDate
                )
                flickSamples.append(FlickSpin.Sample(time: value.time.timeIntervalSinceReferenceDate, location: value.location))
                release(angularVelocity: FlickSpin.angularVelocity(samples: flickSamples.samples, center: center))
            }
    }

    /// 前の位置から今の位置までに指が中心のまわりを回った分だけ盤面を回す。針が境目を越えたら親に伝える（音と触覚）。
    private func follow(to location: CGPoint, from previous: CGPoint, center: CGPoint, time: TimeInterval) {
        dragSession.lastLocation = location
        let delta = WheelDrag.rotationDelta(from: previous, to: location, center: center)
        guard delta != 0 else { return }
        let before = rotation + dragRotation
        dragRotation += delta
        if highlightedIndex != nil { displacedByDrag = true }
        if WheelDrag.boundaryCrossings(from: before, to: rotation + dragRotation, count: items.count) > 0 {
            onBoundaryCross?(time)
        }
    }

    /// 指を離した（またはジェスチャが取り消された。角速度は nil）。追従した角度と角速度を親に渡す。
    /// `dragRotation` を 0 に戻すのと、親がそれを `rotation` に取り込むのを同じ更新に入れて、盤面が跳ねないようにする。
    private func release(angularVelocity: Double?) {
        let active = dragSession.started && !dragSession.ignored
        dragSession.reset()
        flickSamples.reset()
        guard active else { return }
        let rotated = dragRotation
        dragRotation = 0
        onRelease?(angularVelocity, rotated)
    }

    private func wheel(side: CGFloat) -> some View {
        let scale = side / Self.referenceSize
        let radius = side / 2 - 16 * scale
        let center = CGPoint(x: side / 2, y: side / 2)
        let count = items.count
        let sliceAngle = count > 0 ? 360.0 / Double(count) : 360
        let maxLabelLength = WheelLabel.limit(count: count, diameter: side)
        let fontSize = WheelLabel.fontSize(count: count, diameter: side)

        return ZStack {
            Circle().fill(Theme.wheelRim)
                .frame(width: (radius + 11 * scale) * 2, height: (radius + 11 * scale) * 2)
            Circle().strokeBorder(Theme.wheelEdge, lineWidth: 1.5 * scale)
                .frame(width: (radius + 5 * scale) * 2, height: (radius + 5 * scale) * 2)

            if count == 0 {
                Circle().fill(Theme.wheelRim).frame(width: radius * 2, height: radius * 2)
            } else if count == 1 {
                let highlighted = effectiveHighlight == 0
                Circle().fill(Theme.sliceColor(at: 0, count: count))
                    .overlay(
                        Circle().strokeBorder(Theme.stopOutline, lineWidth: Theme.stopOutlineWidth * scale)
                            .opacity(highlighted ? 1 : 0)
                    )
                    .modifier(StopGlow(
                        shape: Circle(), style: glowStyle, sliceColor: Theme.sliceColor(at: 0, count: count),
                        shown: highlighted, radius: Theme.stopGlowRadius * scale
                    ))
                    .animation(reduceMotion ? nil : Theme.stopDimAnimation, value: highlighted)
                    .frame(width: radius * 2, height: radius * 2)
                Text(WheelLabel.truncate(items[0].label, limit: maxLabelLength))
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Self.ink)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let start = Double(index) * sliceAngle
                    let end = start + sliceAngle
                    let mid = start + sliceAngle / 2
                    let labelPoint = polar(center: center, angle: mid, radius: radius * WheelLabel.radiusFraction)
                    let highlighted = index == effectiveHighlight
                    let dimmed = effectiveHighlight != nil && !highlighted

                    ZStack {
                        SliceShape(startAngle: start, endAngle: end, radius: radius)
                            .fill(Theme.sliceColor(at: index, count: count))
                            .overlay(
                                SliceShape(startAngle: start, endAngle: end, radius: radius)
                                    .stroke(Self.ink, lineWidth: 2 * scale)
                            )

                        Text(WheelLabel.truncate(item.label, limit: maxLabelLength))
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundStyle(Self.ink)
                            .fixedSize()
                            // 左半分はそのまま回すと文字が上下逆さまになるため 180 度返す
                            .rotationEffect(.degrees(WheelLabel.rotation(midAngle: mid)))
                            .position(labelPoint)
                    }
                    // 止まったスライス以外に地色を薄く重ねて沈める
                    .overlay(
                        SliceShape(startAngle: start, endAngle: end, radius: radius)
                            .fill(Theme.sliceDim)
                            .opacity(dimmed ? 1 : 0)
                    )
                    // 止まったスライスは縁取りと外側への光彩で浮かせる（前に出すので光彩は沈めた隣に重なる）
                    .overlay(
                        SliceShape(startAngle: start, endAngle: end, radius: radius)
                            .stroke(Theme.stopOutline, style: StrokeStyle(lineWidth: Theme.stopOutlineWidth * scale, lineJoin: .round))
                            .opacity(highlighted ? 1 : 0)
                    )
                    .modifier(StopGlow(
                        shape: SliceShape(startAngle: start, endAngle: end, radius: radius), style: glowStyle,
                        sliceColor: Theme.sliceColor(at: index, count: count), shown: highlighted,
                        radius: Theme.stopGlowRadius * scale
                    ))
                    .animation(reduceMotion ? nil : Theme.stopDimAnimation, value: dimmed)
                    .animation(reduceMotion ? nil : Theme.stopDimAnimation, value: highlighted)
                    // 止まった瞬間に押し出し、結果が出ている間は少し大きいまま残す。隣に隠れないよう強調中だけ前に出す。
                    // 強調が解けたら（結果が消えた・指で動かした）弾ませて元の大きさに戻す
                    .scaleEffect(sliceScale(highlighted: highlighted))
                    .animation(reduceMotion ? nil : Theme.stopSettleAnimation, value: highlighted)
                    .zIndex(highlighted ? 1 : 0)
                }
            }

            Group {
                Circle().fill(Theme.wheelHub)
                    .overlay(Circle().strokeBorder(Theme.wheelHubMark, lineWidth: 2.5 * scale))
                    .frame(width: 38 * scale, height: 38 * scale)
                Circle().fill(Theme.wheelHubMark).frame(width: 12 * scale, height: 12 * scale)
            }
            .zIndex(2)
        }
        .frame(width: side, height: side)
    }

    /// 止まったスライスの倍率。動きを減らす設定では大きさを変えない（暗くする・縁取り・光彩だけにする）。
    private func sliceScale(highlighted: Bool) -> CGFloat {
        guard highlighted, !reduceMotion else { return 1 }
        return pulsing ? Theme.stopPulseScale : Theme.stopHoldScale
    }

    private func polar(center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
        let rad = (angle - 90) * .pi / 180
        return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
    }
}

/// 1 回のドラッグの途中経過。指が動くたびに書き換えるので、View を描き直さないよう参照型で持つ。
@MainActor
final class WheelDragSession {
    /// ドラッグが始まり、まだ指を離していない。
    var started = false
    /// 演出中に始まったドラッグ。指を離すまで追従もフリックもしない。
    var ignored = false
    /// 直前に追従した指の位置。nil ならまだ追従していない（最初の 1 回は `startLocation` から測る）。
    var lastLocation: CGPoint?

    func reset() {
        started = false
        ignored = false
        lastLocation = nil
    }
}

/// 止まったスライスの外側への光彩。白系と止まったスライスの色は影でにじませる。
/// 虹色は影にできないので、スライスの輪郭を角度のグラデーションで太くなぞってぼかし、スライスの後ろに敷く
/// （スライスの塗りは不透明なので、外側にはみ出した分だけが見える）。
private struct StopGlow<S: Shape>: ViewModifier {
    let shape: S
    let style: GlowStyle
    let sliceColor: Color
    let shown: Bool
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .white:
            content.shadow(color: shown ? Theme.stopGlow : .clear, radius: radius)
        case .slice:
            content.shadow(color: shown ? sliceColor.opacity(Theme.stopGlowOpacity) : .clear, radius: radius)
        case .rainbow:
            content.background(
                shape.stroke(Theme.stopGlowRainbow, lineWidth: radius)
                    .blur(radius: radius / 2)
                    .opacity(shown ? 1 : 0)
            )
        }
    }
}

/// 12 時を 0 度とする時計回りの扇形。
struct SliceShape: Shape {
    let startAngle: Double
    let endAngle: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        // SwiftUI は y 軸が下向きなので、clockwise: false で画面上は時計回りになる
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("4 items") {
    RouletteWheelView(items: ItemLabel.makeItems(["ラーメン", "カレー", "寿司", "焼肉"]), rotation: 0)
        .padding(40)
        .background(Theme.ink900)
}

#Preview("12 items") {
    RouletteWheelView(items: ItemLabel.makeItems((1...12).map { "項目\($0)" }), rotation: 30)
        .padding(40)
        .background(Theme.ink900)
}

#Preview("Stopped") {
    RouletteWheelView(
        items: ItemLabel.makeItems(["ラーメン", "カレー", "寿司", "焼肉"]),
        rotation: 45,
        highlightedIndex: 3
    )
    .padding(40)
    .background(Theme.ink900)
}
