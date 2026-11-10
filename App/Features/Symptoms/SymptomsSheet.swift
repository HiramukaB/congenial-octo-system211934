import SwiftUI
import AboutHerCore

/// How she felt on one day, opened from the calendar with a long press on that day: the same card
/// as on "dziś". Every tap is saved at once, so closing the sheet needs nothing more.
struct SymptomsSheet: View {
    let day: LocalDate

    var body: some View {
        ScrollView {
            SymptomsCard(day: day)
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.background)
    }
}

/// The day the calendar opens in `SymptomsSheet`.
nonisolated struct SymptomsSheetDay: Identifiable {
    let day: LocalDate
    var id: LocalDate { day }
}
