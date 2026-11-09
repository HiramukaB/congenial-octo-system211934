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
