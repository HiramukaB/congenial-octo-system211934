import SwiftUI
import AboutHerCore

/// "wnętrze", opened from "ja": the intention for today, small wins, the manifest "kim się
/// stajesz" and the question of the week, with the weeks before it. Everything is written in
/// place and saves itself; a tap corrects, a swipe to the left removes.
struct InnerView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Screen {
            Text("wnętrze").screenTitle()
            TodayIntentionCard(day: store.today)
            InnerWinsCard()
            InnerManifestCard()
            InnerReflectionCards()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "małe zwycięstwa": a short line at a time, the latest first.
private struct InnerWinsCard: View {
    @Environment(AppStore.self) private var store
    @State private var showsAll = false

    /// How many wins show before "pokaż wszystkie".
    private static let recentCount = 7
    private static let placeholder = "np. poszłam na spacer, choć byłam zmęczona"

    var body: some View {
        let wins = store.data.winsNewestFirst
        let shown = showsAll ? wins : Array(wins.prefix(Self.recentCount))
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("małe zwycięstwa").sectionTitle()
                Text(polish: "drobne rzeczy, z których jesteś dumna – każda się liczy")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                // A new win: the field opens empty and closes again once the win is saved.
                InnerTextField(key: store.today,
                               text: "",
                               placeholder: Self.placeholder,
                               emptyLine: "dopisz małe zwycięstwo",
                               save: { text, day in
                                   // The date can move back (a time zone to the west): then it goes to today.
                                   text.isEmpty || store.addWin(text, on: Swift.min(day, store.today))
                               })
                ForEach(shown) { win in
                    InnerTextField(key: win.id,
                                   text: win.text,
                                   placeholder: Self.placeholder,
                                   detail: InnerFormat.day(win.day, today: store.today),
                                   deleteLabel: "usuń zwycięstwo",
                                   emptiedHint: "pusty tekst niczego nie zmieni – zwycięstwo usuniesz, przesuwając je w lewo",
                                   save: { text, id in
                                       // An emptied line changes nothing; a win is removed with a swipe.
                                       text.isEmpty || store.updateWin(id, text: text)
                                   },
                                   delete: { id in store.removeWin(id) })
                }
                if wins.count > shown.count {
                    Button("pokaż wszystkie (\(wins.count))") {
                        showsAll = true
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }
}

/// "kim się stajesz": her own words about who she is becoming.
private struct InnerManifestCard: View {
    @Environment(AppStore.self) private var store

    /// The web version's starting sentence – only an example, never saved for her.
    private static let example = "Jestem kimś, kto dotrzymuje sobie słowa. Buduję siłę i spokój, dzień po dniu."

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("kim się stajesz").sectionTitle()
                InnerTextField(key: "manifest",
                               text: store.data.manifest,
                               placeholder: Self.example,
                               emptyLine: "dotknij i napisz to swoimi słowami, np. „\(Self.example)”",
                               serif: true,
                               lines: 2...10,
                               save: { text, _ in store.setManifest(text) },
                               delete: { _ in store.setManifest("") })
                Text(polish: "Twoje własne słowa. Wracaj tu w dni, w które trudno w to uwierzyć")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("refleksja tygodnia").sectionTitle()
                    Text(polish: question(forWeekOf: week))
                        .displayFont(17, italic: true, relativeTo: .body)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    answerField(week: week,
                                answer: store.data.reflection(forWeekOf: week)?.answer ?? "",
                                emptyLine: "dotknij, żeby odpowiedzieć – kilka słów wystarczy")
                    Text(polish: "co tydzień czeka tu nowe pytanie")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                }
            }
            if !past.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("poprzednie tygodnie").sectionTitle()
                        ForEach(shownPast) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("tydzień od \(InnerFormat.date(entry.week, today: store.today))")
                                    .font(.caption)
                                    .foregroundStyle(Palette.muted)
                                Text(polish: entry.reflection.question)
                                    .font(.footnote.italic())
                                    .foregroundStyle(Palette.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                                answerField(week: entry.week, answer: entry.reflection.answer, emptyLine: "")
                            }
                        }
                        if past.count > shownPast.count {
                            Button("pokaż wszystkie (\(past.count))") {
                                showsAll = true
                            }
                            .buttonStyle(LinkButtonStyle())
                        }
                    }
                }
            }
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
