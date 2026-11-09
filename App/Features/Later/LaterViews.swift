import SwiftUI

/// Placeholder card for tabs that are being moved over from the web version.
struct ComingSoonCard: View {
    let intro: String
    let items: [String]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("w budowie").sectionTitle()
                Text(polish: intro).bodyText()
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        OrganicStar()
                            .fill(Palette.accentDim)
                            .frame(width: 9, height: 9)
                            .padding(.top, 5)
                            .accessibilityHidden(true)
                        Text(polish: item).bodyText()
                    }
                }
            }
        }
    }
}

struct MovementView: View {
    var body: some View {
        Screen {
            Text("ruch").screenTitle()
            ComingSoonCard(
                intro: "tu wróci trening dopasowany do Ciebie:",
                items: [
                    "propozycja na dziś według fazy i Twojej energii",
                    "etapy 1–3 – poprzeczka idzie w górę tylko za Twoją zgodą",
                    "kroki z iPhone’a i seria tygodniowa zamiast „dni pod rząd”"
                ]
            )
        }
    }
}
