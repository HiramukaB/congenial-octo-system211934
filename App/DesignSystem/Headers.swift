import SwiftUI

/// The top of a screen: its serif title and, when it helps, one short line under it.
/// The first thing inside `Screen`; it leaves a little extra room before the first card.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text(title)
                .screenTitle()
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(polish: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.hairline)
    }
}

/// The heading of a card: a lowercase serif title, an optional short line under it, and an
/// optional accessory on the right (a `StarButton`, a count, a link). The accessory's 44 pt tap
/// area never makes the header taller than its title, so every card starts the same way.
///
///     SectionHeader("woda")
///     SectionHeader("co zjadłaś") {
///         StarButton(label: "dopisz posiłek", prominent: true, action: add)
///     }
struct SectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(title)
                    .sectionTitle()
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(polish: subtitle)
                        .hintText()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .padding(.leading, Spacing.item)
                // A 44 pt button keeps its tap area but takes only the title's height.
                .padding(.vertical, -10)
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) {
            EmptyView()
        }
    }
}
