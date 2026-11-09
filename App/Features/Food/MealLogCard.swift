import SwiftUI
import AboutHerCore

/// "co zjadłaś": tap, type in plain Polish, and it saves itself – no confirm button.
struct MealLogCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate
    /// Opens the sheet that teaches the app an unknown product.
    let onTeach: (String) -> Void

    @State private var draft = ""
    @State private var isTyping = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let entries = store.data.meals(on: day)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("co zjadłaś").sectionTitle()
                    Spacer()
                    if !isTyping {
                        StarButton(label: "dopisz posiłek", prominent: true, action: startTyping)
                    }
                }
                if isTyping {
                    TextField("np. trzy jajka, łyżeczka masła, kromka chleba żytniego", text: $draft, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(Palette.text)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .lineLimit(1...5)
                        .onChange(of: draft) { _, newValue in
                            // The return key on a multi-line field inserts a newline: treat it as "done".
                            if newValue.contains("\n") {
                                draft = newValue.replacingOccurrences(of: "\n", with: " ")
                                save()
                            }
                        }
                    preview
                    Text(polish: "zapisze się samo, gdy stukniesz „gotowe” albo przewiniesz ekran")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                } else if entries.isEmpty {
                    Button(action: startTyping) {
                        Text(polish: "tu pojawi się to, co zjesz – dotknij, żeby dopisać")
                            .bodyText()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                ForEach(entries) { entry in
                    MealRow(entry: entry, onTeach: onTeach)
                        .swipeToDelete(label: "usuń posiłek") {
                            store.removeMeal(entry.id, on: day)
                        }
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                save()
            }
        }
        .onChange(of: day) {
            draft = ""
            isTyping = false
        }
    }

    /// Live preview of what the parser understands, while she types.
    @ViewBuilder private var preview: some View {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let parsed = store.mealParser.parse(trimmed)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(parsed.items.enumerated()), id: \.offset) { _, item in
                    Text(FoodFormat.itemLine(item))
                        .font(.caption)
                        .foregroundStyle(Palette.text2)
                }
                if !parsed.unknown.isEmpty {
                    Text("nie znam jeszcze: \(parsed.unknown.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func startTyping() {
        isTyping = true
        isFocused = true
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        isTyping = false
        isFocused = false
        guard !text.isEmpty else { return }
        store.logMeal(text, on: day)
    }
}

/// One logged meal: what she wrote, its values, and the parts the app doesn't know yet.
struct MealRow: View {
    let entry: MealEntry
    let onTeach: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
                .font(.subheadline)
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(FoodFormat.macrosLine(entry.totals))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.muted)
            if !entry.unknown.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("nie znam jeszcze:")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                    ForEach(entry.unknown, id: \.self) { name in
                        Button(name) { onTeach(name) }
                            .buttonStyle(LinkButtonStyle(font: .caption.weight(.medium)))
                            .accessibilityHint("dopisz wartości tego produktu")
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
