import XCTest

@MainActor
final class LocologUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testOnboardingLocalStartButton() throws {
        let startButton = app.buttons["startLocallyButton"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()
        // 메모 목록 화면으로 전환 확인
        XCTAssertTrue(app.navigationBars.element.exists)
    }
}
