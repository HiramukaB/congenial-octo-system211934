import Testing
@testable import AboutHerCore

// The water card adds a glass with one tap and takes one back with another.
@Suite("Water glasses")
struct WaterGlassTests {
    @Test func hoursFallIntoThePartsOfTheDayTheCardNames() {
        #expect(WaterDay.Slot.containing(hour: 0) == .morning)
        #expect(WaterDay.Slot.containing(hour: 12) == .morning)
        #expect(WaterDay.Slot.containing(hour: 13) == .midday)
        #expect(WaterDay.Slot.containing(hour: 19) == .midday)
        #expect(WaterDay.Slot.containing(hour: 20) == .evening)
        #expect(WaterDay.Slot.containing(hour: 23) == .evening)
    }

    @Test func anHourOutsideTheDayCountsAsTheNearestEnd() {
        #expect(WaterDay.Slot.containing(hour: -5) == .morning)
        #expect(WaterDay.Slot.containing(hour: 24) == .evening)
        #expect(WaterDay.Slot.containing(hour: Int.min) == .morning)
        #expect(WaterDay.Slot.containing(hour: Int.max) == .evening)
    }

    @Test func todayAGlassGoesToThePartOfTheDayItIsNow() {
        let day = WaterDay(morning: 3, midday: 0, evening: 0)
        #expect(day.slotForNewGlass(isToday: true, hour: 9) == .morning)
        #expect(day.slotForNewGlass(isToday: true, hour: 15) == .midday)
        #expect(day.slotForNewGlass(isToday: true, hour: 21) == .evening)
    }

    @Test func anEarlierDayFilledInLaterStaysEvenlySpread() {
        var day = WaterDay()
        var slots: [WaterDay.Slot] = []
        for _ in 0..<8 {
            // Late in the evening, which must not matter for an earlier day.
            let slot = day.slotForNewGlass(isToday: false, hour: 22)
            slots.append(slot)
            day.add(1, to: slot)
        }
        #expect(slots == [.morning, .midday, .evening, .morning, .midday, .evening, .morning, .midday])
        #expect(day == WaterDay(morning: 3, midday: 3, evening: 2))
    }

    @Test func anEarlierDayTopsUpThePartWithTheFewestGlasses() {
        #expect(WaterDay(morning: 2, midday: 0, evening: 1).slotForNewGlass(isToday: false, hour: 8) == .midday)
        #expect(WaterDay(morning: 1, midday: 2, evening: 1).slotForNewGlass(isToday: false, hour: 8) == .morning)
        #expect(WaterDay(morning: 4, midday: 4, evening: 3).slotForNewGlass(isToday: false, hour: 8) == .evening)
    }

    @Test func undoTakesBackTheGlassJustAddedThenTheLatestOne() {
        let day = WaterDay(morning: 2, midday: 1, evening: 0)
        #expect(day.slotToTakeBack(preferring: .morning) == .morning)
        // Nothing left in the evening: the latest part of the day that has a glass.
        #expect(day.slotToTakeBack(preferring: .evening) == .midday)
        #expect(day.slotToTakeBack() == .midday)
        #expect(WaterDay(morning: 1).slotToTakeBack() == .morning)
        #expect(WaterDay(morning: 1, midday: 0, evening: 2).slotToTakeBack(preferring: .morning) == .morning)
    }

    @Test func aDayWithoutWaterHasNothingToTakeBack() {
        #expect(WaterDay().slotToTakeBack() == nil)
        #expect(WaterDay().slotToTakeBack(preferring: .midday) == nil)
    }

    @Test func addingAndTakingBackLeavesTheDayAsItWas() {
        var data = AppData()
        let day = LocalDate(year: 2026, month: 11, day: 10)
        data.addWater(2, to: .morning, on: day)
        let before = data.water(on: day)
        let slot = before.slotForNewGlass(isToday: true, hour: 16)
        data.addWater(1, to: slot, on: day)
        #expect(data.water(on: day) == WaterDay(morning: 2, midday: 1, evening: 0))
        let back = data.water(on: day).slotToTakeBack(preferring: slot)
        #expect(back == .midday)
        if let back {
            data.addWater(-1, to: back, on: day)
        }
        #expect(data.water(on: day) == before)
    }
}
