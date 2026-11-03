import XCTest

/// Walks through the app with sample data and saves a screenshot of every screen.
/// CI sets SCREENSHOT_DIR (via TEST_RUNNER_SCREENSHOT_DIR) and publishes the PNGs.
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        // Polish formatting like on a Polish iPhone (the CI simulator is en_US)
        app.launchArguments = ["-demo", "-AppleLanguages", "(pl)", "-AppleLocale", "pl_PL"]
        app.launch()
    }

    func testTour() {
        snap("1-notatki")

        app.tabBars.buttons["Zadania"].tap()
        snap("2-zadania")

        app.tabBars.buttons["Praca"].tap()
        snap("3-praca")

        app.buttons["Dodaj wpis"].tap()
        snap("4-nowy-wpis")
        app.buttons["Anuluj"].tap()

        app.tabBars.buttons["Więcej"].tap()
        snap("5-wiecej")

        app.tabBars.buttons["Notatki"].tap()
        let draft = app.descendants(matching: .any).matching(identifier: "noteDraft").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.tap()
        draft.typeText("Notatka z testu #ci")
        app.buttons["noteSave"].tap()
        XCTAssertTrue(app.staticTexts["Notatka z testu #ci"].waitForExistence(timeout: 5))
        snap("6-nowa-notatka")
    }

    private func snap(_ name: String) {
        sleep(1) // let animations settle
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
        }
    }
}
