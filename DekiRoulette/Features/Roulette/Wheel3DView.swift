import SceneKit
import SwiftUI

/// 3D 表示の盤面（設定の「3D 表示」が ON のとき）。厚みのある盤・外周の縁・中心のハブと、盤を裏から 1 点で支える支柱を
/// SceneKit で描く。OFF のときの `RouletteWheelView` と同じく、回転は親が `rotation` を書き換え、補間の曲線はこのビューが保証する。
/// 補間は SwiftUI に任せ（`Wheel3DSurface` の `animatableData`）、毎フレームの角度を SceneKit の盤に写すだけにするので、
/// 2D と同じ時刻に同じ角度で止まる。スピンの完了判定は今どおり親の `withAnimation … completion:` と保険のタイマーが担う。
struct Wheel3DView: View {
    let items: [Item]
    let rotation: Double
    var spinEasing = Config.spinEasing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Wheel3DSurface(items: items, rotation: rotation, diameter: side, displayScale: displayScale)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        // 2D の盤面と同じく、回転の値の変化だけは外側のトランザクションに依らずスピンの曲線で補間させる
        // （キーボードが閉じる更新に重なっても盤面が最終角度へ飛ばない）。動きを減らす設定では親が値を直接書くので付けない
        .animation(reduceMotion ? nil : Theme.spinAnimation(easing: spinEasing), value: rotation)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// 補間中の回転角を毎フレーム受け取る層。SwiftUI が `animatableData` を補間して `body` を描き直す。
private struct Wheel3DSurface: View, Animatable {
    let items: [Item]
    var rotation: Double
    let diameter: CGFloat
    let displayScale: CGFloat

    nonisolated var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    var body: some View {
        Wheel3DSceneView(items: items, rotation: rotation, diameter: diameter, displayScale: displayScale)
    }
}

private struct Wheel3DSceneView: UIViewRepresentable {
    let items: [Item]
    let rotation: Double
    let diameter: CGFloat
    let displayScale: CGFloat

    func makeCoordinator() -> Wheel3DScene {
        Wheel3DScene()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        // 触れたときの操作は SwiftUI 側で受ける
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(labels: items.map(\.label), diameter: diameter, displayScale: displayScale)
        context.coordinator.spin(to: rotation)
    }
}

/// 盤面の 3D の場面。項目のラベルと大きさが変わったときだけ組み直し、回転は盤のノードの角度を書き換えるだけにする。
@MainActor
final class Wheel3DScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    /// 盤を傾けるノード（支点は表面の中心）。支柱は傾けない。
    private let tiltNode = SCNNode()
    /// 盤を回すノード。スライス・縁・ハブを載せる。
    private let spinNode = SCNNode()
    private let postNode = SCNNode()

    private struct Shape: Equatable {
        let labels: [String]
        let diameter: CGFloat
        let displayScale: CGFloat

        var count: Int { labels.count }
    }

    private var built: Shape?

    init() {
        let camera = SCNCamera()
        camera.fieldOfView = Theme.Wheel3D.fieldOfView
        camera.projectionDirection = .vertical
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = Theme.Wheel3D.ambientLight
        scene.rootNode.addChildNode(ambient)

        // 左上の手前から照らす。表面のスライスは照明に依らないので、側面・縁・支柱にだけ陰影が付く
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = Theme.Wheel3D.keyLight
        key.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi / 8, 0)
        scene.rootNode.addChildNode(key)

