import SwiftUI
import AboutHerCore

/// "ruch": today's suggestion by her stage, the cycle phase and the energy she marked today, the
/// movement she logged this week, and the stage of her plan – raised only when she says yes.
struct MovementView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let today = store.today
        Screen(tint: store.cycle.phase(on: today, today: today)?.phase.tint) {
            Text("ruch").screenTitle()
            if let offer = store.trainingStageOffer {
                MovementOfferCard(stage: offer)
            }
            MovementSuggestionCard(suggestion: store.movementSuggestion)
            WorkoutLogCard()
            MovementStageCard()
            Text(polish: store.isMovementWeightAssumed
                 ? "kcal z ruchu to szacunek. Liczę je dla wagi 65 kg, dopóki nie zapiszesz swojej w zakładce jedzenie"
                 : "kcal z ruchu to szacunek, nie dokładny pomiar")
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

/// "na dziś": what to do, for how long and why, the video to follow, and a star to log it as done.
struct MovementSuggestionCard: View {
    @Environment(AppStore.self) private var store
    let suggestion: MovementSuggestion

    var body: some View {
        let today = store.today
        let isDone = store.data.workouts(on: today).contains { $0.kind == suggestion.kind }
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("na dziś").sectionTitle()
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(suggestion.title) · \(MovementFormat.minutes(suggestion.minutes))")
                        .font(.headline)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(polish: suggestion.detail)
                        .bodyText()
                }
                MovementVideoTile(video: suggestion.video)
                if isDone {
                    HStack(spacing: 10) {
                        OrganicStar()
                            .fill(Palette.accent)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        Text(polish: "zapisałam – dziękuję, że znalazłaś dziś chwilę dla siebie")
                            .font(.footnote)
                            .foregroundStyle(Palette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: 44)
                } else {
                    HStack(spacing: 4) {
                        StarButton(label: "zrobione – zapisz: \(suggestion.kind.label), \(suggestion.loggedMinutes) min",
                                   size: 21,
                                   prominent: true,
                                   action: logSuggestion)
                        Text(polish: "zrobione? Dotknij gwiazdki, a zapiszę: \(suggestion.kind.label) · \(suggestion.loggedMinutes) min")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func logSuggestion() {
        withAnimation(.smooth) {
            _ = store.logWorkout(suggestion.kind, minutes: suggestion.loggedMinutes, on: store.today)
        }
    }
}

/// The video for today's suggestion; it opens in YouTube, or in Safari without the app.
struct MovementVideoTile: View {
    let video: MovementVideo

    var body: some View {
        if let url = URL(string: video.url) {
            Link(destination: url) {
                HStack(spacing: 12) {
                    OrganicStar()
                        .fill(Palette.accent)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.label)
                            .font(.subheadline)
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("otwórz na YouTube")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.accentBackground.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("otwiera film na YouTube")
        }
    }
}

/// The offer to move up a stage: asked once she has made movement a habit, raised only on yes.
struct MovementOfferCard: View {
    @Environment(AppStore.self) private var store
    let stage: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    OrganicStar()
                        .fill(Palette.accent)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    Text("chcesz spróbować etapu \(stage)?")
                        .sectionTitle()
                }
                Text(polish: "w ostatnich tygodniach ruszałaś się regularnie – widzę, że obecny etap masz już oswojony. Etap \(stage), \(MovementFormat.stageName(stage)): \(MovementFormat.stageDetail(stage))")
                    .bodyText()
                Text(polish: "jeśli wolisz zostać tam, gdzie jesteś, to też dobry wybór – zapytam znowu za jakiś czas")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 24) {
                    Button("tak, spróbuję") { answer(accepted: true) }
                        .buttonStyle(LinkButtonStyle())
                    Button("jeszcze nie") { answer(accepted: false) }
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func answer(accepted: Bool) {
        withAnimation(.smooth) {
            _ = store.answerStageOffer(accepted: accepted)
        }
    }
}

/// "Twój etap": where she is in her plan. She can go back a stage at any time; it goes up only
/// when she says yes to the offer.
struct MovementStageCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let stage = store.data.training.stage
        let stages = TrainingProgress.stages
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Twój etap").sectionTitle()
                ForEach(stages, id: \.self) { number in
                    stageRow(number, current: stage)
                }
                if stage < stages.upperBound {
                    Text(polish: "zapytam Cię o kolejny etap, gdy zobaczę, że obecny masz już oswojony. Nigdy nie podniosę poprzeczki bez Twojej zgody")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if stage > stages.lowerBound {
                    Button {
                        withAnimation(.smooth) {
                            _ = store.setTrainingStage(stage - 1)
                        }
                    } label: {
                        Text(verbatim: "wróć do etapu \(stage - 1)")
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func stageRow(_ number: Int, current: Int) -> some View {
        let isCurrent = number == current
        return HStack(alignment: .top, spacing: 12) {
            OrganicStar()
                .fill(isCurrent ? Palette.accent : (number < current ? Palette.accentDim : Palette.line))
                .frame(width: 14, height: 14)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "etap \(number) · \(MovementFormat.stageName(number))")
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Palette.text : Palette.text2)
                Text(polish: MovementFormat.stageDetail(number))
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
