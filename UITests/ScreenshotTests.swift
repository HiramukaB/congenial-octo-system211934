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

/// Launches every tab with fictional demo data and saves a screenshot of it.
final class ScreenshotTests: XCTestCase {
    private let tabs = ["today", "calendar", "food", "movement", "me"]

    @MainActor
    func testCaptureEveryTab() throws {
        for (index, tab) in tabs.enumerated() {
            let app = XCUIApplication()
            // A still background lets the app become idle, so UI automation stays fast and reliable.
            app.launchArguments = ["-demoData", "-stillBackground", "-startTab", tab]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start")
            // Let the layout settle.
            Thread.sleep(forTimeInterval: 2)
            XCTAssertEqual(app.state, .runningForeground, "the app quit on the \(tab) tab")
            saveScreenshot(named: String(format: "%02d-%@", index + 1, tab), in: self)
            app.terminate()
        }
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