        tiltNode.addChildNode(spinNode)
        scene.rootNode.addChildNode(tiltNode)
        scene.rootNode.addChildNode(postNode)
    }

    /// 項目のラベル（件数）か大きさが変わっていれば盤を組み直す。`displayScale` はラベルを焼く画像の倍率。
    func update(labels: [String], diameter: CGFloat, displayScale: CGFloat = 2) {
        let shape = Shape(labels: labels, diameter: diameter, displayScale: max(displayScale, 1))
        guard shape != built, diameter > 0 else { return }
        built = shape
        build(shape)
    }

    /// 盤を累積の回転角 `rotation`（度、時計回りが正）まで回す。
    func spin(to rotation: Double) {
        spinNode.eulerAngles.z = Float(WheelGeometry.spinAngle(rotation: rotation))
    }

    private func build(_ shape: Shape) {
        spinNode.childNodes.forEach { $0.removeFromParentNode() }
        postNode.childNodes.forEach { $0.removeFromParentNode() }

        let diameter = Double(shape.diameter)
        let scale = diameter / WheelLabel.referenceDiameter
        // 2D の盤面と同じ割り付け（外周の縁の内側にスライスを置く）
        let radius = diameter / 2 - 16 * scale
        let thickness = Double(Theme.Wheel3D.thickness) * scale
        let count = shape.count

        cameraNode.position = SCNVector3(
            0, 0, Float(WheelGeometry.cameraDistance(diameter: diameter, fieldOfView: Theme.Wheel3D.fieldOfView))
        )
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = diameter * 10

        if count == 0 {
            spinNode.addChildNode(sliceNode(start: 0, end: 360, radius: radius, thickness: thickness, color: Theme.wheelRim))
        } else {
            let sliceAngle = 360 / Double(count)
            for index in 0..<count {
                let start = Double(index) * sliceAngle
                spinNode.addChildNode(sliceNode(
                    start: start, end: start + sliceAngle, radius: radius, thickness: thickness,
                    color: Theme.sliceColor(at: index, count: count)
                ))
            }
            if count > 1 {
                addSeparators(count: count, radius: radius, scale: scale)
            }
            addLabels(shape, radius: radius)
        }
        addRim(radius: radius, thickness: thickness, scale: scale)
        addHub(scale: scale)
        addPost(thickness: thickness, scale: scale)
    }

    /// 1 枚のスライス。表面は照明に依らない塗り、外周の側面は陰影の付く同じ色。
    private func sliceNode(start: Double, end: Double, radius: Double, thickness: Double, color: Color) -> SCNNode {
        let mesh = WheelGeometry.sliceMesh(start: start, end: end, radius: radius, thickness: thickness)
        let vector = { (v: SIMD3<Double>) in SCNVector3(Float(v.x), Float(v.y), Float(v.z)) }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: mesh.vertices.map(vector)),
                SCNGeometrySource(normals: mesh.normals.map(vector)),
            ],
            elements: [
                SCNGeometryElement(indices: mesh.top, primitiveType: .triangles),
                SCNGeometryElement(indices: mesh.side, primitiveType: .triangles),
            ]
        )
        geometry.materials = [Self.material(color, lit: false), Self.material(color, lit: true)]
        return SCNNode(geometry: geometry)
    }

    /// スライスの境目と外周の線（2D の `onSlice` の線と同じ太さ）。
    private func addSeparators(count: Int, radius: Double, scale: Double) {
        let width = 2 * scale
        let ink = Self.material(Theme.onSlice, lit: false)
        let lift: Float = 0.2
        for index in 0..<count {
            let angle = 360 / Double(count) * Double(index)
            let line = SCNBox(width: width, height: radius, length: 0.1, chamferRadius: 0)
            line.materials = [ink]
            let node = SCNNode(geometry: line)
            let middle = WheelGeometry.point(angle: angle, radius: radius / 2)
            node.position = SCNVector3(Float(middle.x), Float(middle.y), lift)
            node.eulerAngles.z = Float(-angle * .pi / 180)
            spinNode.addChildNode(node)
        }
        spinNode.addChildNode(ring(inner: radius - width / 2, outer: radius + width / 2, z: lift, color: Theme.onSlice))
    }

    /// スライスのラベル。2D と同じ位置・向き・省略・文字サイズで 1 枚の画像に焼き、盤の表面（境目の線より手前）に貼る。
    private func addLabels(_ shape: Shape, radius: Double) {
        let diameter = Double(shape.diameter)
        let image = WheelLabelImage.render(
            labels: shape.labels, diameter: diameter, radius: radius, displayScale: shape.displayScale
        )
        let plane = SCNPlane(width: diameter, height: diameter)
        let material = Self.material(.white, lit: false)
        material.diffuse.contents = image
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.position.z = 0.3
        spinNode.addChildNode(node)
    }

    /// 外周の縁。盤の表面より少し手前に出し、2D と同じ位置に細い線を入れる。
    private func addRim(radius: Double, thickness: Double, scale: Double) {
        let lift = Double(Theme.Wheel3D.rimLift) * scale
        let rim = SCNTube(innerRadius: radius, outerRadius: radius + 11 * scale, height: thickness + lift)
        rim.radialSegmentCount = 96
        rim.materials = [Self.material(Theme.wheelRim, lit: true)]
        let node = SCNNode(geometry: rim)
        node.eulerAngles.x = .pi / 2
        node.position.z = Float((lift - thickness) / 2)
        spinNode.addChildNode(node)
        let edge = 5 * scale
        spinNode.addChildNode(ring(
            inner: radius + edge - 1.5 * scale, outer: radius + edge, z: Float(lift) + 0.1, color: Theme.wheelEdge
        ))
    }

    /// 中心のハブ。2D と同じ大きさで、盤の表面より手前に出す。
    private func addHub(scale: Double) {
        let lift = Double(Theme.Wheel3D.hubLift) * scale
        let hub = SCNCylinder(radius: 19 * scale, height: lift)
        hub.radialSegmentCount = 48
        hub.materials = [Self.material(Theme.wheelHub, lit: true)]
        let node = SCNNode(geometry: hub)
        node.eulerAngles.x = .pi / 2
        node.position.z = Float(lift / 2)
        spinNode.addChildNode(node)
        spinNode.addChildNode(ring(inner: (19 - 2.5) * scale, outer: 19 * scale, z: Float(lift) + 0.1, color: Theme.wheelHubMark))
        let dot = SCNCylinder(radius: 6 * scale, height: 0.1)
        dot.radialSegmentCount = 24
        dot.materials = [Self.material(Theme.wheelHubMark, lit: false)]
        let dotNode = SCNNode(geometry: dot)
        dotNode.eulerAngles.x = .pi / 2
        dotNode.position.z = Float(lift) + 0.2
        spinNode.addChildNode(dotNode)
    }

    /// 盤を裏の中心 1 点で支える支柱。盤と一緒には回さず、傾けもしない。
    private func addPost(thickness: Double, scale: Double) {
        let length = Double(Theme.Wheel3D.postLength) * scale
        let post = SCNCylinder(radius: Double(Theme.Wheel3D.postRadius) * scale, height: length)
        post.radialSegmentCount = 32
        post.materials = [Self.material(Theme.wheelHub, lit: true)]
        let node = SCNNode(geometry: post)
        node.eulerAngles.x = .pi / 2
        node.position.z = Float(-thickness - length / 2)
        postNode.addChildNode(node)
    }

    /// 盤の平面に置く薄い輪。
    private func ring(inner: Double, outer: Double, z: Float, color: Color) -> SCNNode {
        let tube = SCNTube(innerRadius: inner, outerRadius: outer, height: 0.1)
        tube.radialSegmentCount = 96
        tube.materials = [Self.material(color, lit: false)]
        let node = SCNNode(geometry: tube)
        node.eulerAngles.x = .pi / 2
        node.position.z = z
        return node
    }

    /// `lit` が false なら照明に依らず塗りの色のまま出す（盤面の色がライティングでずれないように）。
    private static func material(_ color: Color, lit: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(color)
        material.lightingModel = lit ? .lambert : .constant
        return material
    }
}

