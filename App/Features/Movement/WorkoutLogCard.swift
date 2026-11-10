import SwiftUI
import AboutHerCore

/// "Twój ruch": this week as a count of days with movement – never a streak to keep – and what she
/// logged, today first. "dopisz ruch" opens a field for any activity; a tap on an entry opens it
/// in the same field to correct it, a swipe left deletes it. The field saves itself when the
/// keyboard goes, when the app goes to the background and when she leaves the tab.
struct WorkoutLogCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    /// What the open field writes; nil while it is closed.
    @State private var editing: Editing? = nil
    @State private var minutesDraft = ""
    /// The last minutes she typed couldn't be saved.
    @State private var wasRejected = false
    @FocusState private var isFocused: Bool

    /// A new entry, or a logged one she tapped, and the day it belongs to.
    struct Editing {
        /// nil for a new entry.
        var workoutID: UUID?
        var day: LocalDate
        var kind: WorkoutKind
    }

    var body: some View {
        let today = store.today
        let week = store.movementWeek
        // This week's days up to today, today first.
        let pastDays = Swift.max(0, week.monday.days(to: today))
        let days = (0...pastDays).map { today.adding(days: -$0) }
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Twój ruch").sectionTitle()
                    Spacer()
                    if editing == nil {
                        StarButton(label: "dopisz ruch", prominent: true, action: startNew)
                    }
                }
                MovementWeekStrip(monday: week.monday, today: today, activeDays: week.activeDays)
                Text(weekLine(week))
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
                if let editing {
                    // One and the same field for a new entry and a tapped one, so the keyboard
                    // stays up from entry to entry.
                    editor(editing)
                }
                if wasRejected {
                    Text(polish: "tego nie zapiszę – wpisz liczbę minut od 1 do 600, np. 30")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
                ForEach(days, id: \.self) { day in
                    // The entry in the field isn't listed twice.
                    let entries = store.data.workouts(on: day).filter { $0.id != editing?.workoutID }
                    if !entries.isEmpty {
                        Text(MovementFormat.dayTitle(day, today: today))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 2)
                        ForEach(entries) { workout in
                            row(workout, on: day)
                        }
                    }
                }
                if week.workoutCount == 0 && editing == nil {
                    Button(action: startNew) {
                        Text(polish: "tu pojawi się Twój ruch – dotknij, żeby dopisać spacer, jogę albo cokolwiek innego")
                            .bodyText()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // A light tap when she picks another kind; opening and closing the field have the star's own.
        .sensoryFeedback(.selection, trigger: editing?.kind) { oldKind, newKind in
            oldKind != nil && newKind != nil
        }
        .onChange(of: isFocused) { _, focused in
            // The keyboard went away (dragged down, another tab): she is done.
            if !focused {
                save()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: save the field and the file now.
            if phase == .background && editing != nil {
                save()
                store.saveNow()
            }
        }
        .onDisappear {
            // Another tab took over before the field lost focus.
            save()
        }
    }

    // MARK: - Parts

    /// "w tym tygodniu: 3 dni z ruchem · 95 min"
    private func weekLine(_ week: MovementWeek) -> String {
        guard week.workoutCount > 0 else {
            return "w tym tygodniu: jeszcze nic – każdy ruch się liczy, nawet krótki spacer"
        }
        return "w tym tygodniu: \(PolishPlural.days(week.activeDays.count)) z ruchem · \(week.minutes) min"
    }

    private func row(_ workout: Workout, on day: LocalDate) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(workout.kind.label) · \(workout.minutes) min")
                .font(.subheadline)
                .foregroundStyle(Palette.text)
            Spacer()
            Text(MovementFormat.kcal(store.movementKcal(workout.kind, minutes: workout.minutes)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .swipeToDelete(label: "usuń ruch", onTap: { edit(workout, on: day) }) {
            store.removeWorkout(workout.id, on: day)
        }
    }

    private func editor(_ editing: Editing) -> some View {
        let flow = FlowLayout(spacing: 6, lineSpacing: 6)
        let typedMinutes = Int(minutesDraft.trimmingCharacters(in: .whitespaces))
        return VStack(alignment: .leading, spacing: 10) {
            Text(polish: hint(for: editing))
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            flow {
                ForEach(WorkoutKind.allCases, id: \.self) { kind in
                    kindChip(kind, isSelected: kind == editing.kind)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("np. 30", text: $minutesDraft)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit { save() }
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: 90)
                    .accessibilityLabel("minuty")
                    .accessibilityIdentifier("workout-minutes")
                    // In case the focus asked for together with showing the field didn't take.
                    .onAppear { isFocused = true }
                Text("min")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                Spacer()
                if let typedMinutes, Workout.minuteRange.contains(typedMinutes) {
                    Text(MovementFormat.kcal(store.movementKcal(editing.kind, minutes: typedMinutes)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.accentBackground.opacity(0.6))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
        }
    }

    /// One kind to choose; the chosen one carries a star.
    private func kindChip(_ kind: WorkoutKind, isSelected: Bool) -> some View {
        Button {
            self.editing?.kind = kind
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    OrganicStar()
                        .fill(Palette.accent)
                        .frame(width: 9, height: 9)
                }
                Text(kind.label)
                    .font(.footnote.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Palette.accent : Palette.text2)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background {
                Capsule()
                    .fill(isSelected ? Palette.accent.opacity(0.16) : Color.clear)
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Palette.accent.opacity(0.4) : Palette.line, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func hint(for editing: Editing) -> String {
        // The return key shows a word or a checkmark, so the hint speaks of the keyboard.
        guard editing.workoutID != nil else {
            return "co i ile minut? Zapiszę to, gdy schowasz klawiaturę"
        }
        let day = editing.day == store.today ? "" : " z \(PolishDate.dayMonth(editing.day))"
        return "poprawiasz wpis\(day) – zapiszę zmianę, gdy schowasz klawiaturę"
    }

    // MARK: - Editing

    private func startNew() {
        guard editing == nil else { return }
        wasRejected = false
        editing = Editing(workoutID: nil, day: store.today, kind: .walk)
        minutesDraft = ""
        isFocused = true
    }

    /// A tap on a logged entry opens it in the field. What the field held is saved first.
    private func edit(_ workout: Workout, on day: LocalDate) {
        if editing != nil {
            save()
        } else {
            wasRejected = false
        }
        editing = Editing(workoutID: workout.id, day: day, kind: workout.kind)
        minutesDraft = String(workout.minutes)
        isFocused = true
    }

    /// Saves the field to its own day and closes it. An empty field changes nothing – an entry
    /// is deleted with a swipe.
    private func save() {
        guard let target = editing else { return }
        let text = minutesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        closeField()
        guard !text.isEmpty else { return }
        guard let minutes = Int(text), Workout.minuteRange.contains(minutes) else {
            // Only minutes that can't be saved get this line. When the store refuses for another
            // reason (read-only data), it shows its own alert.
            wasRejected = true
            return
        }
        wasRejected = false
        if let id = target.workoutID, store.data.workouts(on: target.day).contains(where: { $0.id == id }) {
            store.updateWorkout(id, kind: target.kind, minutes: minutes, on: target.day)
        } else {
            // A new entry, or one that isn't there any more: her minutes are kept as a new entry.
            // The date can move back (a time zone to the west): it then goes to the day it is now.
            store.logWorkout(target.kind, minutes: minutes, on: Swift.min(target.day, store.today))
        }
    }

    private func closeField() {
        editing = nil
        isFocused = false
        minutesDraft = ""
    }
}

/// Monday to Sunday, a star for every day she moved: a weekly count, not a streak to keep.
struct MovementWeekStrip: View {
    let monday: LocalDate
    let today: LocalDate
    let activeDays: Set<LocalDate>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = monday.adding(days: offset)
                VStack(spacing: 5) {
                    OrganicStar()
                        .fill(activeDays.contains(day) ? Palette.accent : Palette.line)
                        .frame(width: 16, height: 16)
                    Text(PolishDate.weekdayInitials[offset])
                        .font(.caption2.weight(day == today ? .semibold : .regular))
                        .foregroundStyle(day == today ? Palette.accent : Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .opacity(day > today ? 0.45 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "dni z ruchem w tym tygodniu: \(activeDays.count)"))
    }
}
