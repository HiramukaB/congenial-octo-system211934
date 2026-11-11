import SwiftUI
import AboutHerCore

/// The welcome steps in order. The raw value is what the phone remembers when she leaves midway,
/// so the welcome opens where she stopped.
nonisolated enum WelcomeStep: String, CaseIterable {
    case hello, name, cycle, numbers, targets, reminders, lock, tutorial, done

    /// The steps that ask her something – the ones the progress line counts.
    static var questions: [WelcomeStep] {
        [.name, .cycle, .numbers, .targets, .reminders, .lock]
    }

    var index: Int {
        WelcomeStep.allCases.firstIndex(of: self) ?? 0
    }

    var next: WelcomeStep? {
        let all = WelcomeStep.allCases
        let following = index + 1
        return following < all.count ? all[following] : nil
    }

    var previous: WelcomeStep? {
        let all = WelcomeStep.allCases
        let preceding = index - 1
        return preceding >= 0 && preceding < all.count ? all[preceding] : nil
    }
}

/// What the welcome keeps while she moves back and forth between its steps. Her answers themselves
/// are saved as she gives them; this only remembers how to correct them and what she has typed.
nonisolated struct WelcomeMemory {
    /// The days the cycle step marked – only these are taken back when she changes her answer.
    var markedDays: Set<LocalDate> = []
    /// The first day of the period she chose in the cycle step.
    var periodStart: LocalDate? = nil
    /// About how many days it lasts; nil until the step has set it.
    var periodLength: Int? = nil
    /// She wants to add a newer period than the ones she marked before.
    var isAddingNewerPeriod = false

    /// The three numbers as she typed them, and as they were last saved (or loaded): only a change
    /// against that is saved, so opening the step writes nothing.
    var numbers = WelcomeNumbersDraft()
    var numbersSaved = WelcomeNumbersDraft()
    var hasLoadedNumbers = false
    /// Today's weigh-in came from the welcome, so emptying the field takes it away again.
    var addedWeighIn = false

    /// Her own targets as she typed them, and as they were last saved (or loaded).
    var ownTargets = WelcomeTargetsDraft()
    var ownTargetsSaved = WelcomeTargetsDraft()
    var hasLoadedOwnTargets = false
}

/// The numbers step's fields, exactly as typed.
nonisolated struct WelcomeNumbersDraft: Equatable {
    var birthYear = ""
    var height = ""
    var weight = ""
}

/// Her own daily targets, exactly as typed.
nonisolated struct WelcomeTargetsDraft: Equatable {
    var kcal = ""
    var protein = ""
    var carbs = ""
    var fat = ""

    var isEmpty: Bool {
        [kcal, protein, carbs, fat].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

/// One welcome step: the way back and the progress at the top, the question with one short line
/// under it, the answer, and "dalej" at the bottom – above the keyboard while she types.
/// "pomiń" shows at the top while the step has no answer yet. Both move on, because everything
/// she gives is already saved; `onSkip` is only for a step whose "dalej" does a little more
/// (e.g. goes to the next empty field first).
struct WelcomePage<Content: View>: View {
    private let step: WelcomeStep
    private let title: String
    private let subtitle: String?
    private let canSkip: Bool
    private let onBack: (() -> Void)?
    private let onNext: () -> Void
    private let onSkip: (() -> Void)?
    private let content: Content

    init(step: WelcomeStep, title: String, subtitle: String? = nil, canSkip: Bool = false,
         onBack: (() -> Void)?, onNext: @escaping () -> Void, onSkip: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.canSkip = canSkip
        self.onBack = onBack
        self.onNext = onNext
        self.onSkip = onSkip
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            WelcomeBar(onBack: onBack, trailingTitle: canSkip ? "pomiń" : nil, onTrailing: onSkip ?? onNext) {
                WelcomeProgress(step: step)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        Text(polish: title)
                            .screenTitle()
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle {
                            Text(polish: subtitle)
                                .bodyText()
                        }
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.cardGap)
                .padding(.bottom, Spacing.group)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // Dragging down into the keyboard closes it; the fields save themselves anyway.
            .scrollDismissesKeyboard(.interactively)
            StarActionButton("dalej", action: onNext)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.item)
                .padding(.bottom, Spacing.tight)
        }
    }
}

