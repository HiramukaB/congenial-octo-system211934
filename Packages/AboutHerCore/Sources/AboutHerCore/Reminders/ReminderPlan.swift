import Foundation

/// The five reminders she can turn on in "ustawienia", in the order they are shown.
public enum ReminderKind: String, CaseIterable, Sendable {
    case water, weighIn, periodSoon, dinner, letter
}

extension ReminderSettings {
    /// One reminder by its kind.
    public subscript(kind: ReminderKind) -> ReminderSetting {
        get {
            switch kind {
            case .water: water
            case .weighIn: weighIn
            case .periodSoon: periodSoon
            case .dinner: dinner
            case .letter: letter
            }
        }
        set {
            switch kind {
            case .water: water = newValue
            case .weighIn: weighIn = newValue
            case .periodSoon: periodSoon = newValue
            case .dinner: dinner = newValue
            case .letter: letter = newValue
            }
        }
    }

    /// Whether she turned at least one reminder on.
    public var isAnyOn: Bool {
        ReminderKind.allCases.contains { self[$0].isOn }
    }

    /// The water reminders of a day: the first at her time, then every 4 hours – at most three,
    /// and none of the later ones after 20:00, so she drinks less in the evening and sleeps
    /// through the night. Her own first time always stays.
    public var waterTimes: [ReminderTime] {
        let first = water.time
        var times = [first]
        for step in 1..<ReminderPlan.waterRemindersPerDay {
            let hour = first.hour + step * ReminderPlan.hoursBetweenWater
            let time = ReminderTime(hour: hour, minute: first.minute)
            guard hour <= 23, time <= ReminderPlan.lastWaterTime else { break }
            times.append(time)
        }
        return times
    }
}

extension ReminderTime {
    /// "8:00", "19:30"
    public var text: String {
        minute < 10 ? "\(hour):0\(minute)" : "\(hour):\(minute)"
    }
}

/// One local notification, planned: when it comes and the words on her lock screen.
public struct PlannedReminder: Sendable, Hashable {
    /// The same reminder on the same day and time always gets the same one,
    /// e.g. "abouther.water.2026-11-10.1100".
    public let identifier: String
    public let kind: ReminderKind
    public let day: LocalDate
    public let time: ReminderTime
    /// When it comes, in the calendar it was planned with.
    public let date: Date
    public let title: String
    public let body: String
}

/// Which local notifications to schedule for the coming week, worked out from her data alone.
///
/// Only what she turned on, only what is still ahead, earliest first. The app schedules them
/// again each time it becomes active and whenever something they depend on changes, so
/// skipping works day by day: no more water once she drank her glasses, no dinner question once
/// she logged an evening meal, no weigh-in once she weighed herself today.
public enum ReminderPlan {
    /// How many days ahead are planned, today included.
    public static let horizonDays = 7
    /// iOS keeps at most 64 pending notifications per app; the plan stays under 60.
    public static let maximumCount = 59
    /// Every identifier starts with it.
    public static let identifierPrefix = "abouther."
    /// A meal logged at this hour or later counts as an evening meal.
    public static let eveningFromHour = 16
    /// The note about the cycle comes this many days before the expected period.
    public static let daysBeforePeriod = 2

    static let waterRemindersPerDay = 3
    static let hoursBetweenWater = 4
    static let lastWaterTime = ReminderTime(hour: 20)

    /// Everything in her data the reminders depend on. A fact is looked at only while its
    /// reminder is on, so a change nothing depends on doesn't change the facts.
    public struct Facts: Sendable, Hashable {
        public var today: LocalDate
        public var settings: ReminderSettings
        /// She drank her glasses today.
        public var drankEnoughToday: Bool
        /// She logged a meal today at 16:00 or later.
        public var loggedEveningMealToday: Bool
        public var weighedInToday: Bool
        /// The expected start of her next period, as the cycle engine sees it today.
        public var expectedPeriod: LocalDate?
        /// The days of the planned week on which a letter to herself opens.
        public var letterDays: Set<LocalDate>

        public init(data: AppData, today: LocalDate, calendar: Calendar) {
            let settings = data.settings.reminders
            self.today = today
            self.settings = settings
            drankEnoughToday = settings.water.isOn
                && data.water(on: today).total >= WaterDay.goalGlasses
            loggedEveningMealToday = settings.dinner.isOn && data.meals(on: today).contains { meal in
                LocalDate.today(calendar: calendar, now: meal.createdAt) == today
                    && calendar.component(.hour, from: meal.createdAt) >= ReminderPlan.eveningFromHour
            }
            weighedInToday = settings.weighIn.isOn && data.weights[today] != nil
            expectedPeriod = settings.periodSoon.isOn
                ? CycleEngine(periodDays: data.periodDays, today: today).status(on: today).prediction?.expected
                : nil
            let lastDay = today.adding(days: ReminderPlan.horizonDays - 1)
            letterDays = settings.letter.isOn
                ? Set(data.letters.map(\.opensOn).filter { $0 >= today && $0 <= lastDay })
                : []
        }
    }

