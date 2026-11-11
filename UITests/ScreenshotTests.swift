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
/// while a meal is typed, the targets sheet, the screens "ja" opens, the welcome steps and the
/// short guide.
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
            if tab == "food" || tab == "today" || tab == "movement" {
                // The lower half of the longer screens. On "dziś" the arrows next to the date must
                // move up with the page: proof that a swipe really scrolls it.
                let marker = tab == "today" ? button(labelled: "poprzedni dzień", in: app) : nil
                let markerTop = marker.flatMap { top(of: $0, on: tab) }
                let swipe = Date()
                app.swipeUp()
                saveTiming("\(tab): swipe \(seconds(since: swipe))")
                Thread.sleep(forTimeInterval: 1)
                saveScreenshot(named: String(format: "%02d-%@-2", index + 1, tab), in: self)
                if let marker, let markerTop {
                    checkScrolled(marker, from: markerTop, on: tab)
                }
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
        // The sheet has no bar: its title is the serif header at the top.
        _ = app.staticTexts["Twoje cele dzienne"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 1)
        saveScreenshot(named: "07-food-targets", in: self)
    }

    /// Best effort, with fictional demo data: the screens "ja" opens – "chwila dla siebie",
    /// "wnętrze", "ustawienia" and "humor" – each with its lower half, then the short guide that
    /// "ustawienia" opens again. Every screen gets its own launch; an entry that doesn't show up is
    /// skipped, and so are its screenshots. It runs after the tests above (name order), on a warm
    /// simulator.
    @MainActor
    func testMeScreens() {
        captureMeScreen(opening: "chwila dla siebie", named: "08-me-moment")
        captureMeScreen(opening: "wnętrze", named: "09-me-inner")
        captureMeScreen(opening: "ustawienia", named: "10-me-settings")
        // The draw button at the top of "humor" must move up with the page when she swipes.
        captureMeScreen(opening: "humor", named: "12-humor", scrollMarker: "losuj coś na poprawę humoru")
        captureTutorial(named: "13-tutorial")
    }

    /// `scrollMarker`: the label of a button near the top of the screen. When given, the swipe up
    /// must move it up (or off the screen), or the test fails – the page has to really scroll.
    @MainActor
    private func captureMeScreen(opening title: String, named name: String, scrollMarker: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-stillBackground", "-startTab", "me"]
        let start = Date()
        app.launch()
        defer { app.terminate() }
        guard app.wait(for: .runningForeground, timeout: 15) else { return }
        let launched = seconds(since: start)
        let shown = Date()
        guard app.buttons.firstMatch.waitForExistence(timeout: 30) else { return }
        saveTiming("\(name): launch \(launched), first frame after \(seconds(since: shown))")
        // Let the layout settle.
        Thread.sleep(forTimeInterval: 2)
        guard let entry = findEntry(startingWith: title, in: app) else { return }
        let opening = Date()
        entry.tap()
        // The screen it opens has a bar with the way back to "ja".
        _ = app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5)
        saveTiming("\(name): open \(seconds(since: opening))")
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(app.state, .runningForeground, "the app quit on \(title)")
        saveScreenshot(named: name, in: self)
        let marker = scrollMarker.map { button(labelled: $0, in: app) }
        let markerTop = marker.flatMap { top(of: $0, on: name) }
        // The lower half of the screen.
        let swipe = Date()
        app.swipeUp()
        saveTiming("\(name): swipe \(seconds(since: swipe))")
        Thread.sleep(forTimeInterval: 1)
        saveScreenshot(named: "\(name)-2", in: self)
        if let marker, let markerTop {
            checkScrolled(marker, from: markerTop, on: name)
        }
    }

    /// Where `marker` starts before a swipe up; a failure (and nil) when it isn't on the screen.
    @MainActor
    private func top(of marker: XCUIElement, on screen: String) -> CGFloat? {
        guard marker.waitForExistence(timeout: 5) else {
            XCTFail("\(screen): the element near the top is missing, so the scrolling can't be checked")
            return nil
        }
        return marker.frame.minY
    }

    /// After a swipe up the page must have moved: `marker`, which was at `top`, is now at least
    /// 40 pt higher, or has left the screen with the page. Writes how far it went to timings.txt.
    @MainActor
    private func checkScrolled(_ marker: XCUIElement, from top: CGFloat, on screen: String) {
        guard marker.exists else {
            saveTiming("\(screen): scrolled the top element off the screen")
            return
        }
        let moved = top - marker.frame.minY
        let points = moved.isFinite ? String(format: "%.0f", Double(moved)) : "?"
        saveTiming("\(screen): scrolled \(points) pt")
        XCTAssertGreaterThan(moved, 40, "\(screen): a swipe up did not scroll the page (it moved \(points) pt)")
    }

    /// The short guide, as "ustawienia" opens it again from the row "samouczek".
    @MainActor
    private func captureTutorial(named name: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-stillBackground", "-startTab", "me"]
        let start = Date()
        app.launch()
        defer { app.terminate() }
        guard app.wait(for: .runningForeground, timeout: 15) else { return }
        let launched = seconds(since: start)
        let shown = Date()
        guard app.buttons.firstMatch.waitForExistence(timeout: 30) else { return }
        saveTiming("\(name): launch \(launched), first frame after \(seconds(since: shown))")
        // Let the layout settle.
        Thread.sleep(forTimeInterval: 2)
        guard let settings = findEntry(startingWith: "ustawienia", in: app) else { return }
        settings.tap()
        _ = app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 1)
        guard let row = findEntry(startingWith: "samouczek", in: app) else { return }
        let opening = Date()
        row.tap()
        // The guide covers the screen, with "dalej" at the bottom.
        guard button(labelled: "dalej", in: app).waitForExistence(timeout: 5) else { return }
        saveTiming("\(name): open \(seconds(since: opening))")
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(app.state, .runningForeground, "the app quit on the guide")
        saveScreenshot(named: name, in: self)
    }

    /// The welcome as her phone shows it after the update, on fictional demo data: the greeting
    /// and the first two questions (best effort), then the star action "dalej" through every step
    /// and every card of the guide to "chodźmy", which must close it. The welcome covers the whole
    /// app, so one that can't be finished would keep her out of it. It runs after the tests above
    /// (name order), on a warm simulator.
    @MainActor
    func testOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-showOnboarding", "-stillBackground"]
        let start = Date()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "the app did not start")
        let launched = seconds(since: start)
        let shown = Date()
        let begin = button(labelled: "zaczynamy", in: app)
        guard begin.waitForExistence(timeout: 30) else {
            XCTFail("the welcome did not show")
            return
        }
        saveTiming("11-onboarding: launch \(launched), first frame after \(seconds(since: shown))")
        // Let the layout settle.
        Thread.sleep(forTimeInterval: 2)
        saveScreenshot(named: "11-onboarding-1", in: self)

        // The greeting's "zaczynamy", then the first two questions (name, cycle).
        let next = button(labelled: "dalej", in: app)
        if begin.isHittable {
            begin.tap()
            if next.waitForExistence(timeout: 5) {
                Thread.sleep(forTimeInterval: 1.5)
                saveScreenshot(named: "11-onboarding-2", in: self)
                if next.isHittable {
                    next.tap()
                    Thread.sleep(forTimeInterval: 1.5)
                    saveScreenshot(named: "11-onboarding-3", in: self)
                }
            }
        }

        // "dalej" through the other questions and the five cards of the guide.
        let finish = button(labelled: "chodźmy", in: app)
        let stepping = Date()
        var taps = 0
        var tries = 0
        while !finish.exists && tries < 25 {
            tries += 1
            guard next.waitForExistence(timeout: 5) else { break }
            // A step still fading in may not take a tap yet; the next round tries again.
            if next.isHittable {
                next.tap()
                taps += 1
            }
            Thread.sleep(forTimeInterval: 0.8)
        }
        guard finish.waitForExistence(timeout: 5) else {
            saveScreenshot(named: "11-onboarding-stuck", in: self)
            XCTFail("the welcome never reached its end")
            return
        }
        saveTiming("11-onboarding: \(taps) taps to the end, \(seconds(since: stepping))")
        XCTAssertEqual(app.state, .runningForeground, "the app quit in the welcome")
        let closing = Date()
        finish.tap()
        XCTAssertTrue(waitUntilGone(finish, timeout: 10), "the welcome did not close")
        saveTiming("11-onboarding: close \(seconds(since: closing))")
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

    /// A place in "ja" or a row in "ustawienia", scrolled into reach when it is lower down;
    /// nil when it doesn't show up.
    @MainActor
    private func findEntry(startingWith title: String, in app: XCUIApplication) -> XCUIElement? {
        // An entry reads as its title, then the line about what is inside.
        let startsWithTitle = NSPredicate(format: "label BEGINSWITH %@", title)
        var element = app.buttons.matching(startsWithTitle).firstMatch
        if !element.waitForExistence(timeout: 10) {
            element = app.descendants(matching: .any).matching(startsWithTitle).firstMatch
            guard element.waitForExistence(timeout: 2) else { return nil }
        }
        if !element.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        return element.isHittable ? element : nil
    }

    /// Waits until the element is gone, e.g. a cover that closed; false when it is still there.
    @MainActor
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}

/// The path her phone really takes: real storage (no demo data), a change, leaving the app,
/// a cold start that reads the saved file back. "-skipOnboarding" keeps the welcome steps away
/// on the fresh simulator, without writing anything about them.
final class StorageTests: XCTestCase {
    @MainActor
    func testAMarkedDaySurvivesARestart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-stillBackground", "-startTab", "calendar"]
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
