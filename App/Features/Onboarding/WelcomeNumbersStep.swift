import SwiftUI
import UIKit
import AboutHerCore

/// A field of the numbers step.
nonisolated enum WelcomeNumberField: Hashable {
    case birthYear, height, weight
}

/// "kilka liczb o Tobie": birth year, height and today's weight – what her daily targets are
/// counted from, with the same profile and the same rules as "Twoje cele dzienne" in "jedzenie".
///
/// Each number is saved when she leaves its field (or the step), once it can be right: the weight
/// as today's weigh-in, the profile once all three are known (keeping her activity, pace and
/// targets). Nothing is written just because the step was opened, nothing while she is still
/// typing, and a weigh-in the welcome added goes again if she empties the field.
struct WelcomeNumbersStep: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Binding var memory: WelcomeMemory
    let onBack: () -> Void
    let onNext: () -> Void
    @FocusState private var focus: WelcomeNumberField?

    var body: some View {
        let draft = memory.numbers
        WelcomePage(step: .numbers,
                    title: "kilka liczb o Tobie",
                    subtitle: "z nich policzę Twoje cele na każdy dzień",
                    canSkip: Self.isBlank(draft.birthYear) && Self.isBlank(draft.height) && Self.isBlank(draft.weight),
                    onBack: goBack,
                    onNext: moveOn,
                    onSkip: skip) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                Card {
                    VStack(spacing: 0) {
                        WelcomeNumberRow("rok urodzenia", onTap: { focus = .birthYear }) {
                            numberField("1995", text: $memory.numbers.birthYear, field: .birthYear,
                                        keyboard: .numberPad, label: "rok urodzenia")
                        }
                        RowDivider()
                        WelcomeNumberRow("wzrost", unit: "cm", onTap: { focus = .height }) {
                            numberField("165", text: $memory.numbers.height, field: .height,
                                        keyboard: .decimalPad, label: "wzrost w centymetrach")
                        }
                        RowDivider()
                        WelcomeNumberRow("waga dziś", detail: weightDetail, unit: "kg", onTap: { focus = .weight }) {
                            numberField("64,5", text: $memory.numbers.weight, field: .weight,
                                        keyboard: .decimalPad, label: "waga dziś w kilogramach")
                        }
                    }
                }
                status(draft)
            }
            .animation(.smooth(duration: 0.25), value: statusKind(draft).rawValue)
        }
        .onAppear(perform: load)
        // Saved when she leaves a field or the step, never mid-typing: emptying "64,5" passes
        // "64", which would replace her real weigh-in.
        .onChange(of: focus) { _, _ in
            save()
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: save the fields and the file now.
            if phase == .background {
                save()
                store.saveNow()
            }
        }
        .onDisappear {
            save()
        }
    }

    private func numberField(_ placeholder: String, text: Binding<String>, field: WelcomeNumberField,
                             keyboard: UIKeyboardType, label: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.trailing)
            .font(.title3.monospacedDigit())
            .foregroundStyle(Palette.text)
            .focused($focus, equals: field)
            .accessibilityLabel(Text(label))
    }

    /// Under "waga dziś": her last weigh-in before today, for comparison.
    private var weightDetail: String {
        let today = store.today
        guard let last = store.weightPoints.last(where: { $0.day < today }) else {
            return "zapiszę ją w pomiarach"
        }
        return "ostatnio \(BodyNumbers.text(last.kg)) kg · \(PolishDate.short(last.day))"
    }

    // MARK: - The line under the card

    private enum StatusKind: Int {
        case quiet, problem, complete, partial
    }

    private func statusKind(_ draft: WelcomeNumbersDraft) -> StatusKind {
        if problem(in: draft) != nil {
            return .problem
        }
        if isComplete(draft) {
            return .complete
        }
        let isEmpty = Self.isBlank(draft.birthYear) && Self.isBlank(draft.height) && Self.isBlank(draft.weight)
        return isEmpty ? .quiet : .partial
    }

    @ViewBuilder
    private func status(_ draft: WelcomeNumbersDraft) -> some View {
        switch statusKind(draft) {
        case .problem:
            Text(polish: problem(in: draft) ?? "")
                .font(.footnote)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
        case .complete:
            ConfirmationNote(text: "mam wszystko, czego potrzebuję do Twoich celów")
        case .partial:
            Text(polish: "do celów potrzebuję roku urodzenia, wzrostu i wagi")
                .hintText()
        case .quiet:
            EmptyView()
        }
    }

    /// The first number that can't be right – but not while she is still typing it.
    private func problem(in draft: WelcomeNumbersDraft) -> String? {
        if focus != .birthYear, !Self.isBlank(draft.birthYear),
           BodyNumbers.birthYear(draft.birthYear, currentYear: store.today.year) == nil {
            return "rok urodzenia wpisz w całości, np. 1995"
        }
        if focus != .height, !Self.isBlank(draft.height), BodyNumbers.heightCm(draft.height) == nil {
            return "wzrost podaj w centymetrach, np. 165"
        }
        if focus != .weight, !Self.isBlank(draft.weight), BodyNumbers.weightKg(draft.weight) == nil {
            return "wagę podaj w kilogramach, np. 64,5"
        }
        return nil
    }

    /// Year and height can be used, and a weight is known – typed now or from before.
    private func isComplete(_ draft: WelcomeNumbersDraft) -> Bool {
        BodyNumbers.birthYear(draft.birthYear, currentYear: store.today.year) != nil
            && BodyNumbers.heightCm(draft.height) != nil
            && profileWeight(draft) != nil
    }

    /// The weight the profile gets: the one she typed, else the profile's own, else her trend.
    private func profileWeight(_ draft: WelcomeNumbersDraft) -> Double? {
        BodyNumbers.weightKg(draft.weight) ?? store.data.nutritionProfile?.weightKg ?? store.currentWeight
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func text(of field: WelcomeNumberField) -> String {
        switch field {
        case .birthYear: memory.numbers.birthYear
        case .height: memory.numbers.height
        case .weight: memory.numbers.weight
        }
    }

    // MARK: - Moving on

    /// "dalej" first goes to the next empty field, like the keyboard's own "dalej"; then on.
    private func moveOn() {
        let order: [WelcomeNumberField] = [.birthYear, .height, .weight]
        if let current = focus, let index = order.firstIndex(of: current),
           let empty = order[(index + 1)...].first(where: { Self.isBlank(text(of: $0)) }) {
            focus = empty
            return
        }
        focus = nil
        save()
        onNext()
    }

    private func skip() {
        focus = nil
        save()
        onNext()
    }

    private func goBack() {
        focus = nil
        save()
        onBack()
    }

    // MARK: - Loading and saving

    /// What she gave before: the profile's year and height, and today's weigh-in. With nothing at
    /// all yet, the first field gets the keyboard.
    private func load() {
        guard !memory.hasLoadedNumbers else { return }
        var draft = WelcomeNumbersDraft()
        if let profile = store.data.nutritionProfile {
            draft.birthYear = String(profile.birthYear)
            draft.height = BodyNumbers.text(profile.heightCm)
        }
        if let kg = store.data.weights[store.today] {
            draft.weight = BodyNumbers.text(kg)
        }
        // The baseline first, so loading itself saves nothing.
        memory.numbersSaved = draft
        memory.numbers = draft
        memory.hasLoadedNumbers = true
        if draft == WelcomeNumbersDraft() {
            focus = .birthYear
        }
    }

    /// Saves what changed since the last save, as far as it can be right. Called when she leaves
    /// a field or the step, and when the app goes to the background.
    private func save() {
        let draft = memory.numbers
        let before = memory.numbersSaved
        guard memory.hasLoadedNumbers, draft != before else { return }
        memory.numbersSaved = draft
        let today = store.today
        if draft.weight != before.weight {
            saveWeight(draft.weight, on: today)
        }
        guard let year = BodyNumbers.birthYear(draft.birthYear, currentYear: today.year),
              let height = BodyNumbers.heightCm(draft.height),
              let weight = profileWeight(draft)
        else { return }
        let stored = store.data.nutritionProfile
        let profile = NutritionProfile(birthYear: year, heightCm: height, weightKg: weight,
                                       activity: stored?.activity ?? .light,
                                       deficitKcal: stored?.deficitKcal ?? WelcomePace.gentle.rawValue)
        guard profile != stored else { return }
        _ = store.saveNutrition(profile: profile, targets: store.data.targetsSetting)
    }

    /// Today's weigh-in from the field. Emptied, only a weigh-in the welcome added goes away.
    private func saveWeight(_ text: String, on today: LocalDate) {
        if let kg = BodyNumbers.weightKg(text) {
            let existing = store.data.weights[today]
            guard existing != (kg * 10).rounded() / 10 else { return }
            if store.setWeight(kg, on: today) && existing == nil {
                memory.addedWeighIn = true
            }
        } else if Self.isBlank(text) && memory.addedWeighIn {
            store.removeWeight(on: today)
            memory.addedWeighIn = false
        }
    }
}