    /// What to schedule from `now` on, for the next `horizonDays` days.
    public static func reminders(for data: AppData, now: Date, calendar: Calendar) -> [PlannedReminder] {
        let today = LocalDate.today(calendar: calendar, now: now)
        return reminders(for: Facts(data: data, today: today, calendar: calendar), now: now, calendar: calendar)
    }

    /// What to schedule from `now` on, for the `horizonDays` days starting with `facts.today`.
    public static func reminders(for facts: Facts, now: Date, calendar: Calendar) -> [PlannedReminder] {
        let settings = facts.settings
        var planned: [PlannedReminder] = []

        func add(_ kind: ReminderKind, on day: LocalDate, at time: ReminderTime, _ text: ReminderText) {
            let moment = DateComponents(year: day.year, month: day.month, day: day.day,
                                        hour: time.hour, minute: time.minute)
            guard let date = calendar.date(from: moment), date > now else { return }
            planned.append(PlannedReminder(identifier: identifier(kind, on: day, at: time), kind: kind,
                                           day: day, time: time, date: date,
                                           title: text.title, body: text.body))
        }

        for offset in 0..<horizonDays {
            let day = facts.today.adding(days: offset)
            let isToday = offset == 0
            if settings.water.isOn && !(isToday && facts.drankEnoughToday) {
                for (index, time) in settings.waterTimes.enumerated() {
                    add(.water, on: day, at: time, ReminderText.water(index))
                }
            }
            if settings.weighIn.isOn && day.isoWeekday == settings.weighInWeekday
                && !(isToday && facts.weighedInToday) {
                add(.weighIn, on: day, at: settings.weighIn.time, ReminderText.weighIn)
            }
            if settings.periodSoon.isOn, let expected = facts.expectedPeriod,
               expected.adding(days: -daysBeforePeriod) == day {
                add(.periodSoon, on: day, at: settings.periodSoon.time, ReminderText.periodSoon)
            }
            if settings.dinner.isOn && !(isToday && facts.loggedEveningMealToday) {
                add(.dinner, on: day, at: settings.dinner.time, ReminderText.dinner)
            }
            if settings.letter.isOn && facts.letterDays.contains(day) {
                add(.letter, on: day, at: settings.letter.time, ReminderText.letter)
            }
        }
        let ordered = planned.sorted { ($0.date, $0.identifier) < ($1.date, $1.identifier) }
        return Array(ordered.prefix(maximumCount))
    }

    /// "abouther.water.2026-11-10.1100"
    static func identifier(_ kind: ReminderKind, on day: LocalDate, at time: ReminderTime) -> String {
        let hour = time.hour < 10 ? "0\(time.hour)" : "\(time.hour)"
        let minute = time.minute < 10 ? "0\(time.minute)" : "\(time.minute)"
        return "\(identifierPrefix)\(kind.rawValue).\(day.iso).\(hour)\(minute)"
    }
}

/// The words on her lock screen. Anyone may see them there, so they stay gentle and discreet:
/// nothing about her period or her weight, and never a word of what she wrote.
struct ReminderText: Sendable, Hashable {
    let title: String
    let body: String

    static let waterBodies = [
        "mała przerwa na szklankę wody?",
        "szklanka wody dobrze Ci teraz zrobi",
        "jeszcze jedna szklanka wody – w swoim tempie",
    ]

    /// The text of the day's water reminder number `index` (0 = the first).
    static func water(_ index: Int) -> ReminderText {
        let count = waterBodies.count
        return ReminderText(title: "woda", body: waterBodies[(index % count + count) % count])
    }

    static let weighIn = ReminderText(
        title: "Twój cotygodniowy moment",
        body: "jeśli masz dziś ochotę, zajrzyj do „jedzenie” – bez presji, liczy się kierunek, nie jeden dzień")
    static let periodSoon = ReminderText(
        title: "na najbliższe dni",
        body: "zajrzyj do kalendarza – szykuje się nowy rozdział. Bądź dla siebie łagodna")
    static let dinner = ReminderText(
        title: "dopisać kolację?",
        body: "jeśli już jadłaś, wystarczy kilka słów w „jedzenie”")
    static let letter = ReminderText(
        title: "list do siebie",
        body: "dziś możesz przeczytać to, co kiedyś do siebie napisałaś – czeka na Ciebie w „ja”")

    /// Every text the plan can use.
    static var all: [ReminderText] {
        waterBodies.indices.map(water) + [weighIn, periodSoon, dinner, letter]
    }
}
