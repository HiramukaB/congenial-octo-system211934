import SwiftUI
import AboutHerCore

/// The day a screen shows, between the steps to the day before and after: "dziś" in italic serif
/// with the date, or an earlier date with "wróć do dziś". Used by "jedzenie"; "dziś" has its own
/// header with the greeting.
struct DaySwitcher: View {
    let date: LocalDate
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: Spacing.tight) {
            ChevronStepButton(systemImage: "chevron.left", label: "poprzedni dzień", action: onPrevious)
            VStack(spacing: Spacing.hairline) {
                if isToday {
                    Text("dziś")
                        .displayFont(24, italic: true, relativeTo: .title2)
                        .foregroundStyle(Palette.accent)
                    Text(PolishDate.long(date))
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                } else {
                    Text(PolishDate.long(date))
                        .displayFont(19, weight: .medium, relativeTo: .title3)
                        .foregroundStyle(Palette.text)
                        .multilineTextAlignment(.center)
                    Button("wróć do dziś", action: onToday)
                        .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
                }
            }
            .frame(maxWidth: .infinity)
            ChevronStepButton(systemImage: "chevron.right", label: "następny dzień",
                              isEnabled: !isToday, action: onNext)
        }
    }
}
