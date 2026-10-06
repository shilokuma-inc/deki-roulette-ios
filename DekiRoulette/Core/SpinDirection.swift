import Foundation

/// 盤面を回す向き。画面上の時計回りが正（`rotation` が増える向き）で、反時計回りでは累積角が減る。
enum SpinDirection: Equatable {
    case clockwise
    case counterclockwise
}
