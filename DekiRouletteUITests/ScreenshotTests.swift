import XCTest

/// App Store 用スクリーンショットの撮影。`scripts/capture-screenshots.sh` から
/// `DekiRouletteScreenshots` スキームで実行し、添付画像を xcresult から取り出す。
/// 添付名の先頭 2 桁が App Store Connect 上の並び順になる。
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureTabs() throws {
        // 直前に前面にいた別アプリへの「戻る」表示がステータスバーに写り込まないよう、
        // いったんホームに戻してから起動する
        XCUIDevice.shared.press(.home)
        settle()

        let app = XCUIApplication()
        app.launch()

        // タブは iPhone ではタブバーのボタン、iPad では上部の通常ボタン（identifier に
        // RootView の tabItem が使う SF Symbol 名が入る）として露出するので、両方に対応する
        let tabBar = app.tabBars.firstMatch
        let orderTabOnPad = app.buttons["list.number"].firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 10) { tabBar.exists || orderTabOnPad.exists },
            "タブが見つからない"
        )
        let orderTab = tabBar.exists ? tabBar.buttons.element(boundBy: 1) : orderTabOnPad
        XCTAssertTrue(orderTab.exists, "順番決めのタブが見つからない")

        // 1 枚目: ルーレット（起動直後のタブ）
        attach(screenshot: stableScreenshot(), name: "01-roulette")

        // 2 枚目: 順番決め
        XCTAssertTrue(
            waitUntil(timeout: 10) { orderTab.isHittable },
            "順番決めのタブを押せない"
        )
        orderTab.tap()
        XCTAssertTrue(
            waitUntil(timeout: 10) { orderTab.isSelected },
            "順番決めタブに切り替わらない"
        )
        attach(screenshot: stableScreenshot(), name: "02-order")
    }

    /// 画面遷移アニメーションが落ち着くまで待つ。
    private func settle() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    }

    /// 同じ絵が 2 回続けて撮れるまで待ってから撮る。起動直後やタブ切り替え直後は描画が追いつかず、
    /// 前の画面の一部が残ったフレームが撮れることがある（画面の小さい端末で出やすい）。
    /// 常に動くものがある画面では安定しないので、上限まで試したら最後の 1 枚を使う。
    @MainActor
    private func stableScreenshot() -> XCUIScreenshot {
        var previous = XCUIScreen.main.screenshot()
        for _ in 0..<20 {
            settle()
            let current = XCUIScreen.main.screenshot()
            if current.pngRepresentation == previous.pngRepresentation { return current }
            previous = current
        }
        XCTFail("画面が安定しないままスクリーンショットを撮りました")
        return previous
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return condition()
    }

    private func attach(screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
