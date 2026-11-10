import Foundation

/// Her settings: local reminders, the lock and her first steps in the app (her name, the welcome,
/// the guide). Everything is off until she turns it on.
public struct AppSettings: Codable, Sendable, Hashable {
    public var reminders: ReminderSettings
    /// Face ID (or the passcode) before her data shows, and a cover in the app switcher.
    public var isLockEnabled: Bool
    /// Schema 4: her name, the welcome steps and the guide.
    public var onboarding: OnboardingState

    public init(reminders: ReminderSettings = ReminderSettings(), isLockEnabled: Bool = false,
                onboarding: OnboardingState = OnboardingState()) {
        self.reminders = reminders
        self.isLockEnabled = isLockEnabled
        self.onboarding = onboarding
    }

    enum CodingKeys: String, CodingKey {
        case reminders, isLockEnabled, onboarding
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reminders = try container.decodeIfPresent(ReminderSettings.self, forKey: .reminders) ?? ReminderSettings()
        isLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLockEnabled) ?? false
        onboarding = try container.decodeIfPresent(OnboardingState.self, forKey: .onboarding) ?? OnboardingState()
    }
}

/// Local reminders on her phone. All are off until she turns them on; the times are suggestions
/// she can change.
public struct ReminderSettings: Codable, Sendable, Hashable {
    /// Water during the day; `time` is the first reminder of the day (see `waterTimes`).
    public var water: ReminderSetting
    /// The weekly weigh-in, on `weighInWeekday`.
    public var weighIn: ReminderSetting
    /// ISO weekday of the weigh-in: 1 = Monday … 7 = Sunday.
    public var weighInWeekday: Int
    /// A discreet note two days before the expected period.
    public var periodSoon: ReminderSetting
    /// In the evening: "dopisać kolację?".
    public var dinner: ReminderSetting
    /// On the day a letter to herself opens.
    public var letter: ReminderSetting

    /// A weekday outside 1–7 is clamped. Water starts at 11:00 (then 15:00 and 19:00), the
    /// weigh-in is on Monday.
    public init(water: ReminderSetting = ReminderSetting(time: ReminderTime(hour: 11)),
                weighIn: ReminderSetting = ReminderSetting(time: ReminderTime(hour: 8)),
                weighInWeekday: Int = 1,
                periodSoon: ReminderSetting = ReminderSetting(time: ReminderTime(hour: 9)),
                dinner: ReminderSetting = ReminderSetting(time: ReminderTime(hour: 20)),
                letter: ReminderSetting = ReminderSetting(time: ReminderTime(hour: 9))) {
        self.water = water
        self.weighIn = weighIn
        self.weighInWeekday = Swift.min(Swift.max(weighInWeekday, 1), 7)
        self.periodSoon = periodSoon
        self.dinner = dinner
        self.letter = letter
    }

    enum CodingKeys: String, CodingKey {
        case water, weighIn, weighInWeekday, periodSoon, dinner, letter
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReminderSettings()
        self.init(water: try container.decodeIfPresent(ReminderSetting.self, forKey: .water) ?? defaults.water,
                  weighIn: try container.decodeIfPresent(ReminderSetting.self, forKey: .weighIn) ?? defaults.weighIn,
                  weighInWeekday: try container.decodeIfPresent(Int.self, forKey: .weighInWeekday) ?? defaults.weighInWeekday,
                  periodSoon: try container.decodeIfPresent(ReminderSetting.self, forKey: .periodSoon) ?? defaults.periodSoon,
                  dinner: try container.decodeIfPresent(ReminderSetting.self, forKey: .dinner) ?? defaults.dinner,
                  letter: try container.decodeIfPresent(ReminderSetting.self, forKey: .letter) ?? defaults.letter)
    }
}

/// One reminder: whether it's on and at what time.
public struct ReminderSetting: Codable, Sendable, Hashable {
    public var isOn: Bool
    public var time: ReminderTime

    public init(isOn: Bool = false, time: ReminderTime) {
        self.isOn = isOn
        self.time = time
    }

    enum CodingKeys: String, CodingKey {
        case isOn, time
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        time = try container.decodeIfPresent(ReminderTime.self, forKey: .time) ?? ReminderTime(hour: 9)
    }
}

/// A time of day in her own time zone.
public struct ReminderTime: Codable, Sendable, Hashable, Comparable {
    /// 0–23
    public let hour: Int
    /// 0–59
    public let minute: Int

    /// Values out of range are clamped.
    public init(hour: Int, minute: Int = 0) {
        self.hour = Swift.min(Swift.max(hour, 0), 23)
        self.minute = Swift.min(Swift.max(minute, 0), 59)
    }

    public static func < (lhs: ReminderTime, rhs: ReminderTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    enum CodingKeys: String, CodingKey {
        case hour, minute
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(hour: try container.decodeIfPresent(Int.self, forKey: .hour) ?? 9,
                  minute: try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0)
    }
}
