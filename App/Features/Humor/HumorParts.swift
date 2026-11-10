import SwiftUI
import AboutHerCore

extension HumorItem.Kind {
    /// The tile in the editor: "żart", "cytat", "inne".
    nonisolated var label: String {
        switch self {
        case .joke: "żart"
        case .quote: "cytat"
        case .other: "inne"
        }
    }
}

/// How her jokes and quotes are described in the app.
nonisolated enum HumorFormat {
    /// The small line under one in her collection: "cytat · Ola", "żart"; for "inne" only where it
    /// comes from, when she said.
    static func detail(_ item: HumorItem) -> String? {
        switch item.kind {
        case .joke, .quote:
            guard let source = item.source else { return item.kind.label }
            return "\(item.kind.label) · \(source)"
        case .other:
            return item.source
        }
    }

    /// Under one shown on its own: "– Ola"; nil when she didn't say who.
    static func attribution(_ item: HumorItem) -> String? {
        item.source.map { "– \($0)" }
    }

    /// What VoiceOver reads for one: her words, then the small line.
    static func spoken(_ item: HumorItem, detail: String?) -> String {
        guard let detail else { return item.text }
        return "\(item.text). \(detail)"
    }
}

/// One joke or quote as she reads it: her words in serif italic and a small line under them.
struct HumorQuoteText: View {
    let item: HumorItem
    /// The size of her words; it grows with the text size.
    var size: CGFloat = 18
    /// The line under them, e.g. "cytat · Ola" or "– Ola".
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(polish: item.text)
                .displayFont(size, italic: true, relativeTo: .body)
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .rowDetail()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The star that marks a favourite: filled when it is one, outlined when not. 44 pt to tap.
struct HumorFavoriteButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                OrganicStar()
                    .fill(isOn ? Palette.accent : Color.clear)
                OrganicStar()
                    .stroke(isOn ? Palette.accent : Palette.accentDim.opacity(0.7), lineWidth: 1.3)
            }
            .frame(width: 20, height: 20)
            .frame(width: TapSize.minimum, height: TapSize.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(StarPressStyle())
        .animation(.snappy(duration: 0.2), value: isOn)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(Text("ulubiony"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// One joke or quote in her collection, as its own card: her words, what it is and who said it,
/// and the favourite star in the corner. The screen adds "tap to correct, swipe left to delete".
struct HumorItemCard: View {
    let item: HumorItem
    let onToggleFavorite: () -> Void

    var body: some View {
        let detail = HumorFormat.detail(item)
        Card {
            HStack(alignment: .top, spacing: Spacing.tight) {
                HumorQuoteText(item: item, detail: detail)
                HumorFavoriteButton(isOn: item.isFavorite, action: onToggleFavorite)
                    // The star sits beside the first line; its 44 pt reach into the card's margin.
                    .padding(.top, -12)
                    .padding(.trailing, -12)
            }
        }
        // One element for VoiceOver; the star is one of its actions.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(HumorFormat.spoken(item, detail: detail)))
        .accessibilityValue(Text(item.isFavorite ? "ulubiony" : ""))
        .accessibilityAction(named: Text(item.isFavorite ? "usuń z ulubionych" : "dodaj do ulubionych")) {
            onToggleFavorite()
        }
    }
}
