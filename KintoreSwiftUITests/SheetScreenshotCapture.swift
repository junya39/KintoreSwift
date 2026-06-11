import XCTest

/// 開発確認用: Homeの各シートを開いてスクリーンショットを /tmp に保存する
final class SheetScreenshotCapture: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureSheetScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["許可"].firstMatch
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }

        XCTAssertTrue(app.staticTexts["きょうもきたえよう！"].waitForExistence(timeout: 5))
        app.swipeUp()

        captureSheet(app: app, openButton: "カレンダー", saveAs: "sheet_calendar")
        captureSheet(app: app, openButton: "種目追加", saveAs: "sheet_add_exercise")
        captureSheet(app: app, openButton: "相棒", saveAs: "sheet_buddy")
    }

    @MainActor
    private func captureSheet(app: XCUIApplication, openButton: String, saveAs name: String) {
        let button = app.buttons[openButton].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3), "\(openButton)ボタンが見つかること")
        button.tap()
        sleep(1)

        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))

        let close = app.buttons["閉じる"].firstMatch
        if close.waitForExistence(timeout: 2) {
            close.tap()
        }
        sleep(1)
    }
}