/// The top line of a welcome step and of the guide: the way back on the left, where she is in the
/// middle, a quiet text action ("pomiń", "zamknij") on the right – each only when there is one.
struct WelcomeBar<Center: View>: View {
    private let onBack: (() -> Void)?
    private let trailingTitle: String?
    private let onTrailing: (() -> Void)?
    private let center: Center

    init(onBack: (() -> Void)?, trailingTitle: String? = nil, onTrailing: (() -> Void)? = nil,
         @ViewBuilder center: () -> Center) {
        self.onBack = onBack
        self.trailingTitle = trailingTitle
        self.onTrailing = onTrailing
        self.center = center()
    }

    var body: some View {
        ZStack {
            center
            HStack(spacing: 0) {
                if let onBack {
                    WelcomeBackButton(action: onBack)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if let trailingTitle, let onTrailing {
                    WelcomeTextButton(title: trailingTitle, action: onTrailing)
                        .transition(.opacity)
                }
            }
        }
        .frame(height: TapSize.minimum)
        .padding(.horizontal, Spacing.item)
        .padding(.top, Spacing.tight)
        .animation(.snappy(duration: 0.2), value: trailingTitle)
    }
}

/// Where she is among the questions: a line for each, the ones behind her filled, the current one
/// longer and brightest – readable at a glance. Nothing on the steps that ask nothing (the
/// greeting, the guide, the end).
struct WelcomeProgress: View {
    let step: WelcomeStep

    var body: some View {
        let questions = WelcomeStep.questions
        if let current = questions.firstIndex(of: step) {
            HStack(spacing: Spacing.hairline) {
                ForEach(0..<questions.count, id: \.self) { index in
                    Capsule()
                        .fill(color(for: index, current: current))
                        .frame(width: index == current ? 34 : 20, height: 5)
                }
            }
            .animation(.snappy(duration: 0.25), value: current)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "krok \(current + 1) z \(questions.count)"))
        }
    }

    private func color(for index: Int, current: Int) -> Color {
        if index == current {
            return Palette.accent
        }
        return index < current ? Palette.accent.opacity(0.55) : Color.white.opacity(0.16)
    }
}

/// "wstecz": a round 44 pt button with a chevron, like the system's back button.
struct WelcomeBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.text)
                .frame(width: TapSize.minimum, height: TapSize.minimum)
                .background {
                    Circle().fill(Color.white.opacity(0.07))
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(Text("wstecz"))
    }
}

/// A quiet text action at the top: "pomiń", "zamknij". At least 44 pt to tap.
struct WelcomeTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(Palette.text2)
                .padding(.horizontal, Spacing.tight)
                .frame(minWidth: TapSize.minimum, minHeight: TapSize.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A row of numbers in a card: the label (and a short line under it) on the left, the open field
/// with its unit on the right. A tap anywhere on the row gives the field the keyboard.
struct WelcomeNumberRow<Field: View>: View {
    private let title: String
    private let detail: String?
    private let unit: String?
    private let onTap: () -> Void
    private let field: Field

    init(_ title: String, detail: String? = nil, unit: String? = nil, onTap: @escaping () -> Void,
         @ViewBuilder field: () -> Field) {
        self.title = title
        self.detail = detail
        self.unit = unit
        self.onTap = onTap
        self.field = field()
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.item) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .rowTitle()
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(polish: detail)
                        .rowDetail()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.hairline) {
                field
                if let unit {
                    Text(unit)
                        .rowDetail()
                        .accessibilityHidden(true)
                }
            }
            .fieldBox()
            .frame(width: 150)
        }
        .padding(.vertical, Spacing.tight)
        .frame(minHeight: TapSize.large)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
