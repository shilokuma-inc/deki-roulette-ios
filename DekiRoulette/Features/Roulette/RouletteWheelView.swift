import SwiftUI

/// 盤面の描画。回転は親が `rotation` を書き換え、このビューは `rotationEffect` で受ける。
/// 角度は 12 時を 0 度として時計回りに数える。針は 12 時に固定。
struct RouletteWheelView: View {
    let items: [Item]
    let rotation: Double

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
            .rotationEffect(.degrees(rotation))
            .shadow(color: Theme.wheelShadow, radius: 15, y: 10)

            pointer
                .offset(y: -6)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var pointer: some View {
        Triangle()
            .fill(Theme.flare)
            .frame(width: 22, height: 26)
            .shadow(color: Theme.pointerShadow, radius: 3, y: 3)
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
                Circle().fill(Theme.sliceColor(at: 0)).frame(width: radius * 2, height: radius * 2)
                Text(WheelLabel.truncate(items[0].label, limit: maxLabelLength))
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Self.ink)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let start = Double(index) * sliceAngle
                    let end = start + sliceAngle
                    let mid = start + sliceAngle / 2
                    let labelPoint = polar(center: center, angle: mid, radius: radius * 0.62)

                    SliceShape(startAngle: start, endAngle: end, radius: radius)
                        .fill(Theme.sliceColor(at: index))
                        .overlay(
                            SliceShape(startAngle: start, endAngle: end, radius: radius)
                                .stroke(Self.ink, lineWidth: 2 * scale)
                        )

                    Text(WheelLabel.truncate(item.label, limit: maxLabelLength))
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundStyle(Self.ink)
                        .fixedSize()
                        // 左半分はそのまま回すと文字が上下逆さまになるため 180 度返す
                        .rotationEffect(.degrees(mid > 180 ? mid + 90 : mid - 90))
                        .position(labelPoint)
                }
            }

            Circle().fill(Theme.wheelHub)
                .overlay(Circle().strokeBorder(Theme.wheelHubMark, lineWidth: 2.5 * scale))
                .frame(width: 38 * scale, height: 38 * scale)
            Circle().fill(Theme.wheelHubMark).frame(width: 12 * scale, height: 12 * scale)
        }
        .frame(width: side, height: side)
    }

    private func polar(center: CGPoint, angle: Double, radius: CGFloat) -> CGPoint {
        let rad = (angle - 90) * .pi / 180
        return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
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
