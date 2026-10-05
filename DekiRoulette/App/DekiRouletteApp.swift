import SwiftUI

@main
struct DekiRouletteApp: App {
    /// 画面収録・ミラーリングの状態。両画面の `ItemListView` が印を伏せる判断に使う。
    @State private var screenCapture = ScreenCaptureMonitor(source: UIScreenCaptureSource())

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.rounded)
                .environment(screenCapture)
                // 初期化の時点ではシーンが未接続で読めないので、表示されたら読み直す。
                // 起動前から収録中だと変化の通知が来ないため
                .onAppear { screenCapture.refresh() }
        }
    }
}
