import XCTest

final class LocologUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testOnboardingLocalStartButton() throws {
        let startButton = app.buttons["로컬로 시작하기"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()
        // 메모 목록 화면으로 전환 확인
        XCTAssertTrue(app.navigationBars.element.exists)
    }
}
