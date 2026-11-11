import SwiftUI
import AboutHerCore

/// How she felt on one day, opened from the calendar: the same scales as on "dziś", with the
/// symptom tiles open. Every change is saved at once, so closing the sheet needs nothing more.
struct SymptomsSheet: View {
    let day: LocalDate

    var body: some View {
        ScrollView {
            DaySymptomsForm(day: day)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.section)
                .padding(.bottom, Spacing.section)
                // Like `Screen`: a swipe scrolls wherever it starts, between the rows too.
                .contentShape(Rectangle())
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.background)
    }
}

/// The day the calendar opens in `SymptomsSheet`.
nonisolated struct SymptomsSheetDay: Identifiable {
    let day: LocalDate
    var id: LocalDate { day }
}
