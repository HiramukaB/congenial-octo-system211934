import SwiftUI
import UIKit

/// "oddech": four seconds in, six seconds out, for three minutes. "zacznij" opens the exercise on
/// a calm screen of its own, so nothing else moves or asks for her attention meanwhile.
struct BreathingCard: View {
    @State private var isBreathing = false
    /// She breathed the whole three minutes on this visit.
    @State private var hasFinished = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("oddech", subtitle: "4 sekundy wdechu, 6 wydechu · trzy minuty")
                if hasFinished {
                    ConfirmationNote(text: "pięknie – to były trzy minuty tylko dla Ciebie")
                }
                StarActionButton(hasFinished ? "jeszcze raz" : "zacznij", size: .regular) {
                    isBreathing = true
                }
                .accessibilityLabel(Text(hasFinished ? "oddychaj jeszcze raz" : "zacznij oddech"))
            }
        }
        .fullScreenCover(isPresented: $isBreathing) {
            BreathingSession {
                withAnimation(.smooth) {
                    hasFinished = true
                }
            }
        }
    }
}

/// The exercise itself: the star grows with each breath in and shrinks with each breath out, with
/// a soft tap at every change, and the time left under it. "zakończ" stops it at any moment;
/// leaving the app stops it too. The screen stays on meanwhile. With Reduce Motion the star keeps
/// its size and only brightens and fades.
private struct BreathingSession: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Called when she has breathed all three minutes.
    let onComplete: () -> Void

    private static let inhaleSeconds = 4
    private static let exhaleSeconds = 6
    /// 18 breaths of 10 seconds: three minutes.
    private static let breaths = 18

    @State private var step = BreathingStep.rest
    /// Which breath it is: 1 … `breaths`; 0 before the first.
    @State private var breath = 0
    /// Counts every change of step, for the haptics.
    @State private var changes = 0
    @State private var isFinished = false

    var body: some View {
        VStack(spacing: Spacing.group) {
            Spacer(minLength: Spacing.section)
            star
            VStack(spacing: Spacing.tight) {
                Text(polish: stepText)
                    .displayFont(26, italic: true, relativeTo: .title2)
                    .foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    // A quick fade of its own: the star's steps last four and six seconds.
                    .animation(.easeInOut(duration: 0.4), value: stepText)
                // Always one line tall, so nothing moves when it appears.
                Text(verbatim: remainingText ?? " ")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.muted)
                    .accessibilityHidden(remainingText == nil)
            }
            Spacer(minLength: Spacing.section)
            VStack(spacing: Spacing.item) {
                if !isFinished {
                    Text(polish: "zakręci Ci się w głowie? Przerwij i oddychaj jak zwykle")
                        .hintText()
                        .multilineTextAlignment(.center)
                }
                StarActionButton(isFinished ? "gotowe" : "zakończ", size: .regular) {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, Spacing.card)
        .padding(.bottom, Spacing.group)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ambientBackground()
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: changes)
        .task {
            await breathe()
        }
        .onAppear {
            // The screen doesn't dim and lock in the middle of a breath.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app ends the exercise.
            if phase == .background {
                dismiss()
            }
        }
    }

    /// Small at rest and after a breath out, full after a breath in.
    private var star: some View {
        let isFull = step == .inhale
        return OrganicStar()
            .fill(Palette.accent)
            .frame(width: 170, height: 170)
            .scaleEffect(reduceMotion ? 0.8 : (isFull ? 1 : 0.5))
            .opacity(isFull ? 1 : 0.65)
            .shadow(color: Palette.accent.opacity(isFull ? 0.45 : 0.15), radius: isFull ? 30 : 10)
            .frame(width: 220, height: 220)
            .accessibilityHidden(true)
    }

    private var stepText: String {
        if isFinished {
            return "pięknie – to były trzy minuty tylko dla Ciebie"
        }
        switch step {
        case .inhale: return "wdech"
        case .exhale: return "wydech"
        case .rest: return "zaczynamy"
        }
    }

    /// "jeszcze ok. 3 min", "ostatni oddech"; nil before the first breath and at the end.
    private var remainingText: String? {
        guard !isFinished, breath > 0 else { return nil }
        guard breath < Self.breaths else { return "ostatni oddech" }
        let seconds = (Self.breaths - breath + 1) * (Self.inhaleSeconds + Self.exhaleSeconds)
        return "jeszcze ok. \((seconds + 59) / 60) min"
    }

    /// Leads the breaths to the end, after a moment to settle. Runs as the screen's task, so it is
    /// cancelled when the screen goes (she stopped, or left the app).
    private func breathe() async {
        try? await Task.sleep(for: .seconds(1.5))
        if Task.isCancelled { return }
        for number in 1...Self.breaths {
            breath = number
            go(to: .inhale, over: Self.inhaleSeconds)
            try? await Task.sleep(for: .seconds(Self.inhaleSeconds))
            if Task.isCancelled { return }
            go(to: .exhale, over: Self.exhaleSeconds)
            try? await Task.sleep(for: .seconds(Self.exhaleSeconds))
            if Task.isCancelled { return }
        }
        isFinished = true
        go(to: .rest, over: 2)
        onComplete()
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
