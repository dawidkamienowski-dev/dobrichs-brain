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

        app.tabBars.buttons["Nawyki"].tap()
        snap("3-nawyki")
        app.buttons["+250 ml"].tap()
        app.buttons["Odhacz Siłownia"].tap()
        snap("4-nawyki-odhaczone")
        app.staticTexts["Bez papierosów"].tap()
        snap("5-nawyk-szczegoly")
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Praca"].tap()
        snap("6-praca")

        app.buttons["Dodaj wpis"].tap()
        snap("7-nowy-wpis")
        app.buttons["Anuluj"].tap()

        app.tabBars.buttons["Więcej"].tap()
        snap("8-wiecej")
        app.buttons["Podgląd widżetów"].tap()
        snap("9-widzety")
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Notatki"].tap()
        let draft = app.descendants(matching: .any).matching(identifier: "noteDraft").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.tap()
        draft.typeText("Notatka z testu #ci")
        app.buttons["noteSave"].tap()
        XCTAssertTrue(app.staticTexts["Notatka z testu #ci"].waitForExistence(timeout: 5))
        snap("10-nowa-notatka")

        // Live Activity of the running demo shift in the Dynamic Island
        XCUIDevice.shared.press(.home)
        sleep(2)
        snap("11-dynamic-island")
    }

    /// Same app in dark mode (as if chosen in Więcej → Motyw).
    func testDarkMode() {
        app.terminate()
        app.launchArguments += ["-appearance", "dark"]
        app.launch()
        app.tabBars.buttons["Nawyki"].tap()
        snap("12-ciemny-nawyki")
        app.tabBars.buttons["Praca"].tap()
        snap("13-ciemny-praca")
        app.tabBars.buttons["Więcej"].tap()
        snap("14-ciemny-wiecej")
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
