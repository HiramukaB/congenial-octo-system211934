import SwiftUI

/// "ja": her inner part of the app. A short header, then the places it opens – "wnętrze",
/// "chwila dla siebie", "list do siebie", "zdjęcia" and "ustawienia" – and the app version.
struct MeView: View {
    var body: some View {
        NavigationStack {
            Screen {
                Text("ja").screenTitle()
                Text(polish: "miejsce tylko dla Ciebie, w Twoim tempie")
                    .bodyText()
                MeLink(title: "wnętrze",
                       detail: "małe zwycięstwa, kim się stajesz i refleksja tygodnia") {
                    InnerView()
                }
                MeLink(title: "chwila dla siebie",
                       detail: "medytacja, oddech i pytanie do przemyślenia") {
                    MomentView()
                }
                MeLink(title: "list do siebie",
                       detail: "napiszesz dziś, przeczytasz w dniu, który wybierzesz") {
                    LetterView()
                }
                MeLink(title: "zdjęcia",
                       detail: "tylko w aplikacji, nie w Twojej galerii") {
                    PhotosView()
                }
                MeLink(title: "ustawienia",
                       detail: "przypomnienia i blokada Face ID") {
                    SettingsView()
                }
                Text("about her · wersja \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            // The tab keeps its own big title; the bar shows only on the screens it opens,
            // with a way back to "ja".
            .navigationTitle("ja")
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

/// One place "ja" opens: a card with a star, a lowercase title and a line about what is inside.
struct MeLink<Destination: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            Card {
                HStack(spacing: 12) {
                    OrganicStar()
                        .fill(Palette.accentDim)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).sectionTitle()
                        Text(polish: detail)
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