/// 盤面のラベルを焼いた画像。盤と同じ大きさの正方形で、2D の `RouletteWheelView` と同じ位置・向きに置く
/// （画像の上が 12 時。y は下向きなので、2D の座標の取り方がそのまま使える）。
@MainActor
private enum WheelLabelImage {
    static func render(labels: [String], diameter: Double, radius: Double, displayScale: CGFloat) -> UIImage {
        let count = labels.count
        let side = CGFloat(diameter)
        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        format.opaque = false
        let font = roundedBold(size: WheelLabel.fontSize(count: count, diameter: diameter))
        let limit = WheelLabel.limit(count: count, diameter: diameter)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(Theme.onSlice)]
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { renderer in
            let context = renderer.cgContext
            let sliceAngle = count > 0 ? 360 / Double(count) : 360
            for (index, label) in labels.enumerated() {
                let text = NSAttributedString(string: WheelLabel.truncate(label, limit: limit), attributes: attributes)
                let size = text.size()
                context.saveGState()
                if count == 1 {
                    // 1 件だけのときは中央に置く
                    context.translateBy(x: side / 2, y: side / 2)
                } else {
                    let mid = (Double(index) + 0.5) * sliceAngle
                    let point = WheelGeometry.point(angle: mid, radius: radius * WheelLabel.radiusFraction)
                    context.translateBy(x: side / 2 + CGFloat(point.x), y: side / 2 - CGFloat(point.y))
                    context.rotate(by: CGFloat(WheelLabel.rotation(midAngle: mid) * .pi / 180))
                }
                text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
                context.restoreGState()
            }
        }
    }

    /// 2D の盤面と同じ書体（アプリ全体の `.fontDesign(.rounded)` と `.bold`）。
    private static func roundedBold(size: Double) -> UIFont {
        let font = UIFont.systemFont(ofSize: CGFloat(size), weight: .bold)
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: descriptor, size: CGFloat(size))
    }
}

#Preview("4 items") {
    Wheel3DView(items: ItemLabel.makeItems(["ラーメン", "カレー", "寿司", "焼肉"]), rotation: 0)
        .padding(40)
        .background(Theme.ink900)
}

#Preview("12 items") {
    Wheel3DView(items: ItemLabel.makeItems((1...12).map { "項目\($0)" }), rotation: 30)
        .padding(40)
        .background(Theme.ink900)
}
