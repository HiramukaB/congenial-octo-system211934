import SwiftUI
import AboutHerCore

/// "wnętrze", opened from "ja": the intention for today, small wins, the manifest "kim się
/// stajesz" and the question of the week, with the weeks before it. Everything is written in
/// place and saves itself; a tap corrects, a swipe to the left removes.
struct InnerView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Screen {
            ScreenHeader(title: "wnętrze")
            TodayIntentionCard(day: store.today)
            InnerWinsCard()
            InnerManifestCard()
            InnerReflectionCards()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "małe zwycięstwa": a clear "dopisz zwycięstwo", then her wins, the latest first.
private struct InnerWinsCard: View {
    @Environment(AppStore.self) private var store
    @State private var showsAll = false

    /// How many wins show before "pokaż wszystkie".
    private static let recentCount = 5
    private static let placeholder = "np. poszłam na spacer, choć byłam zmęczona"

    var body: some View {
        let wins = store.data.winsNewestFirst
        let shown = showsAll ? wins : Array(wins.prefix(Self.recentCount))
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("małe zwycięstwa",
                              subtitle: wins.isEmpty ? "drobne rzeczy, z których jesteś dumna" : nil)
                // A new win: the button opens an empty field, which closes again once the win is saved.
                InnerTextField(key: store.today,
                               text: "",
                               placeholder: Self.placeholder,
                               emptyLine: "dopisz zwycięstwo",
                               emptyStyle: .action,
                               save: { text, day in
                                   // The date can move back (a time zone to the west): then it goes to today.
                                   text.isEmpty || store.addWin(text, on: Swift.min(day, store.today))
                               })
                if !shown.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(shown) { win in
                            if win.id != shown.first?.id {
                                RowDivider()
                            }
                            InnerTextField(key: win.id,
                                           text: win.text,
                                           placeholder: Self.placeholder,
                                           detail: InnerFormat.day(win.day, today: store.today),
                                           deleteLabel: "usuń zwycięstwo",
                                           emptiedHint: "żeby usunąć zwycięstwo, przesuń je w lewo",
                                           save: { text, id in
                                               // An emptied line changes nothing; a win is removed with a swipe.
                                               text.isEmpty || store.updateWin(id, text: text)
                                           },
                                           delete: { id in store.removeWin(id) })
                        }
                    }
                }
                if wins.count > shown.count {
                    Button("pokaż wszystkie (\(wins.count))") {
                        withAnimation(.smooth) {
                            showsAll = true
                        }
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }
}

/// "kim się stajesz": her own words about who she is becoming – the heart of this screen.
private struct InnerManifestCard: View {
    @Environment(AppStore.self) private var store

    /// The web version's starting sentence – only an example, never saved for her.
    private static let example = "Jestem kimś, kto dotrzymuje sobie słowa. Buduję siłę i spokój, dzień po dniu."

    var body: some View {
        Card(style: .highlight) {
            VStack(alignment: .leading, spacing: Spacing.item) {
                SectionHeader("kim się stajesz")
                InnerTextField(key: "manifest",
                               text: store.data.manifest,
                               placeholder: Self.example,
                               emptyLine: "napisz swoimi słowami, kim się stajesz",
                               serif: true,
                               lines: 2...10,
                               save: { text, _ in store.setManifest(text) },
                               delete: { _ in store.setManifest("") })
            }
        }
    }
}

/// "refleksja tygodnia": one question a week and her answer, kept with the question as she saw it,
/// then the weeks before – to read again, and to correct.
private struct InnerReflectionCards: View {
    @Environment(AppStore.self) private var store
    @State private var showsAll = false

    /// How many past weeks show before "pokaż wszystkie".
    private static let recentCount = 3

    var body: some View {
        let week = store.today.startOfWeek
        let past = store.data.pastReflections(before: store.today)
        let shownPast = showsAll ? past : Array(past.prefix(Self.recentCount))
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.item) {
                    SectionHeader("refleksja tygodnia", subtitle: "co tydzień nowe pytanie")
                    Text(polish: question(forWeekOf: week))
                        .displayFont(19, italic: true, relativeTo: .body)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    answerField(week: week,
                                answer: store.data.reflection(forWeekOf: week)?.answer ?? "",
                                emptyLine: "odpowiedz – kilka słów wystarczy")
                }
            }
            if !past.isEmpty {
                Card(style: .quiet) {
                    VStack(alignment: .leading, spacing: Spacing.item) {
                        SectionHeader("poprzednie tygodnie")
                        VStack(alignment: .leading, spacing: Spacing.item) {
                            ForEach(shownPast) { entry in
                                if entry.id != shownPast.first?.id {
                                    RowDivider()
                                }
                                pastWeek(entry)
                            }
                        }
                        if past.count > shownPast.count {
                            Button("pokaż wszystkie (\(past.count))") {
                                withAnimation(.smooth) {
                                    showsAll = true
                                }
                            }
                            .buttonStyle(LinkButtonStyle())
                        }
                    }
                }
            }
        }
    }

    /// An earlier week: when it was, the question then, and her answer to correct or remove.
    private func pastWeek(_ entry: PastReflection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text("tydzień od \(InnerFormat.date(entry.week, today: store.today))")
                .rowDetail()
            Text(polish: entry.reflection.question)
                .font(.subheadline.italic())
                .foregroundStyle(Palette.text2)
                .fixedSize(horizontal: false, vertical: true)
            answerField(week: entry.week, answer: entry.reflection.answer, emptyLine: "")
        }
    }

    /// Her answer for the week starting on `week`; emptied, the week's reflection goes.
    private func answerField(week: LocalDate, answer: String, emptyLine: String) -> some View {
        InnerTextField(key: week,
                       text: answer,
                       placeholder: "Twoja odpowiedź",
                       emptyLine: emptyLine,
                       lines: 2...8,
                       deleteLabel: "usuń odpowiedź",
                       save: { text, target in
                           store.setReflection(question: question(forWeekOf: target), answer: text, forWeekOf: target)
                       },
                       delete: { target in
                           store.setReflection(question: "", answer: "", forWeekOf: target)
                       })
    }

    /// The question of a week as she saw it: the one kept with her answer, otherwise the week's own.
    private func question(forWeekOf week: LocalDate) -> String {
        store.data.reflection(forWeekOf: week)?.question ?? WeeklyReflection.question(forWeekOf: week)
    }
}
