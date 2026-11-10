import SwiftUI
import AboutHerCore

/// "medytacja": her mood with one tap, and a meditation for it and the part of the day, which the
/// star opens on YouTube (in the app when it is installed, otherwise in Safari).
struct MomentMeditationCard: View {
    @Environment(\.openURL) private var openURL
    let time: MeditationTime
    let mood: MoodLevel?
    /// The mood is the one she marked for today on "dziś".
    let isMoodFromToday: Bool
    let onPickMood: (MoodLevel) -> Void

    var body: some View {
        let meditation = MeditationGuide.meditation(for: time, mood: mood)
        let flow = FlowLayout(spacing: 6, lineSpacing: 6)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("medytacja").sectionTitle()
                Text(polish: introLine)
                    .bodyText()
                VStack(alignment: .leading, spacing: 4) {
                    Text("jaki masz teraz nastrój?")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.muted)
                    flow {
                        ForEach(MoodLevel.allCases, id: \.self) { level in
                            MomentMoodChoice(label: Self.label(of: level), isSelected: level == mood) {
                                onPickMood(level)
                            }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: mood)
                }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meditation.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("otwórz na YouTube")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        open(meditation)
                    }
                    StarButton(label: "otwórz medytację", size: 21, prominent: true,
                               isEnabled: meditation.url != nil, action: { open(meditation) })
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The part of the day, and what the meditation is picked for.
    private var introLine: String {
        let part: String
        switch time {
        case .morning: part = "na dobry początek dnia"
        case .day: part = "na chwilę oddechu w środku dnia"
        case .evening: part = "na wyciszenie przed snem"
        }
        guard mood != nil else {
            return part + ". Powiedz mi, jaki masz nastrój, a dobiorę do niego medytację"
        }
        return part + (isMoodFromToday ? " · dobrana do nastroju, który zaznaczyłaś dziś" : " · dobrana do Twojego nastroju")
    }

    private func open(_ meditation: Meditation) {
        guard let url = meditation.url else { return }
        openURL(url)
    }

    /// The names of the moods, as on "dziś".
    private static func label(of mood: MoodLevel) -> String {
        switch mood {
        case .veryGood: "bardzo dobry"
        case .good: "dobry"
        case .neutral: "średni"
        case .low: "obniżony"
        case .veryLow: "niski"
        }
    }
}

/// One mood to tap: a small star that fills when it is the chosen one.
private struct MomentMoodChoice: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                OrganicStar()
                    .fill(isSelected ? Palette.accent : Palette.accentDim.opacity(0.35))
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Palette.accent : Palette.text2)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                Capsule().fill(isSelected ? Palette.accentBackground : Color.clear)
            }
            .overlay {
                Capsule().strokeBorder(isSelected ? Palette.accent.opacity(0.35) : Palette.line, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "intencja": a few words to take into the meditation, picked for her mood. The star offers
/// another; she can also write her own, which is kept in "Twoje zapiski" with the date.
struct MomentIntentionCard: View {
    let intention: String
    let onSwap: () -> Void
    @State private var isWriting = false
    /// She has just written her own; shown until she asks for another.
    @State private var hasSaved = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("intencja").sectionTitle()
                    Spacer()
                    if !isWriting {
                        StarButton(label: "inna intencja", action: offerAnother)
                    }
                }
                Text(polish: intention)
                    .displayFont(22, italic: true, relativeTo: .title3)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: intention)
                Text(polish: "weź ją ze sobą do medytacji albo do oddechu. Gwiazdka podsunie Ci inną")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if isWriting {
                    MomentNoteField(target: .new(kind: .intention, prompt: ""),
                                    placeholder: "np. dziś idę swoim tempem",
                                    hint: "napisz ją po swojemu – zapiszę, gdy schowasz klawiaturę",
                                    onClose: { saved in
                                        isWriting = false
                                        hasSaved = saved
                                    })
                } else {
                    if hasSaved {
                        Text(polish: "zapisałam ją w Twoich zapiskach, na dole")
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                    }
                    Button("napisz własną intencję") {
                        hasSaved = false
                        isWriting = true
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func offerAnother() {
        hasSaved = false
        onSwap()
    }
}
