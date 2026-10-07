import Metal
import SceneKit
import SwiftUI
import Testing
@testable import DekiRoulette

/// 3D の盤面を画面外で描き、スライスの並び・回る向き・塗りの色を画素で確かめる。
@MainActor
struct Wheel3DSceneTests {
    private let size: CGFloat = 320
    /// 描く範囲（盤面の枠より `overscan` だけ広い）。
    private var canvas: CGFloat { size * (1 + 2 * Theme.Wheel3D.overscan) }

    /// 場面を描いた画素（RGBA8、sRGB）。
    private struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func color(at point: CGPoint) -> SIMD3<Double> {
            let x = min(max(Int(point.x), 0), width - 1)
            let y = min(max(Int(point.y), 0), height - 1)
            let offset = (y * width + x) * 4
            return SIMD3(Double(bytes[offset]), Double(bytes[offset + 1]), Double(bytes[offset + 2])) / 255
        }
    }

    private func render(_ scene: Wheel3DScene) throws -> Pixels {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene.scene
        renderer.pointOfView = scene.cameraNode
        let image = renderer.snapshot(atTime: 0, with: CGSize(width: canvas, height: canvas), antialiasingMode: .none)
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        #expect(drawn)
        return Pixels(width: width, height: height, bytes: bytes)
    }

    /// 盤面の角度 `angle`（12 時が 0 度、時計回り）・半径の割合 `fraction` の画素の位置（画像は y が下向き）。
    private func location(angle: Double, fraction: Double, pixels: Pixels) -> CGPoint {
        let radius = (Double(size) / 2 - 16 * Double(size) / WheelLabel.referenceDiameter) * fraction
        let point = WheelGeometry.point(angle: angle, radius: radius)
        return location(x: point.x, y: point.y, pixels: pixels)
    }

    /// 盤の平面の座標（中心が原点、y が上）の画素の位置。
    private func location(x: Double, y: Double, pixels: Pixels) -> CGPoint {
        let scale = Double(pixels.width) / Double(canvas)
        return CGPoint(x: (Double(canvas) / 2 + x) * scale, y: (Double(canvas) / 2 - y) * scale)
    }

    private func srgb(_ color: Color) -> SIMD3<Double> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD3(Double(r), Double(g), Double(b))
    }

    private func isClose(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        let d = a - b
        return max(abs(d.x), abs(d.y), abs(d.z)) < 0.04
    }

    private func makeScene(count: Int, rotation: Double) -> Wheel3DScene {
        makeScene(labels: Array(repeating: "", count: count), rotation: rotation)
    }

    private func makeScene(labels: [String], rotation: Double) -> Wheel3DScene {
        let scene = Wheel3DScene()
        scene.update(labels: labels, diameter: size)
        scene.spin(to: rotation)
        return scene
    }

    /// `center` のまわり（一辺 `box` px）で、ラベルの文字色（`onSlice`）に近い画素の数。
    private func inkCount(around center: CGPoint, box: Int = 10, pixels: Pixels) -> Int {
        let ink = srgb(Theme.onSlice)
        var count = 0
        for dx in -box / 2..<box / 2 {
            for dy in -box / 2..<box / 2 {
                let color = pixels.color(at: CGPoint(x: center.x + CGFloat(dx), y: center.y + CGFloat(dy)))
                if isClose(color, ink) { count += 1 }
            }
        }
        return count
    }

    @Test func スライスは12時から時計回りに並び塗りの色のまま出る() throws {
        let pixels = try render(makeScene(count: 4, rotation: 0))
        for index in 0..<4 {
            let color = pixels.color(at: location(angle: 45 + 90 * Double(index), fraction: 0.6, pixels: pixels))
            #expect(isClose(color, srgb(Theme.sliceColor(at: index, count: 4))), "slice \(index): \(color)")
        }
    }

    /// 回転角だけ時計回りに回る（2D の `rotationEffect` と同じ向き）。
    @Test func 時計回りに回る() throws {
        let pixels = try render(makeScene(count: 4, rotation: 90))
        let color = pixels.color(at: location(angle: 135, fraction: 0.6, pixels: pixels))
        #expect(isClose(color, srgb(Theme.sliceColor(at: 0, count: 4))), "\(color)")
    }

    @Test func 項目1件は円1枚() throws {
        let pixels = try render(makeScene(count: 1, rotation: 0))
        for angle in [30.0, 200, 300] {
            let color = pixels.color(at: location(angle: angle, fraction: 0.6, pixels: pixels))
            #expect(isClose(color, srgb(Theme.sliceColor(at: 0, count: 1))), "\(angle): \(color)")
        }
    }

    @Test func 件数が変わると組み直す() throws {
        let scene = makeScene(count: 4, rotation: 0)
        scene.update(labels: ["", "", ""], diameter: size)
        let pixels = try render(scene)
        let color = pixels.color(at: location(angle: 180, fraction: 0.6, pixels: pixels))
        #expect(isClose(color, srgb(Theme.sliceColor(at: 1, count: 3))), "\(color)")
    }

    /// ラベルは自分のスライスの上に出る（上下・左右に反転しない）。
    @Test func ラベルは自分のスライスに出る() throws {
        let pixels = try render(makeScene(labels: ["", "■■■", "", ""], rotation: 0))
        let own = location(angle: 135, fraction: WheelLabel.radiusFraction, pixels: pixels)
        #expect(inkCount(around: own, pixels: pixels) > 30)
        for angle in [45.0, 225, 315] {
            let other = location(angle: angle, fraction: WheelLabel.radiusFraction, pixels: pixels)
            #expect(inkCount(around: other, pixels: pixels) == 0, "\(angle)")
        }
    }

    /// 文字は半径方向に左から右へ並び、右半分では中心側から、左半分では外周側から読み始める（2D と同じ向き）。
    /// 先頭にだけ印のあるラベルで、印が出る側を確かめる（左右に反転すると逆の側に出る）。
    @Test func ラベルの文字は2Dと同じ向きに並ぶ() throws {
        let label = "■\u{3000}\u{3000}\u{3000}"
        let pixels = try render(makeScene(labels: ["", label, "", label], rotation: 0))
        let inner = WheelLabel.radiusFraction - 0.13
        let outer = WheelLabel.radiusFraction + 0.13
        // 右半分（135 度）は中心側が先頭
        #expect(inkCount(around: location(angle: 135, fraction: inner, pixels: pixels), pixels: pixels) > 30)
        #expect(inkCount(around: location(angle: 135, fraction: outer, pixels: pixels), pixels: pixels) == 0)
        // 左半分（315 度）は逆さまにしないよう返すので、外周側が先頭
        #expect(inkCount(around: location(angle: 315, fraction: outer, pixels: pixels), pixels: pixels) > 30)
        #expect(inkCount(around: location(angle: 315, fraction: inner, pixels: pixels), pixels: pixels) == 0)
    }

    @Test func ラベルは盤と一緒に回る() throws {
        let pixels = try render(makeScene(labels: ["", "■■■", "", ""], rotation: 180))
        let moved = location(angle: 315, fraction: WheelLabel.radiusFraction, pixels: pixels)
        #expect(inkCount(around: moved, pixels: pixels) > 30)
        let original = location(angle: 135, fraction: WheelLabel.radiusFraction, pixels: pixels)
        #expect(inkCount(around: original, pixels: pixels) == 0)
    }

    @Test func ラベルが変わると組み直す() throws {
        let scene = makeScene(labels: ["", "■■■", "", ""], rotation: 0)
        scene.update(labels: ["", "", "", ""], diameter: size)
        let pixels = try render(scene)
        let own = location(angle: 135, fraction: WheelLabel.radiusFraction, pixels: pixels)
        #expect(inkCount(around: own, pixels: pixels) == 0)
    }

    // MARK: 針と結果の帯

    @Test func 針は12時に塗りの色のまま出る() throws {
        let pixels = try render(makeScene(count: 4, rotation: 0))
        // 針の先（盤面の枠の上端から 20pt 下）より少し上の中央
        let color = pixels.color(at: location(x: 0, y: Double(size) / 2 - 8, pixels: pixels))
        #expect(isClose(color, srgb(Theme.flare)), "\(color)")
    }

    @Test func 針は盤と一緒に回らない() throws {
        let pixels = try render(makeScene(count: 4, rotation: 123))
        let color = pixels.color(at: location(x: 0, y: Double(size) / 2 - 8, pixels: pixels))
        #expect(isClose(color, srgb(Theme.flare)), "\(color)")
    }

    /// 帯の中央（針の先の下）の位置。
    private var bandCenterY: Double {
        let diameter = Double(size)
        let top = diameter / 2 - ResultBand.top(diameter: diameter, pointerBounce: Theme.pointerBounceOffset)
        // 帯の高さはおよそ文字の高さ + 上下の余白。中央より少し上を見る
        return top - ResultBand.fontSize(diameter: diameter) * 0.5
    }

    @Test func 結果の帯は針の下に出る() throws {
        let scene = makeScene(count: 4, rotation: 0)
        scene.show(result: Wheel3DResult(id: "a1", label: "\u{3000}", accent: Theme.sliceColor(at: 2, count: 4)), reduceMotion: true)
        let pixels = try render(scene)
        let color = pixels.color(at: location(x: 0, y: bandCenterY, pixels: pixels))
        #expect(isClose(color, srgb(Theme.resultBandFill)), "\(color)")
    }

    @Test func 結果が消えると帯も消える() throws {
        let scene = makeScene(count: 4, rotation: 0)
        scene.show(result: Wheel3DResult(id: "a1", label: "\u{3000}", accent: Theme.sliceColor(at: 2, count: 4)), reduceMotion: true)
        scene.show(result: nil, reduceMotion: true)
        let pixels = try render(scene)
        let color = pixels.color(at: location(x: 0, y: bandCenterY, pixels: pixels))
        #expect(!isClose(color, srgb(Theme.resultBandFill)), "\(color)")
    }
}
