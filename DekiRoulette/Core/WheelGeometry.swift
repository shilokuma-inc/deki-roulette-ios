import Foundation

/// 3D の盤面の形の計算。3D 空間は手前から見て x が右・y が上・z が手前で、盤は xy 平面に置いて手前（+z）へ向ける。
/// 角度は 2D と同じく 12 時を 0 度として、手前から見て時計回りに数える。
enum WheelGeometry {
    /// 盤面の角度 `angle`（度）・中心からの距離 `radius` の点を、盤の平面（xy）上の座標に写す。
    static func point(angle: Double, radius: Double) -> SIMD2<Double> {
        let rad = angle * .pi / 180
        return SIMD2(radius * sin(rad), radius * cos(rad))
    }

    /// `start` 度から `end` 度までの外周を等分した点（両端を含む）。1 周を `segmentsPerTurn` 等分する細かさで、
    /// 細いスライスでも最低 1 区間（2 点）にする。
    static func arc(start: Double, end: Double, radius: Double, segmentsPerTurn: Int = 96) -> [SIMD2<Double>] {
        let span = end - start
        let segments = max(1, Int((abs(span) / 360 * Double(segmentsPerTurn)).rounded(.up)))
        return (0...segments).map { step in
            point(angle: start + span * Double(step) / Double(segments), radius: radius)
        }
    }

    /// 盤の累積の回転角（度、時計回りが正。`RouletteModel.rotation`）を、z 軸まわりの回転（ラジアン）に写す。
    /// z 軸まわりは手前から見て反時計回りが正なので、符号を返す。
    static func spinAngle(rotation: Double) -> Double {
        -rotation * .pi / 180
    }

    /// 縦の画角 `fieldOfView`（度）の透視カメラで、盤の平面に置いた直径 `diameter` の円が縦にちょうど収まる距離。
    static func cameraDistance(diameter: Double, fieldOfView: Double) -> Double {
        let half = max(fieldOfView, 1) / 2 * .pi / 180
        return diameter / 2 / tan(half)
    }
}
