import SwiftUI
import AboutHerCore

/// "Twój ruch": this week at a glance – a star for every day she moved, a weekly count and never a
/// streak to keep – then "dopisz ruch" and what she logged in the last seven days, newest first.
/// A tap on an entry opens it in place, a swipe left deletes it. The editor saves every change at
/// once, so closing it never loses anything.
struct WorkoutLogCard: View {
    @Environment(AppStore.self) private var store
    /// What the editor is open for; nil while it is closed.
    @State private var editing: WorkoutEditing? = nil

    /// How many days the list goes back, today included.
    private static let listedDays = 7

    var body: some View {
        let today = store.today
        let week = store.movementWeek
        // A new entry is edited above the list, so it isn't listed twice.
        let newEntryID: UUID? = editing?.isNew == true ? editing?.id : nil
        let entries = store.data.recentWorkouts(through: today, days: Self.listedDays)
            .filter { $0.workout.id != newEntryID }
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("Twój ruch", subtitle: weekLine(week))
                MovementWeekStrip(monday: week.monday, today: today, activeDays: week.activeDays)
                if let editing, editing.isNew {
                    WorkoutEditor(editing: editing, onClose: close)
                } else {
                    StarActionButton("dopisz ruch", size: .regular, action: startNew)
                }
                if !entries.isEmpty {
                    list(entries)
                    MoreInfo("jak liczę kcal?", text: kcalNote)
                }
            }
        }
        .onDisappear {
            // Everything is saved already; she comes back to a calm card.
            editing = nil
        }
    }

    // MARK: - Parts

    /// "w tym tygodniu: 3 dni z ruchem · 95 min"
    private func weekLine(_ week: MovementWeek) -> String {
        guard week.workoutCount > 0 else {
            return "w tym tygodniu jeszcze nic – każdy ruch się liczy"
        }
        return "w tym tygodniu: \(PolishPlural.days(week.activeDays.count)) z ruchem · \(week.minutes) min"
    }

    private func list(_ entries: [DatedWorkout]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                if let editing, editing.id == entry.workout.id, editing.day == entry.day {
                    // The entry she tapped opens right where it was.
                    WorkoutEditor(editing: editing, onClose: close)
                        .padding(.vertical, Spacing.item)
                } else {
                    row(entry)
                }
                if entry.id != entries.last?.id {
                    RowDivider()
                }
            }
        }
    }

    /// "spacer" · "dziś · ok. 114 kcal" · "30 min"
    private func row(_ entry: DatedWorkout) -> some View {
        let workout = entry.workout
        let day = MovementFormat.recentDay(entry.day, today: store.today)
        let kcal = MovementFormat.kcal(store.movementKcal(workout.kind, minutes: workout.minutes))
        return ListRow(workout.kind.label, detail: "\(day) · \(kcal)") {
            Text(verbatim: "\(workout.minutes) min")
                .valueText()
        }
        .swipeToDelete(label: "usuń ruch", onTap: { edit(entry) }) {
            remove(entry)
        }
    }

    private var kcalNote: String {
        store.isMovementWeightAssumed
            ? "to szacunek z rodzaju ruchu i czasu, liczony dla 65 kg, dopóki nie zapiszesz swojej wagi w zakładce jedzenie"
            : "to szacunek z rodzaju ruchu, czasu i Twojej wagi – nie dokładny pomiar"
    }

    // MARK: - Editing

    private func startNew() {
        withAnimation(.smooth) {
            editing = WorkoutEditing(id: UUID(), day: store.today, isNew: true)
        }
    }

    /// A tap on an entry opens it in place. Nothing in an open editor needs saving first.
    private func edit(_ entry: DatedWorkout) {
        withAnimation(.smooth) {
            editing = WorkoutEditing(id: entry.workout.id, day: entry.day, isNew: false)
        }
    }

    private func close() {
        withAnimation(.smooth) {
            editing = nil
        }
    }

    private func remove(_ entry: DatedWorkout) {
        withAnimation(.snappy(duration: 0.2)) {
            store.removeWorkout(entry.workout.id, on: entry.day)
        }
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
                let isActive = activeDays.contains(day)
                let isToday = day == today
                VStack(spacing: Spacing.tight) {
                    ZStack {
                        OrganicStar()
                            .fill(isActive ? Palette.accent : Color.clear)
                        OrganicStar()
                            .stroke(isActive ? Palette.accent : Palette.accentDim.opacity(0.45), lineWidth: 1.2)
                    }
                    .frame(width: 22, height: 22)
                    Text(PolishDate.weekdayInitials[offset])
                        .font(.footnote.weight(isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? Palette.accent : Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .opacity(day > today ? 0.45 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenWeek))
    }

    /// "dni z ruchem w tym tygodniu: poniedziałek, środa"
    private var spokenWeek: String {
        let names = (0..<7).compactMap { offset -> String? in
            activeDays.contains(monday.adding(days: offset)) ? MovementFormat.weekdays[offset] : nil
        }
        guard !names.isEmpty else { return "w tym tygodniu jeszcze bez ruchu" }
        return "dni z ruchem w tym tygodniu: \(names.joined(separator: ", "))"
    }
}
