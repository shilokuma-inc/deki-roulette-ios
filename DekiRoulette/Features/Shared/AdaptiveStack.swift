import SwiftUI

/// 横幅に余裕があるときは横並び、なければ縦積み。Web 版の `lg:flex-row` に対応する。
struct AdaptiveStack<Content: View>: View {
    let horizontal: Bool
    /// 横並びのときの上下の揃え方。縦積みでは使わない。
    var alignment: VerticalAlignment = .top
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if horizontal {
            HStack(alignment: alignment, spacing: spacing) { content() }
        } else {
            VStack(spacing: spacing) { content() }
        }
    }
}
