import SwiftUI
import AboutHerCore

/// What the editor is open for: an entry she logged, or a new one. A new entry has its id from the
/// start and is saved as soon as she picks its kind.
struct WorkoutEditing: Equatable {
    let id: UUID
    let day: LocalDate
    let isNew: Bool
}

/// The movement editor, open in place: large tiles for the kind and a scale she drags for the
/// minutes. Every change is saved at once – a new entry as soon as she picks its kind, starting
/// from the minutes she logged for it last time – so "gotowe" only closes it.
struct WorkoutEditor: View {
    @Environment(AppStore.self) private var store
    private let editing: WorkoutEditing
    private let onClose: () -> Void

    /// She opened the rarer kinds with "więcej".
    @State private var showsAllKinds = false
    /// Something was saved while it is open, so "zapisałam" shows.
    @State private var hasSaved = false

    /// The kinds shown before "więcej".
    private static let commonKinds: [WorkoutKind] = [.walk, .yoga, .stretching, .pilates, .strength]

    init(editing: WorkoutEditing, onClose: @escaping () -> Void) {
        self.editing = editing
        self.onClose = onClose
    }

    var body: some View {
        let saved = savedWorkout
        // A rarer kind she has chosen keeps every kind in view.
        let hasRareKind = saved.map { !Self.commonKinds.contains($0.kind) } ?? false
        let showsAll = showsAllKinds || hasRareKind
        let kinds = showsAll ? WorkoutKind.allCases : Self.commonKinds
        VStack(alignment: .leading, spacing: Spacing.group) {
            VStack(alignment: .leading, spacing: Spacing.item) {
                Text(MovementFormat.question(for: editing.day, today: store.today))
                    .rowTitle()
                TileGrid(columns: 2) {
                    ForEach(kinds, id: \.self) { kind in
                        ToggleTile(title: kind.label, isOn: kind == saved?.kind) {
                            choose(kind)
                        }
                    }
                    if !hasRareKind {
                        MoreKindsTile(isExpanded: showsAll) {
                            withAnimation(.smooth) {
                                showsAllKinds.toggle()
                            }
                        }
                    }
                }
            }
            if let saved {
                WorkoutMinutesScale(minutes: saved.minutes) { minutes in
                    setMinutes(minutes)
                }
            }
            HStack(spacing: Spacing.item) {
                StarActionButton("gotowe", size: .regular, action: onClose)
                Spacer(minLength: 0)
                if hasSaved {
                    ConfirmationNote(text: "zapisałam")
                }
            }
        }
    }

    /// The entry as it is saved now; nil for a new one until she picks its kind.
    private var savedWorkout: Workout? {
        store.data.workouts(on: editing.day).first { $0.id == editing.id }
    }

    // MARK: - Changes

    /// Saves the kind at once. A new entry starts with the minutes she logged for it last time.
    private func choose(_ kind: WorkoutKind) {
        let current = savedWorkout
        guard current?.kind != kind else { return }
        let minutes = current?.minutes ?? store.suggestedMinutes(for: kind)
        let workout = Workout(id: editing.id, kind: kind, minutes: minutes)
        let isSaved = withAnimation(.smooth) {
            store.saveWorkout(workout, on: editing.day)
        }
        if isSaved {
            confirm()
        }
    }

    /// Every step of the scale is saved at once.
    private func setMinutes(_ minutes: Int) {
        guard var workout = savedWorkout, workout.minutes != minutes else { return }
        workout.minutes = minutes
        if store.saveWorkout(workout, on: editing.day) {
            confirm()
        }
    }

    private func confirm() {
        guard !hasSaved else { return }
        withAnimation(.smooth) {
            hasSaved = true
        }
    }
}

/// The last tile among the kinds: "więcej" shows the rarer ones, "mniej" folds them away again.
private struct MoreKindsTile: View {
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.tight + 2) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accentDim)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(isExpanded ? "mniej" : "więcej")
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.item + 2)
            .padding(.vertical, Spacing.tight)
            .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(Text(isExpanded ? "mniej rodzajów ruchu" : "więcej rodzajów ruchu"))
    }
}
