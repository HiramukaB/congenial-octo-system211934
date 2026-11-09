import SwiftUI
import UniformTypeIdentifiers
import AboutHerCore

/// "ja": the inner part of the app. For now: moving the period history over from the web version.
struct MeView: View {
    @Environment(AppStore.self) private var store
    @State private var isImporting = false
    @State private var importMessage: String?

    var body: some View {
        Screen {
            Text("ja").screenTitle()
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("przenieś dane z wersji HTML").sectionTitle()
                    Text(polish: "w starej wersji wejdź w ustawienia i dotknij „zapisz kopię”. Wybierz ten plik tutaj, a przeniosę zaznaczone dni okresu. Niczego nie nadpiszę")
                        .bodyText()
                    Button("wybierz plik kopii") {
                        isImporting = true
                    }
                    .buttonStyle(LinkButtonStyle())
                    if let importMessage {
                        Text(polish: importMessage)
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
            ComingSoonCard(
                intro: "tu wróci to, co w wersji HTML było w zakładce „wnętrze” i w ustawieniach, a do tego kilka nowości:",
                items: [
                    "intencja na dziś, małe zwycięstwa i manifest „kim się stajesz”",
                    "chwila dla siebie: oddech z haptyką i medytacje",
                    "list do siebie za 3 miesiące, refleksja tygodniowa i zdjęcia",
                    "ustawienia, blokada Face ID i kopie zapasowe"
                ]
            )
            Text("about her · wersja \(appVersion)")
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            let raw: Data
            do {
                raw = try Data(contentsOf: url)
            } catch {
                importMessage = "nie udało mi się otworzyć tego pliku"
                return
            }
            let days: Set<LocalDate>
            do {
                days = try LegacyImport.periodDays(fromHTMLExport: raw)
            } catch {
                importMessage = "to nie wygląda na kopię z wersji HTML"
                return
            }
            // nil: the store can't take changes right now and has already said why.
            guard let added = store.importPeriodDays(days) else {
                importMessage = nil
                return
            }
            importMessage = added == 0
                ? "nie znalazłam nowych dni okresu – wszystko już tu jest"
                : "gotowe – dodałam \(PolishPlural.days(added)) okresu"
        case .failure:
            importMessage = "nie udało mi się otworzyć tego pliku"
        }
    }
}
