import XCTest

final class HomeScreenSmokeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Home画面が表示され、通知許可アラートが出た場合は許可して閉じる
    @MainActor
    func testHomeScreenShowsCharacterStage() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["許可"].firstMatch
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        } else {
            let allowEnglish = springboard.buttons["Allow"].firstMatch
            if allowEnglish.waitForExistence(timeout: 1) {
                allowEnglish.tap()
            }
        }

        XCTAssertTrue(
            app.staticTexts["クエスト"].waitForExistence(timeout: 5),
            "クエストバナーが表示されること"
        )
        XCTAssertTrue(
            app.staticTexts["トレーニングスタート！"].waitForExistence(timeout: 3),
            "スタートボタンが表示されること"
        )
    }
}
