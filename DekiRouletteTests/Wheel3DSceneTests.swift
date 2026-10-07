import Metal
import SceneKit
import SwiftUI
import Testing
@testable import DekiRoulette

/// 3D の盤面を画面外で描き、スライスの並び・回る向き・塗りの色を画素で確かめる。
@MainActor
struct Wheel3DSceneTests {
    private let size: CGFloat = 320

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
        let image = renderer.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .none)
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
        let scale = Double(pixels.width) / Double(size)
        let radius = (Double(size) / 2 - 16 * Double(size) / WheelLabel.referenceDiameter) * fraction
        let point = WheelGeometry.point(angle: angle, radius: radius)
        return CGPoint(x: (Double(size) / 2 + point.x) * scale, y: (Double(size) / 2 - point.y) * scale)
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
        let scene = Wheel3DScene()
        scene.update(count: count, diameter: size)
        scene.spin(to: rotation)
        return scene
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
        scene.update(count: 3, diameter: size)
        let pixels = try render(scene)
        let color = pixels.color(at: location(angle: 180, fraction: 0.6, pixels: pixels))
        #expect(isClose(color, srgb(Theme.sliceColor(at: 1, count: 3))), "\(color)")
    }
}
