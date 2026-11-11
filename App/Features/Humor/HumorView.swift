import SwiftUI
import AboutHerCore

/// "humor", opened from "ja": her own collection of jokes and funny quotes to come back to when
/// she needs a smile.
///
/// - "losuj coś na poprawę humoru" shows one at random – her favourites more often, never the
///   same one twice in a row (`AppData.randomHumor`).
/// - "Twoja kolekcja" is one calm card: "dodaj" opens a new one in place at its top; it saves
///   itself when the keyboard goes.
/// - Each one is a row: a tap corrects it, a swipe to the left deletes it, the star marks a
///   favourite.
struct HumorView: View {
    @Environment(AppStore.self) private var store
    /// The one "losuj" drew last; nil until she draws.
    @State private var drawnID: UUID? = nil
    /// The id of the new one she is writing; nil while she isn't.
    @State private var newID: UUID? = nil
    /// The one open for correcting.
    @State private var editingID: UUID? = nil
    @State private var showsAll = false
    /// "zapisałam" under the heading, for a moment after a new one is saved.
    @State private var isConfirming = false
    /// Counts what she saved, for a light haptic each time and to end the right "zapisałam".
    @State private var saves = 0

    /// How many are shown before "pokaż wszystkie".
    private static let firstCount = 20

    var body: some View {
        let items = store.data.humorNewestFirst
        // A new one saved in the background while she still writes shows only in its own editor.
        let listed = items.filter { $0.id != newID }
        let shown = showsAll ? listed : Array(listed.prefix(Self.firstCount))
        Screen {
            ScreenHeader(title: "humor", subtitle: "to, co Cię bawi, zawsze pod ręką")
            if items.isEmpty && newID == nil {
                Card(style: .highlight) {
                    EmptyState(title: "tu zbierzesz to, co Cię bawi",
                               message: "żarty i cytaty, do których zechcesz wracać",
                               actionTitle: "dodaj pierwszy",
                               action: startAdding)
                }
            } else {
                if !items.isEmpty {
                    HumorDrawCard(item: items.first(where: { $0.id == drawnID }),
                                  onDraw: draw,
                                  onToggleFavorite: toggleFavorite)
                }
                collectionCard(shown: shown, total: listed.count)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "Twoja kolekcja": the way to add one, the new one being written, then hers, newest first.
    private func collectionCard(shown: [HumorItem], total: Int) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("Twoja kolekcja") {
                    // Resting while a new one is already open below.
                    StarActionButton("dodaj", size: .regular, isEnabled: newID == nil, action: startAdding)
                        .accessibilityLabel(Text("dodaj żart albo cytat"))
                }
                if isConfirming {
                    ConfirmationNote(text: "zapisałam")
                }
                VStack(alignment: .leading, spacing: 0) {
                    if let newID {
                        HumorEditor(itemID: newID, original: nil) { saved in
                            closeNew(newID, saved: saved)
                        }
                        .transition(.opacity)
                        if !shown.isEmpty {
                            RowDivider()
                        }
                    }
                    ForEach(shown) { item in
                        if item.id != shown.first?.id {
                            RowDivider()
                        }
                        row(item)
                    }
                }
                if total > shown.count {
                    Button("pokaż wszystkie (\(total))") {
                        withAnimation(.smooth) {
                            showsAll = true
                        }
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: saves)
    }

    @ViewBuilder
    private func row(_ item: HumorItem) -> some View {
        if editingID == item.id {
            HumorEditor(itemID: item.id, original: item) { saved in
                // Another one may already be open in its place.
                if editingID == item.id {
                    withAnimation(.smooth) {
                        editingID = nil
                    }
                }
                if saved {
                    saves &+= 1
                }
            }
        } else {
            HumorRow(item: item) {
                toggleFavorite(item.id)
            }
            .swipeToDelete(label: "usuń", onTap: { startEditing(item.id) }) {
                remove(item.id)
            }
        }
    }

    // MARK: - Actions

    private func draw() {
        let next = store.data.randomHumor(after: drawnID)
        withAnimation(.smooth) {
            drawnID = next?.id
        }
    }

    /// Opens a new one at the top of her collection – unless her data can't be changed right now
    /// (the store tells her why).
    private func startAdding() {
        guard newID == nil, store.acceptsHumorChanges() else { return }
        withAnimation(.smooth) {
            editingID = nil
            isConfirming = false
            newID = UUID()
        }
    }

    private func startEditing(_ id: UUID) {
        guard store.acceptsHumorChanges() else { return }
        withAnimation(.smooth) {
            newID = nil
            editingID = id
        }
    }

    private func closeNew(_ id: UUID, saved: Bool) {
        if newID == id {
            withAnimation(.smooth) {
                newID = nil
            }
        }
        guard saved else { return }
        saves &+= 1
        let turn = saves
        withAnimation(.smooth) {
            isConfirming = true
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard saves == turn else { return }
            withAnimation(.smooth) {
                isConfirming = false
            }
        }
    }

    private func toggleFavorite(_ id: UUID) {
        _ = store.toggleHumorFavorite(id)
    }

    private func remove(_ id: UUID) {
        withAnimation(.smooth) {
            store.removeHumor(id)
        }
    }
}

/// The card the screen is about: one of her jokes or quotes drawn at random – or, before she
/// draws, a quiet invitation – and the big star that draws.
private struct HumorDrawCard: View {
    /// The one drawn last; nil before she draws (or once it was deleted).
    let item: HumorItem?
    let onDraw: () -> Void
    let onToggleFavorite: (UUID) -> Void

    var body: some View {
        Card(style: .highlight) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                if let item {
                    HStack(alignment: .top, spacing: Spacing.tight) {
                        HumorQuoteText(item: item, size: 22, detail: HumorFormat.attribution(item))
                            .accessibilityElement(children: .combine)
                        HumorFavoriteButton(isOn: item.isFavorite) {
                            onToggleFavorite(item.id)
                        }
                        // Level with the first line; its 44 pt reach into the card's margin.
                        .padding(.top, -10)
                        .padding(.trailing, -12)
                    }
                    .id(item.id)
                    .transition(.opacity)
                } else {
                    VStack(spacing: Spacing.tight) {
                        StarCluster()
                        Text(polish: "potrzebujesz uśmiechu?")
                            .displayFont(20, italic: true, relativeTo: .title3)
                            .foregroundStyle(Palette.text)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                }
                StarActionButton(item == nil ? "losuj coś na poprawę humoru" : "losuj coś innego", action: onDraw)
            }
        }
    }
}
