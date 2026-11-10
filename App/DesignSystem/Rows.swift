import SwiftUI

/// A compact row of a list inside a card: her words as the title, a small line under them
/// (a date, a source, "ok. 114 kcal") and an optional accessory on the right. At least 44 pt tall.
///
/// For her rule "swipe left to delete, tap to edit", put the row's own `swipeToDelete` on it,
/// and `RowDivider()` between rows:
///
///     ListRow(item.text, detail: "dziś") {
///         Text("ok. 114 kcal").rowDetail()
///     }
///     .swipeToDelete(label: "usuń", onTap: { edit(item) }) { remove(item) }
struct ListRow<Trailing: View>: View {
    private let title: String
    private let detail: String?
    private let trailing: Trailing

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .rowTitle()
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .rowDetail()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .padding(.leading, Spacing.item)
        }
        .padding(.vertical, Spacing.tight + 2)
        .frame(minHeight: TapSize.minimum)
        .accessibilityElement(children: .combine)
    }
}

extension ListRow where Trailing == EmptyView {
    init(_ title: String, detail: String? = nil) {
        self.init(title, detail: detail) {
            EmptyView()
        }
    }
}

/// A hairline between the rows of a list.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
