import SwiftUI
import UIKit

/// "oddech": four seconds in, six seconds out, for three minutes. The star grows with each breath
/// in and shrinks with each breath out, with a soft tap at every change. A tap on the star stops it
/// at any moment; leaving the screen or the app stops it too. The screen stays on meanwhile.
struct BreathingCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let inhaleSeconds = 4
    private static let exhaleSeconds = 6
    /// 18 breaths of 10 seconds: three minutes.
    private static let breaths = 18

    @State private var isRunning = false
    @State private var step = BreathingStep.rest
    /// Which breath it is: 1 … `breaths`.
    @State private var breath = 0
    /// Counts every change of step, for the haptics.
    @State private var changes = 0
    @State private var hasFinished = false

    var body: some View {
        Card {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("oddech").sectionTitle()
                    Text(polish: "wdech przez 4 sekundy, wydech przez 6, przez trzy minuty. Dotknij gwiazdki, żeby zacząć, i jeszcze raz, kiedy zechcesz skończyć")
                        .bodyText()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: toggle) {
                    star
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRunning ? "zatrzymaj oddech" : "zacznij oddech")
                VStack(spacing: 4) {
                    Text(stepText)
                        .displayFont(20, italic: true, relativeTo: .title3)
                        .foregroundStyle(Palette.accent)
                        .contentTransition(.opacity)
                        // A quick fade of its own: the star's steps last four and six seconds.
                        .animation(.easeInOut(duration: 0.4), value: step)
                    if isRunning {
                        Text(remainingText)
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                }
                .multilineTextAlignment(.center)
                Text(polish: "jeśli zakręci Ci się w głowie, po prostu przerwij i wróć do zwykłego oddechu")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: changes)
        .task(id: isRunning) {
            await breathe()
        }
        .onChange(of: isRunning) { _, running in
            // The screen doesn't dim and lock in the middle of a breath.
            UIApplication.shared.isIdleTimerDisabled = running
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                stop()
            }
        }
        .onDisappear {
            stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// Small at rest and after a breath out, full after a breath in. With Reduce Motion it keeps its
    /// size and only brightens and fades.
    private var star: some View {
        let isFull = step == .inhale
        return OrganicStar()
            .fill(Palette.accent)
            .frame(width: 150, height: 150)
            .scaleEffect(reduceMotion ? 0.8 : (isFull ? 1 : 0.5))
            .opacity(isFull ? 1 : 0.65)
            .shadow(color: Palette.accent.opacity(isFull ? 0.45 : 0.15), radius: isFull ? 28 : 10)
            .frame(width: 190, height: 190)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }

    private var stepText: String {
        guard isRunning else {
            return hasFinished ? "pięknie – to były trzy minuty tylko dla Ciebie" : "kiedy będziesz gotowa"
        }
        switch step {
        case .inhale: return "wdech"
        case .exhale: return "wydech"
        case .rest: return "zaczynamy"
        }
    }

    private var remainingText: String {
        let current = Swift.max(breath, 1)
        guard current < Self.breaths else { return "ostatni oddech" }
        let seconds = (Self.breaths - current + 1) * (Self.inhaleSeconds + Self.exhaleSeconds)
        return "jeszcze ok. \((seconds + 59) / 60) min"
    }

    private func toggle() {
        if isRunning {
            stop()
        } else {
            hasFinished = false
            breath = 0
            isRunning = true
        }
    }

    /// Ending `isRunning` cancels the task that leads the breaths.
    private func stop() {
        guard isRunning else { return }
        isRunning = false
        go(to: .rest, over: 1)
    }

    /// Leads the breaths to the end, unless she stops first (the task is then cancelled). Runs as
    /// the view's task each time `isRunning` changes; when it has just turned off, nothing to do.
    private func breathe() async {
        guard isRunning else { return }
        for number in 1...Self.breaths {
            breath = number
            go(to: .inhale, over: Self.inhaleSeconds)
            try? await Task.sleep(for: .seconds(Self.inhaleSeconds))
            if Task.isCancelled { return }
            go(to: .exhale, over: Self.exhaleSeconds)
            try? await Task.sleep(for: .seconds(Self.exhaleSeconds))
            if Task.isCancelled { return }
        }
        hasFinished = true
        isRunning = false
        go(to: .rest, over: 2)
    }

    /// The star moves for the whole length of the step; VoiceOver says the step aloud.
    private func go(to newStep: BreathingStep, over seconds: Int) {
        withAnimation(.easeInOut(duration: Double(seconds))) {
            step = newStep
        }
        changes &+= 1
        if UIAccessibility.isVoiceOverRunning, let spoken = newStep.spoken {
            UIAccessibility.post(notification: .announcement, argument: spoken)
        }
    }
}

/// Where the breathing exercise is.
private nonisolated enum BreathingStep {
    case rest
    case inhale
    case exhale

    /// What VoiceOver says when the step begins.
    var spoken: String? {
        switch self {
        case .rest: nil
        case .inhale: "wdech"
        case .exhale: "wydech"
        }
    }
}
