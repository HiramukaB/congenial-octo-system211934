import XCTest

/// Saves a screenshot as a test attachment and, in CI, as a PNG in ~/screenshots
/// (uploaded as the "screenshots" artifact).
@MainActor
func saveScreenshot(named name: String, in testCase: XCTestCase) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    testCase.add(attachment)

    guard let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
    let folder = URL(fileURLWithPath: hostHome).appendingPathComponent("screenshots", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
}

/// In CI, adds a line to "timings.txt" next to the screenshots: how long each screen took, so a
/// screen that got slower shows up in the artifact.
func saveTiming(_ line: String) {
    guard let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
    let folder = URL(fileURLWithPath: hostHome).appendingPathComponent("screenshots", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("timings.txt")
    let data = Data((line + "\n").utf8)
    if let handle = try? FileHandle(forWritingTo: file) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: file)
    }
}

/// Seconds since `start`, for `saveTiming`.
func seconds(since start: Date) -> String {
    String(format: "%.1f s", Date().timeIntervalSince(start))
}

/// Launches every tab with fictional demo data and saves a screenshot of it, then the food tab
/// while a meal is typed and the targets sheet.
final class ScreenshotTests: XCTestCase {
    private let tabs = ["today", "calendar", "food", "movement", "me"]

    @MainActor
    func testCaptureEveryTab() throws {
        for (index, tab) in tabs.enumerated() {
            let app = XCUIApplication()
            // A still background lets the app become idle, so UI automation stays fast and reliable.
            app.launchArguments = ["-demoData", "-stillBackground", "-startTab", tab]
            let start = Date()
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start")
            let launched = seconds(since: start)
            // The tab bar comes with the first frame. On a busy machine the screen can still be black
            // right after the launch, so the screenshot waits for it.
            let shown = Date()
            XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 30), "the \(tab) tab never appeared")
            saveTiming("\(tab): launch \(launched), first frame after \(seconds(since: shown))")
            // Let the layout settle.
            Thread.sleep(forTimeInterval: 2)
            XCTAssertEqual(app.state, .runningForeground, "the app quit on the \(tab) tab")
            saveScreenshot(named: String(format: "%02d-%@", index + 1, tab), in: self)
            if tab == "food" || tab == "today" {
                // The lower half of the longer screens.
                let swipe = Date()
                app.swipeUp()
                saveTiming("\(tab): swipe \(seconds(since: swipe))")
                Thread.sleep(forTimeInterval: 1)
                saveScreenshot(named: String(format: "%02d-%@-2", index + 1, tab), in: self)
            }
            app.terminate()
        }
    }

    /// Best effort, with fictional demo data: the food tab while a meal is being typed, and the
    /// "Twoje cele dzienne" sheet. A step whose element doesn't show up is skipped, and so is its
    /// screenshot. It runs after `testCaptureEveryTab` (tests run in name order), so the simulator
    /// is already warm when it launches the app.
    @MainActor
    func testFoodTypingAndTargets() {
        captureTypingAMeal()
        captureTargetsSheet()
    }

    @MainActor
    private func captureTypingAMeal() {
        let app = launchFoodTab()
        defer { app.terminate() }
        let star = button(labelled: "dopisz posiłek", in: app)
        guard star.waitForExistence(timeout: 10), star.isHittable else { return }
        star.tap()
        let field = app.descendants(matching: .any).matching(identifier: "meal-field").firstMatch
        guard field.waitForExistence(timeout: 5) else { return }
        // The app gives the new field the keyboard by itself. Without a visible keyboard (e.g. a
        // simulator with a hardware keyboard) a tap on the field makes sure it has the focus.
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) {
            guard field.isHittable else { return }
            field.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        // A fresh simulator covers the keyboard with its "slide to type" tip the first time.
        let keyboardTip = app.buttons["Continue"]
        if keyboardTip.waitForExistence(timeout: 2), keyboardTip.isHittable {
            keyboardTip.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        // Every keystroke counts the whole text again for the live preview.
        let meal = "kurczak ryż brokuł, kawa z mlekiem"
        let typing = Date()
        app.typeText(meal)
        saveTiming("typing \(meal.count) characters: \(seconds(since: typing))")
        Thread.sleep(forTimeInterval: 1.5)
        saveScreenshot(named: "06-food-typing", in: self)
    }

    @MainActor
    private func captureTargetsSheet() {
        let app = launchFoodTab()
        defer { app.terminate() }
        let targets = button(labelled: "Twoje cele dzienne", in: app)
        guard targets.waitForExistence(timeout: 10), targets.isHittable else { return }
        targets.tap()
        _ = app.navigationBars["Twoje cele dzienne"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 1)
        saveScreenshot(named: "07-food-targets", in: self)
    }

    @MainActor
    private func launchFoodTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-stillBackground", "-startTab", "food"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 15)
        _ = app.buttons.firstMatch.waitForExistence(timeout: 30)
        // Let the layout settle.
        Thread.sleep(forTimeInterval: 2)
        return app
    }

    /// The first button with this VoiceOver label, so a second match can never make a tap fail.
    @MainActor
    private func button(labelled label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}

/// The path her phone really takes: real storage (no demo data), a change, leaving the app,
/// a cold start that reads the saved file back.
final class StorageTests: XCTestCase {
    @MainActor
    func testAMarkedDaySurvivesARestart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-stillBackground", "-startTab", "calendar"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start")

        let day = app.buttons["day-\(Self.todayISO())"]
        XCTAssertTrue(day.waitForExistence(timeout: 15), "today's calendar cell is missing")
        // Works on a fresh simulator and on one where an earlier run left the day marked.
        let wasMarked = day.label.contains(Self.markedLabel)
        day.tap()
        let changed = waitUntil(day, isMarked: !wasMarked)
        if !changed {
            saveScreenshot(named: "storage-after-tap", in: self)
        }
        XCTAssertTrue(changed, "tapping today did not change it")

        XCUIDevice.shared.press(.home)            // leaving the app saves right away
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()

        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start with saved data")
        let dayAfterRestart = app.buttons["day-\(Self.todayISO())"]
        XCTAssertTrue(dayAfterRestart.waitForExistence(timeout: 15), "today's calendar cell is missing after the restart")
        let kept = waitUntil(dayAfterRestart, isMarked: !wasMarked)
        if !kept {
            saveScreenshot(named: "storage-after-restart", in: self)
        }
        XCTAssertTrue(kept, "the change was not saved")
        app.terminate()
    }

    private static let markedLabel = "okres zaznaczony"

    /// Today in the simulator's time zone, the same way the app's calendar names its cells.
    private static func todayISO() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    @MainActor
    private func waitUntil(_ element: XCUIElement, isMarked: Bool, timeout: TimeInterval = 20) -> Bool {
        let format = isMarked ? "label CONTAINS %@" : "NOT (label CONTAINS %@)"
        let predicate = NSPredicate(format: format, Self.markedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
