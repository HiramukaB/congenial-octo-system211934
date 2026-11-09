import SwiftUI

/// "ja": the inner part of the app – intention, small wins, reflection, letters, meditation.
/// Being built; for now it shows what is coming and the app version.
struct MeView: View {
    var body: some View {
        Screen {
            Text("ja").screenTitle()
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
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
