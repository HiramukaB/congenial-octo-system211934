import SwiftUI
import AboutHerCore

/// Names, colours and gentle hints for each phase – the "inner seasons".
extension CyclePhase {
    var label: String {
        switch self {
        case .menstrual: "okres"
        case .follicular: "folikularna"
        case .ovulatory: "owulacja"
        case .luteal: "lutealna"
        }
    }

    var season: String {
        switch self {
        case .menstrual: "zima"
        case .follicular: "wiosna"
        case .ovulatory: "lato"
        case .luteal: "jesień"
        }
    }

    var tint: Color {
        switch self {
        case .menstrual: Color(hex: 0xB07080)
        case .follicular: Color(hex: 0xA8B5A0)
        case .ovulatory: Color(hex: 0xE3CFA0)
        case .luteal: Color(hex: 0xC9A27E)
        }
    }

    var energyHint: String {
        switch self {
        case .menstrual: "to zwykle czas mniejszej energii. Możesz zwolnić bez wyrzutów sumienia"
        case .follicular: "energia zwykle rośnie z dnia na dzień"
        case .ovulatory: "zwykle najwięcej energii i pewności siebie"
        case .luteal: "energia może stopniowo opadać, a apetyt rosnąć – to normalne"
        }
    }

    var foodHint: String {
        switch self {
        case .menstrual: "ciepłe posiłki i żelazo: kasze, strączki, jajka, zielone liście"
        case .follicular: "więcej białka i świeżych warzyw – wspierają budowanie siły"
        case .ovulatory: "białko i lekkie, kolorowe posiłki"
        case .luteal: "magnez i sycące przekąski: kakao, orzechy, pestki, kasza gryczana"
        }
    }

    var movementHint: String {
        switch self {
        case .menstrual: "joga, spacer, rozciąganie – tyle, ile masz dziś siły"
        case .follicular: "dobry moment na trening siłowy i odrobinę więcej intensywności"
        case .ovulatory: "możesz dać sobie więcej: siła, interwały, taniec"
        case .luteal: "umiarkowanie: spokojna siła, pilates, długie spacery"
        }
    }

    var planningHint: String {
        switch self {
        case .menstrual: "jeśli możesz, zostaw sobie trochę przestrzeni: spokojniejsze zadania zamiast wymagających spotkań"
        case .follicular: "dobry czas, żeby wziąć na siebie coś trudnego, na co wcześniej brakowało sił"
        case .ovulatory: "jeśli masz przed sobą prezentację albo trudną rozmowę, to dobry dzień"
        case .luteal: "praca w skupieniu i we własnym tempie uda się lepiej niż dzień pełen spotkań"
        }
    }
}

extension PhaseInfo {
    /// Honest wording for estimates; nothing for days she marked herself.
    var confidenceNote: String? {
        guard !isLoggedPeriod else { return nil }
        switch confidence {
        case .high: return nil
        case .medium: return "to szacunek na podstawie Twoich ostatnich cykli"
        case .low: return "przy Twoich wahaniach cyklu to tylko szacunek – Twoje samopoczucie jest ważniejsze"
        }
    }

    var isEstimate: Bool {
        !isLoggedPeriod && confidence < .high
    }
}

/// "≈ owulacja · lato" with a coloured dot.
struct PhasePill: View {
    let phase: CyclePhase
    var isEstimate = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phase.tint)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(phase.tint.opacity(0.16)))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        let name = "\(phase.label) · \(phase.season)"
        return isEstimate ? "≈ \(name)" : name
    }
}
