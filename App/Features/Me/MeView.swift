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
                    Text("w starej wersji wejdź w ustawienia i dotknij „zapisz kopię”. Wybierz ten plik tutaj, a przeniosę zaznaczone dni okresu. Niczego nie nadpiszę.")
                        .bodyText()
                    Button("wybierz plik kopii") {
                        isImporting = true
                    }
                    .buttonStyle(LinkButtonStyle())
                    if let importMessage {
                        Text(importMessage)
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
            ComingSoonCard(
                intro: "tu wróci wszystko, co w wersji HTML było w zakładce „wnętrze”:",
                items: [
                    "intencja na dziś, małe zwycięstwa i manifest „kim się stajesz”",
                    "chwila dla siebie: oddech z haptyką i medytacje",
                    "list do siebie za 3 miesiące, refleksja tygodniowa i zdjęcia",
                    "ustawienia, blokada Face ID i kopie zapasowe"
                ]
            )
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let raw = try Data(contentsOf: url)
                let days = try LegacyImport.periodDays(fromHTMLExport: raw)
                let added = store.importPeriodDays(days)
                importMessage = added == 0
                    ? "nie znalazłam nowych dni okresu – wszystko już tu jest"
                    : "gotowe – dodałam \(PolishPlural.days(added)) okresu"
            } catch {
                importMessage = "to nie wygląda na kopię z wersji HTML"
            }
        case .failure:
            importMessage = "nie udało mi się otworzyć tego pliku"
        }
    }
}
