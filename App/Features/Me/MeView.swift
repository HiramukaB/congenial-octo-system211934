import SwiftUI
import AboutHerCore

/// "ja": her own part of the app – a calm list of the places it opens and the app version.
/// The places she visits for herself share one card; "ustawienia" sits apart, quieter, below.
struct MeView: View {
    @Environment(AppStore.self) private var store
    /// Dividers start under the names, past the round icons (40 pt icon + 12 pt gap).
    @ScaledMetric(relativeTo: .body) private var dividerInset: CGFloat = 52

    var body: some View {
        NavigationStack {
            Screen {
                ScreenHeader(title: "ja", subtitle: "miejsce tylko dla Ciebie, w Twoim tempie")
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        MeLink(title: "wnętrze", detail: "intencja, zwycięstwa, refleksja", symbol: "heart") {
                            InnerView()
                        }
                        divider
                        MeLink(title: "chwila dla siebie", detail: "medytacja, oddech, pytanie", symbol: "leaf") {
                            MomentView()
                        }
                        divider
                        // Slot: owner F builds "humor". An outlined symbol, like the others.
                        MeLink(title: "humor", detail: "żarty i cytaty, które Cię bawią", symbol: "quote.bubble") {
                            HumorView()
                        }
                        divider
                        MeLink(title: "list do siebie", detail: letterDetail, symbol: "envelope") {
                            LetterView()
                        }
                        divider
                        MeLink(title: "zdjęcia", detail: "tylko w aplikacji, nie w galerii", symbol: "photo") {
                            PhotosView()
                        }
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, Spacing.hairline)
                }
                Card(padding: 0, style: .quiet) {
                    // One line, like the places above.
                    MeLink(title: "ustawienia", detail: "przypomnienia i blokada", symbol: "gearshape") {
                        SettingsView()
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, Spacing.hairline)
                }
                Text("about her · wersja \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.tight)
            }
            // The tab keeps its own big title; the bar shows only on the screens it opens,
            // with a way back to "ja".
            .navigationTitle("ja")
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var divider: some View {
        RowDivider()
            .padding(.leading, dividerInset)
    }

    /// A letter that opened today first; otherwise when the next sealed one opens.
    private var letterDetail: String {
        let today = store.today
        if store.data.openLetters(on: today).contains(where: { $0.opensOn == today }) {
            return "dziś otworzył się Twój list"
        }
        if let next = store.data.sealedLetters(on: today).first {
            return "otworzysz go \(InnerFormat.date(next.opensOn, today: today))"
        }
        return "napisz do przyszłej siebie"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

/// One place "ja" opens: a round icon, its name, a line about what is inside and a chevron.
/// VoiceOver reads the name first, then the line (the UI tests look for the names).
struct MeLink<Destination: View>: View {
    let title: String
    let detail: String
    /// An SF Symbol for the place.
    let symbol: String
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            MePlaceRow(title: title, detail: detail, symbol: symbol)
        }
        .buttonStyle(MePlacePressStyle())
        .accessibilityLabel(Text("\(title), \(detail)"))
    }
}

/// The look of a place to open: a soft round icon, a serif name, one short line and a chevron.
/// At least 56 pt tall. `MeLink` wraps it in a link; "ustawienia" uses it for "samouczek".
struct MePlaceRow: View {
    private let title: String
    private let detail: String
    private let symbol: String
    /// The icon's circle; it grows with the text size.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 40

    init(title: String, detail: String, symbol: String) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: Spacing.item) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(Palette.accent)
                .frame(width: iconSize, height: iconSize)
                .background {
                    Circle()
                        .fill(Palette.accentBackground)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Palette.accent.opacity(0.18), lineWidth: 1)
                }
                .accessibilityHidden(true)
            // The words take all the room up to the chevron, so the short line stays on one line.
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .displayFont(19, weight: .medium, relativeTo: .body)
                    .foregroundStyle(Palette.text)
                Text(polish: detail)
                    .rowDetail()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.item)
        .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A soft glow behind a place while it is pressed, a little wider than the row.
struct MePlacePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.06 : 0))
                    .padding(.horizontal, -Spacing.item)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
