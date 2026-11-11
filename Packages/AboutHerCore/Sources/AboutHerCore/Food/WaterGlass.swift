/// One tap adds a glass and one takes it back: where that glass goes and which one goes back.
/// The three parts of the day stay in her data (the card shows them in one short line), but she
/// no longer has to pick one herself.
extension WaterDay.Slot {
    /// The part of the day `hour` (0–23) belongs to, as the card names them: "rano" until 12:59,
    /// "popołudnie" from 13:00 to 19:59, "wieczór" from 20:00. An hour outside 0–23 counts as the
    /// nearest end of the day.
    public static func containing(hour: Int) -> WaterDay.Slot {
        if hour < 13 {
            return .morning
        }
        if hour < 20 {
            return .midday
        }
        return .evening
    }
}

extension WaterDay {
    /// Where a new glass goes. Today: the part of the day it is now (`hour`, 0–23). An earlier day,
    /// filled in afterwards: the part with the fewest glasses – the earliest of them on a tie – so
    /// such a day stays evenly spread instead of landing in whatever part of the day it is now.
    public func slotForNewGlass(isToday: Bool, hour: Int) -> Slot {
        if isToday {
            return .containing(hour: hour)
        }
        var fewest = Slot.morning
        for slot in Slot.allCases where count(in: slot) < count(in: fewest) {
            fewest = slot
        }
        return fewest
    }

    /// The glass "cofnij" takes back: one from `preferred` (where she has just added one) while it
    /// still has any, otherwise one from the latest part of the day that has a glass.
    /// nil when the day has no water at all.
    public func slotToTakeBack(preferring preferred: Slot? = nil) -> Slot? {
        if let preferred, count(in: preferred) > 0 {
            return preferred
        }
        return Slot.allCases.reversed().first { count(in: $0) > 0 }
    }
}
