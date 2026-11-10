import SwiftUI
import AboutHerCore

/// "Twój etap": the three stages of her plan as a short path – hers with what it means, the others
/// on tap. Once she has made movement a habit, the offer of the next stage shows here; the stage
/// goes up only when she says yes. She can go back to an easier stage at any time.
struct MovementStageCard: View {
    @Environment(AppStore.self) private var store
    /// Another stage she opened to read about.
    @State private var openStage: Int? = nil
    /// A warm line after she answered the offer or went back a stage.
    @State private var note: String? = nil

    var body: some View {
        let stage = store.data.training.stage
        let offer = store.trainingStageOffer
        // Quiet while there is nothing to answer.
        Card(style: offer == nil ? CardStyle.quiet : CardStyle.standard) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("Twój etap")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(TrainingProgress.stages, id: \.self) { number in
                        if number == stage {
                            currentStage(number)
                        } else {
                            otherStage(number, current: stage)
                        }
                    }
                }
                if let offer {
                    offerQuestion(offer)
                }
                if let note {
                    ConfirmationNote(text: note)
                }
            }
        }
        .onDisappear {
            openStage = nil
            note = nil
        }
    }

    // MARK: - Parts

    private func currentStage(_ number: Int) -> some View {
        HStack(alignment: .top, spacing: Spacing.item) {
            StageStar(place: .current)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(verbatim: "etap \(number) · \(MovementFormat.stageName(number))")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(polish: MovementFormat.stageDetail(number))
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSelected)
    }

    /// A stage behind or ahead of hers: one line, its details on tap.
    private func otherStage(_ number: Int, current: Int) -> some View {
        let isOpen = openStage == number
        let isBehind = number < current
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    openStage = isOpen ? nil : number
                }
            } label: {
                HStack(spacing: Spacing.item) {
                    StageStar(place: isBehind ? .behind : .ahead)
                    Text(verbatim: "etap \(number) · \(MovementFormat.stageName(number))")
                        .font(.body)
                        .foregroundStyle(Palette.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: TapSize.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isOpen ? "rozwinięte" : "zwinięte"))
            if isOpen {
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(polish: MovementFormat.stageDetail(number))
                        .font(.subheadline)
                        .foregroundStyle(Palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    if isBehind {
                        Button {
                            goBack(to: number)
                        } label: {
                            Text(verbatim: "wróć do etapu \(number)")
                        }
                        .buttonStyle(LinkButtonStyle())
                    } else {
                        Text(polish: "zapytam Cię o niego, gdy obecny etap będziesz mieć oswojony")
                            .hintText()
                    }
                }
                .padding(.leading, StageStar.size + Spacing.item)
                .padding(.bottom, Spacing.item)
                .transition(.opacity)
            }
        }
    }

    /// "ruszasz się regularnie – chcesz spróbować etapu 2?" with a yes and a "not yet".
    private func offerQuestion(_ offer: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text(polish: "ruszasz się regularnie – chcesz spróbować etapu \(offer)?")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(polish: "\(MovementFormat.stageDetail(offer)). Zostać przy obecnym to też dobry wybór")
                .bodyText()
            HStack(spacing: Spacing.group) {
                StarActionButton("tak, spróbuję", size: .regular) {
                    answer(accepted: true, offer: offer)
                }
                Button("jeszcze nie") {
                    answer(accepted: false, offer: offer)
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
    }

    // MARK: - Changes

    private func answer(accepted: Bool, offer: Int) {
        let isSaved = withAnimation(.smooth) {
            store.answerStageOffer(accepted: accepted)
        }
        guard isSaved else { return }
        withAnimation(.smooth) {
            openStage = nil
            note = accepted
                ? "etap \(offer) – zaczynamy spokojnie, w Twoim tempie"
                : "dobrze – zapytam znowu za jakiś czas"
        }
    }

    private func goBack(to number: Int) {
        let isSaved = withAnimation(.smooth) {
            store.setTrainingStage(number)
        }
        guard isSaved else { return }
        withAnimation(.smooth) {
            openStage = nil
            note = "dobrze – wracamy do etapu \(number), bez pośpiechu"
        }
    }
}

/// A stage on the path: filled for hers, softly filled behind her, outlined ahead.
private struct StageStar: View {
    enum Place {
        case current, behind, ahead
    }

    static let size: CGFloat = 16

    let place: Place

    var body: some View {
        ZStack {
            OrganicStar()
                .fill(fill)
            OrganicStar()
                .stroke(place == .ahead ? Palette.accentDim.opacity(0.6) : fill, lineWidth: 1.2)
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch place {
        case .current: Palette.accent
        case .behind: Palette.accentDim.opacity(0.7)
        case .ahead: Color.clear
        }
    }
}
