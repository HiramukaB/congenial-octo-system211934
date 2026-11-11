import SwiftUI
import UIKit
import Combine
import LocalAuthentication
import AboutHerCore

extension View {
    /// Face ID before her data shows (when she turned the lock on) and a cover in the app
    /// switcher. RootView puts it around everything it shows.
    func appLock() -> some View {
        modifier(AppLock())
    }
}

/// With the lock on, a calm cover hides everything whenever the app isn't active – so the app
/// switcher never shows her data – and Face ID (or the phone's passcode) opens it again at launch
/// and after the app has been in the background. Never in the demo, and the lock is off until
/// she turns it on in "ustawienia".
struct AppLock: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            AppLockLayer()
        }
    }
}

/// Watches the lock setting and the scene, and covers her screen while it's locked. The cover is
/// drawn here too, so even the very first frame at launch never shows her data.
private struct AppLockLayer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    private let session = AppLockSession.shared

    var body: some View {
        let isEnabled = AppLockSession.isAvailable && store.data.settings.isLockEnabled
        let isCovered = isEnabled && (!session.isUnlocked || scenePhase != .active)
        Color.clear
            .overlay {
                if isCovered {
                    LockCoverView(session: session)
                }
            }
            .allowsHitTesting(isCovered)
            // Also when her file is read only after launch and the lock turns out to be on.
            .onChange(of: isEnabled, initial: true) { _, enabled in
                session.update(isEnabled: enabled, isActive: scenePhase == .active)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    session.didEnterBackground()
                }
                session.update(isEnabled: isEnabled, isActive: phase == .active)
            }
            // Right away, before iOS takes the picture for the app switcher.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                session.willResignActive()
            }
    }
}

/// The lock while the app runs: whether she has confirmed it's her, and the cover's own window.
///
/// The cover lives in a window of its own above everything, because sheets and alerts are shown
/// above anything drawn inside the app's window.
@Observable
final class AppLockSession {
    static let shared = AppLockSession()
    /// Never in the demo, so screenshots and UI tests never wait for Face ID.
    static let isAvailable = !LaunchArguments.usesDemoData

    /// She has confirmed it's her since the app last went to the background.
    private(set) var isUnlocked = false
    /// Face ID was cancelled or didn't recognise her: the next try waits for her tap on the star,
    /// so the question never comes back in a loop.
    private(set) var waitsForTap = false

    @ObservationIgnored private var isEnabled = false
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var isAuthenticating = false
    /// Grows each time the app goes to the background, so an answer that comes after that is ignored.
    @ObservationIgnored private var lockRound = 0
    @ObservationIgnored private var coverWindow: UIWindow?

    private init() {}

    enum TurnOnResult {
        case on, noPasscode, notConfirmed
    }

    /// Called whenever the lock setting or the scene changes. Asks for Face ID once the app is
    /// active and still locked.
    func update(isEnabled: Bool, isActive: Bool) {
        self.isEnabled = isEnabled
        self.isActive = isActive
        if !isEnabled {
            waitsForTap = false
        }
        updateCover()
        if isEnabled && isActive && !isUnlocked && !isAuthenticating && !waitsForTap {
            unlock()
        }
    }

    func willResignActive() {
        isActive = false
        updateCover()
    }

    /// Locks again: coming back needs Face ID.
    func didEnterBackground() {
        lockRound += 1
        isAuthenticating = false
        isUnlocked = false
        waitsForTap = false
        isActive = false
        updateCover()
    }

    /// Asks for Face ID, or the passcode when Face ID can't be used.
    func unlock() {
        guard isEnabled, isActive, !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        waitsForTap = false
        let thisRound = lockRound
        Task {
            let outcome = await LockAuthenticator.confirm(reason: "żeby pokazać Twoje dane")
            guard thisRound == lockRound else { return }
            isAuthenticating = false
            switch outcome {
            // A phone without a passcode can't be locked; she is never shut out of her own data.
            case .confirmed, .noPasscode:
                isUnlocked = true
            case .notConfirmed:
                waitsForTap = true
            }
            updateCover()
        }
    }

    /// Turns the lock on in "ustawienia": she confirms it's her once, so it's clear it works.
    /// Without a passcode on the phone it stays off.
    func turnOn(_ store: AppStore) async -> TurnOnResult {
        guard LockAuthenticator.canConfirm() else { return .noPasscode }
        isAuthenticating = true
        let outcome = await LockAuthenticator.confirm(reason: "żeby włączyć blokadę")
        isAuthenticating = false
        switch outcome {
        case .confirmed:
            // She has just shown it's her: the app stays open.
            isUnlocked = true
            return store.setLockEnabled(true) ? .on : .notConfirmed
        case .noPasscode:
            return .noPasscode
        case .notConfirmed:
            return .notConfirmed
        }
    }

    private var isCovered: Bool {
        isEnabled && (!isUnlocked || !isActive)
    }

    private func updateCover() {
        guard isCovered else {
            coverWindow?.isHidden = true
            coverWindow = nil
            return
        }
        guard coverWindow == nil, let scene = Self.windowScene else { return }
        // The keyboard sits above every window: put it away, so nothing she typed shows over the
        // cover. Her fields save themselves when they close.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        let host = UIHostingController(rootView: LockCoverView(session: self))
        host.view.backgroundColor = UIColor(Palette.background)
        window.rootViewController = host
        window.isHidden = false
        coverWindow = window
    }

    private static var windowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

/// Face ID with the passcode as the fallback.
private enum LockAuthenticator {
    enum Outcome {
        case confirmed, notConfirmed, noPasscode
    }

    /// False when the phone has no passcode, so there is nothing to lock with.
    static func canConfirm() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static func confirm(reason: String) async -> Outcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return error?.code == LAError.Code.passcodeNotSet.rawValue ? .noPasscode : .notConfirmed
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                ? .confirmed : .notConfirmed
        } catch {
            return .notConfirmed
        }
    }
}

/// The calm cover: the night colour, the app's star and its name in the middle. After a cancelled
/// Face ID, one large "odblokuj" near her thumb to try again. It reads nothing from the store: it
/// is also drawn in a window of its own, outside the app's views.
private struct LockCoverView: View {
    let session: AppLockSession

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x2A241C), Palette.background],
                           center: .center, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
            VStack(spacing: Spacing.cardGap) {
                OrganicStar()
                    .fill(Palette.accent)
                    .frame(width: 44, height: 44)
                    .shadow(color: Palette.accent.opacity(0.35), radius: 18)
                    .accessibilityHidden(true)
                Text("about her")
                    .displayFont(26, weight: .medium, relativeTo: .title2)
                    .foregroundStyle(Palette.text)
            }
            .padding(Spacing.section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if session.waitsForTap {
                StarActionButton("odblokuj") {
                    session.unlock()
                }
                .accessibilityHint(Text("poproszę o Face ID albo kod telefonu"))
                // The same width as the large buttons everywhere else in the app.
                .padding(.horizontal, Spacing.card)
                .padding(.bottom, Spacing.section)
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: session.waitsForTap)
        .preferredColorScheme(.dark)
    }
}
