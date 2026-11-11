import SwiftUI
import AboutHerCore

/// "ruch": one suggestion for today, her movement this week and in the last few days, and the
/// stage of her plan – raised only when she says yes.
struct MovementView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let today = store.today
        Screen(tint: store.cycle.phase(on: today, today: today)?.phase.tint) {
            ScreenHeader(title: "ruch")
            MovementSuggestionCard(suggestion: store.movementSuggestion)
            WorkoutLogCard()
            MovementStageCard()
        }
    }
}

/// "na dziś", the card the screen is about: what to do and for how long – by her stage, the phase
/// and the energy she marked today – the video to follow, and "zrobione" to log it.
struct MovementSuggestionCard: View {
    @Environment(AppStore.self) private var store
    let suggestion: MovementSuggestion

    var body: some View {
        let isDone = store.data.workouts(on: store.today).contains { $0.kind == suggestion.kind }
        Card(style: .highlight) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("na dziś") {
                    Text(MovementFormat.minutes(suggestion.minutes))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.text2)
                }
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(polish: suggestion.title)
                        .displayFont(24, weight: .medium, relativeTo: .title2)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(polish: suggestion.detail)
                        .bodyText()
                }
                MovementVideoTile(video: suggestion.video)
                if isDone {
                    // As tall as the button it replaces, so the card doesn't jump.
                    ConfirmationNote(text: "zapisałam – dziękuję, że znalazłaś dziś chwilę dla siebie")
                        .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
                } else {
                    StarActionButton("zrobione", action: logSuggestion)
                        .accessibilityHint(Text(verbatim: "zapiszę: \(suggestion.kind.label), \(MovementFormat.spokenMinutes(suggestion.loggedMinutes))"))
                }
            }
        }
    }

    /// Logs the shorter end of the suggestion; she can correct it in "Twój ruch".
    private func logSuggestion() {
        withAnimation(.smooth) {
            _ = store.logWorkout(suggestion.kind, minutes: suggestion.loggedMinutes, on: store.today)
        }
    }
}

/// The video for today's suggestion as a calm tile; it opens in YouTube, or in Safari without the app.
struct MovementVideoTile: View {
    let video: MovementVideo

    var body: some View {
        if let url = URL(string: video.url) {
            let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
            Link(destination: url) {
                HStack(spacing: Spacing.item) {
                    Image(systemName: "play.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 36, height: 36)
                        .background(Palette.accent.opacity(0.14), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .rowTitle()
                            .fixedSize(horizontal: false, vertical: true)
                        Text(video.source)
                            .rowDetail()
                    }
                    Spacer(minLength: Spacing.tight)
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.item)
                .padding(.vertical, Spacing.tight)
                .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
                .background(Color.white.opacity(0.04), in: shape)
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                }
                .contentShape(shape)
            }
            .buttonStyle(TilePressStyle())
            .accessibilityHint(Text("otwiera film na YouTube"))
        }
    }
}
