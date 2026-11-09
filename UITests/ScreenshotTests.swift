import XCTest

/// Launches every tab with fictional demo data and saves a screenshot of it.
/// In CI the PNG files land in ~/screenshots and are uploaded as the "screenshots" artifact.
final class ScreenshotTests: XCTestCase {
    private let tabs = ["today", "calendar", "food", "movement", "me"]

    @MainActor
    func testCaptureEveryTab() throws {
        for (index, tab) in tabs.enumerated() {
            let app = XCUIApplication()
            app.launchArguments = ["-demoData", "-startTab", tab]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start")
            // Let the first frames of the background and the layout settle.
            Thread.sleep(forTimeInterval: 2)
            XCTAssertEqual(app.state, .runningForeground, "the app quit on the \(tab) tab")
            save(screenshot: XCUIScreen.main.screenshot(), named: String(format: "%02d-%@", index + 1, tab))
            app.terminate()
        }
    }

    @MainActor
    private func save(screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let folder = URL(fileURLWithPath: hostHome).appendingPathComponent("screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }
}

/// The path her phone really takes: real storage (no demo data), a change, leaving the app,
/// a cold start that reads the saved file back.
final class StorageTests: XCTestCase {
    @MainActor
    func testAMarkedDaySurvivesARestart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-startTab", "calendar"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start")

        let day = app.buttons["day-\(Self.todayISO())"]
        XCTAssertTrue(day.waitForExistence(timeout: 10), "today's calendar cell is missing")
        // Works on a fresh simulator and on one where an earlier run left the day marked.
        let wasMarked = day.label.contains(Self.markedLabel)
        day.tap()
        XCTAssertTrue(waitUntil(day, isMarked: !wasMarked), "tapping today did not change it")

        XCUIDevice.shared.press(.home)            // leaving the app saves right away
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()

        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start with saved data")
        let dayAfterRestart = app.buttons["day-\(Self.todayISO())"]
        XCTAssertTrue(dayAfterRestart.waitForExistence(timeout: 10), "today's calendar cell is missing after the restart")
        XCTAssertTrue(waitUntil(dayAfterRestart, isMarked: !wasMarked), "the change was not saved")
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
    private func waitUntil(_ element: XCUIElement, isMarked: Bool, timeout: TimeInterval = 5) -> Bool {
        let format = isMarked ? "label CONTAINS %@" : "NOT (label CONTAINS %@)"
        let predicate = NSPredicate(format: format, Self.markedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
