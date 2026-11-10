import SwiftUI
import AboutHerCore

/// The welcome: her first configuration, one calm question per screen – her name, her cycle, a few
/// numbers about her and her daily targets, reminders, the Face ID lock – then the short guide.
///
/// Every answer is saved the moment she gives it, and "pomiń" waits on every question. If she
/// leaves midway, what she gave is kept and the welcome opens again where she stopped (the step is
/// remembered on the phone, never in the demo). On data she already has – the first launch after
/// the update that brings the welcome – each step shows what is there, so she only confirms it.
///
/// RootView shows it as a full-screen cover while `store.needsOnboarding` is true and takes it
/// away when `store.completeOnboarding()` is called – the last step's "chodźmy". It never calls
/// `dismiss()` itself.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: WelcomeStep
    /// The last move went forward: the next step slides in from the right, otherwise from the left.
    @State private var isMovingForward = true
    @State private var memory = WelcomeMemory()
    /// Her data held something before the welcome began – read once, so her first answers don't
    /// change how the greeting reads when she goes back to it.
    @State private var isReturning: Bool? = nil

    /// Where the welcome resumes after she leaves it midway.
    private static let resumeKey = "welcomeStep"

    init() {
        let saved = LaunchArguments.usesDemoData ? nil : UserDefaults.standard.string(forKey: Self.resumeKey)
        _step = State(initialValue: saved.flatMap { WelcomeStep(rawValue: $0) } ?? .hello)
    }

    var body: some View {
        ZStack {
            page(for: step)
                .id(step)
                .transition(stepTransition)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ambientBackground()
        .onAppear {
            if isReturning == nil {
                isReturning = store.hasHistoryBeforeWelcome
            }
        }
    }

    @ViewBuilder
    private func page(for step: WelcomeStep) -> some View {
        switch step {
        case .hello:
            WelcomeHelloPage(isReturning: isReturning ?? store.hasHistoryBeforeWelcome) {
                go(to: .name)
            }
        case .name:
            WelcomeNameStep(onBack: goBack, onNext: goForward)
        case .cycle:
            WelcomeCycleStep(memory: $memory, onBack: goBack, onNext: goForward)
        case .numbers:
            WelcomeNumbersStep(memory: $memory, onBack: goBack, onNext: goForward)
        case .targets:
            WelcomeTargetsStep(memory: $memory, onBack: goBack, onNext: goForward)
        case .reminders:
            WelcomeRemindersStep(onBack: goBack, onNext: goForward)
        case .lock:
            WelcomeLockStep(onBack: goBack, onNext: goForward)
        case .tutorial:
            TutorialView(onFinish: { go(to: .done) }, onBack: { go(to: .lock) })
        case .done:
            WelcomeDonePage(name: store.preferredName, onBack: goBack, onFinish: finish)
        }
    }

    /// Calm: the new step fades in and drifts a little from the side she is moving to.
    private var stepTransition: AnyTransition {
        let shift: CGFloat = reduceMotion ? 0 : (isMovingForward ? 28 : -28)
        return .asymmetric(insertion: .opacity.combined(with: .offset(x: shift, y: 0)),
                           removal: .opacity)
    }

    // MARK: - Moving

    private func goForward() {
        if let next = step.next {
            go(to: next)
        }
    }

    private func goBack() {
        if let previous = step.previous {
            go(to: previous)
        }
    }

    private func go(to target: WelcomeStep) {
        guard target != step else { return }
        isMovingForward = target.index > step.index
        withAnimation(reduceMotion ? Animation.easeInOut(duration: 0.2) : Animation.smooth(duration: 0.35)) {
            step = target
        }
        if !LaunchArguments.usesDemoData {
            UserDefaults.standard.set(target.rawValue, forKey: Self.resumeKey)
        }
    }

    /// "chodźmy": the welcome is done for good, and RootView takes it away. If her data can't be
    /// saved right now, the store says why and the last step stays.
    private func finish() {
        guard store.completeOnboarding() else { return }
        if !LaunchArguments.usesDemoData {
            UserDefaults.standard.removeObject(forKey: Self.resumeKey)
        }
    }
}

// MARK: - The greeting and the end

/// The first screen: who the app is for her, in two short sentences.
private struct WelcomeHelloPage: View {
    /// Her data already holds what she logged before the welcome existed.
    let isReturning: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    WelcomeStars()
                        .padding(.bottom, Spacing.group)
                    Text(polish: isReturning ? "dobrze, że jesteś" : "miło Cię poznać")
                        .displayFont(34, weight: .medium, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(polish: isReturning
                         ? "przejdźmy razem przez kilka ustawień. Pokażę, co już wiem, a Ty tylko sprawdzisz"
                         : "jestem tu, żeby było Ci łatwiej: cykl, jedzenie, ruch i chwile dla siebie – w Twoim rytmie, bez presji")
                        .bodyText()
                        .padding(.top, Spacing.item)
                    Text(polish: isReturning
                         ? "to zajmie chwilę – każdy krok możesz pominąć"
                         : "kilka krótkich pytań – każde możesz pominąć")
                        .hintText()
                        .padding(.top, Spacing.cardGap)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.section * 3)
                .padding(.bottom, Spacing.group)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            StarActionButton("zaczynamy", action: onStart)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.item)
                .padding(.bottom, Spacing.tight)
        }
    }
}

/// The last screen: everything is in place, and where to change it later.
private struct WelcomeDonePage: View {
    let name: String?
    let onBack: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            WelcomeBar(onBack: onBack) {
                EmptyView()
            }
            ScrollView {
                VStack(spacing: 0) {
                    WelcomeStars()
                        .padding(.bottom, Spacing.group)
                    Text(polish: name.map { "gotowe, \($0)" } ?? "wszystko gotowe")
                        .displayFont(34, weight: .medium, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(polish: "zmienisz to wszystko w każdej chwili – w kalendarzu, w jedzeniu i w ustawieniach")
                        .bodyText()
                        .padding(.top, Spacing.item)
                    Text(polish: "samouczek znajdziesz w „ja” → ustawienia")
                        .hintText()
                        .padding(.top, Spacing.cardGap)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.section * 2)
                .padding(.bottom, Spacing.group)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            StarActionButton("chodźmy", action: onFinish)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.item)
                .padding(.bottom, Spacing.tight)
        }
    }
}

/// The app's stars, a little larger: one bright, three small ones around it. They come in softly.
private struct WelcomeStars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            OrganicStar()
                .fill(Palette.accent)
                .frame(width: 42, height: 42)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.8))
                .frame(width: 15, height: 15)
                .offset(x: 36, y: -20)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.55))
                .frame(width: 11, height: 11)
                .offset(x: -34, y: 16)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.4))
                .frame(width: 8, height: 8)
                .offset(x: -18, y: -26)
        }
        .frame(width: 110, height: 72)
        .opacity(isShown ? 1 : 0)
        .scaleEffect(isShown || reduceMotion ? 1 : 0.85)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.smooth(duration: 0.6)) {
                isShown = true
            }
        }
    }
}
