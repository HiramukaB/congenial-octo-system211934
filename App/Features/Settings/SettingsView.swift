import SwiftUI
import UIKit
import AboutHerCore

/// "ustawienia", opened from "ja": her reminders and the Face ID lock.
///
/// Every reminder is off until she turns it on with its star; the first one she turns on asks
/// iOS whether the app may send notifications. A tap on a time opens a wheel in place, each turn
/// of it is saved at once, and another tap closes it – there is nothing to confirm.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    /// What iOS says about notifications; nil until it has been asked.
    @State private var permission: ReminderPermission?
    /// The reminder whose time is open.
    @State private var openKind: ReminderKind?
    /// The time on the open wheel.
    @State private var wheelTime = Date()
    /// The question about notifications is on screen.
    @State private var isAskingPermission = false
    @State private var isTurningLockOn = false
    /// A gentle line under the lock when it couldn't be turned on.
    @State private var lockNote: String?

    var body: some View {
        let settings = store.data.settings
        Screen {
            Text("ustawienia").screenTitle()
            remindersCard(settings.reminders)
            lockCard(isOn: settings.isLockEnabled)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            permission = await ReminderPermission.current()
        }
        .onChange(of: scenePhase) { _, phase in
            // She may be back from the phone's settings.
            if phase == .active {
                Task {
                    permission = await ReminderPermission.current()
                }
            }
        }
        .onChange(of: wheelTime) { _, date in
            guard let kind = openKind else { return }
            let time = SettingsClock.time(of: date)
            guard time != store.data.settings.reminders[kind].time else { return }
            store.updateSettings { $0.reminders[kind].time = time }
        }
    }

    // MARK: - Reminders

    private func remindersCard(_ reminders: ReminderSettings) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("przypomnienia").sectionTitle()
                Text(polish: "przypomnę Ci tylko o tym, co sama włączysz gwiazdką, a gdy pozwolisz na powiadomienia – także o dniu, w którym otworzy się Twój list. Dotknij godziny, żeby ją zmienić")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if permission == .denied && reminders.isAnyOn {
                    deniedNote
                }
                ForEach(ReminderKind.allCases, id: \.self) { kind in
                    reminderRow(kind, reminders: reminders)
                }
                Text(polish: "planuję je na tydzień naprzód i odświeżam, gdy zaglądasz do aplikacji")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reminderRow(_ kind: ReminderKind, reminders: ReminderSettings) -> some View {
        let setting = reminders[kind]
        let timeLabel = kind.timeLabel(in: reminders)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                SettingsStarToggle(label: "przypomnienie: \(kind.title)", isOn: setting.isOn) {
                    toggle(kind)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.subheadline)
                        .foregroundStyle(setting.isOn ? Palette.text : Palette.text2)
                    Text(polish: kind.detail(in: reminders))
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    openOrClose(kind)
                } label: {
                    Text(timeLabel)
                }
                .buttonStyle(LinkButtonStyle(font: .subheadline.monospacedDigit()))
                .accessibilityLabel(Text("zmień godzinę: \(kind.title), \(timeLabel)"))
            }
            if openKind == kind {
                timeEditor(kind, reminders: reminders)
            }
        }
    }

    /// The wheel, and for the weigh-in the day of the week above it.
    private func timeEditor(_ kind: ReminderKind, reminders: ReminderSettings) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if kind == .weighIn {
                weekdayChips(selected: reminders.weighInWeekday)
            }
            DatePicker("godzina", selection: $wheelTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "pl_PL"))
                .frame(maxWidth: .infinity)
        }
    }

    private func weekdayChips(selected: Int) -> some View {
        let flow = FlowLayout(spacing: 6, lineSpacing: 6)
        return flow {
            ForEach(1...7, id: \.self) { weekday in
                SettingsWeekdayChip(label: SettingsWords.weekdayShort(weekday),
                                    spoken: SettingsWords.weekdayName(weekday),
                                    isOn: weekday == selected) {
                    guard weekday != selected else { return }
                    store.updateSettings { $0.reminders.weighInWeekday = weekday }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var deniedNote: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(polish: "powiadomienia od about her są wyłączone w ustawieniach telefonu, więc moje przypomnienia do Ciebie nie dotrą. Dotknij gwiazdki – otworzę te ustawienia")
                .font(.footnote)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            StarButton(label: "otwórz ustawienia powiadomień", prominent: true) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
        }
    }

    /// Turns a reminder off, or on. The first one she turns on asks iOS for permission; once she
    /// allows notifications, the day a letter opens is on too.
    private func toggle(_ kind: ReminderKind) {
        guard !store.data.settings.reminders[kind].isOn else {
            store.updateSettings { $0.reminders[kind].isOn = false }
            return
        }
        guard !isAskingPermission else { return }
        isAskingPermission = true
        Task {
            var allowedJustNow = false
            if await ReminderPermission.current() == .notAsked {
                allowedJustNow = await ReminderPermission.ask()
            }
            // Her choice is kept even if she said no: it starts working once notifications are allowed.
            store.updateSettings { settings in
                settings.reminders[kind].isOn = true
                if allowedJustNow {
                    settings.reminders.letter.isOn = true
                }
            }
            permission = await ReminderPermission.current()
            isAskingPermission = false
        }
    }

    private func openOrClose(_ kind: ReminderKind) {
        withAnimation(.snappy) {
            if openKind == kind {
                openKind = nil
            } else {
                openKind = kind
                wheelTime = SettingsClock.date(of: store.data.settings.reminders[kind].time)
            }
        }
    }

    // MARK: - Lock

    private func lockCard(isOn: Bool) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("blokada").sectionTitle()
                HStack(alignment: .center, spacing: 6) {
                    SettingsStarToggle(label: "blokada Face ID", isOn: isOn) {
                        toggleLock(isOn: isOn)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Face ID przy otwieraniu")
                            .font(.subheadline)
                            .foregroundStyle(isOn ? Palette.text : Palette.text2)
                        Text(polish: "zanim pokażę Twoje dane, poproszę o Face ID albo kod telefonu, a w przełączaniu aplikacji zakryję ekran gwiazdką")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if let lockNote {
                    Text(polish: lockNote)
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Off at once; on only after she confirms it's her, and never on a phone without a passcode.
    private func toggleLock(isOn: Bool) {
        lockNote = nil
        guard !isOn else {
            store.setLockEnabled(false)
            return
        }
        guard !isTurningLockOn else { return }
        isTurningLockOn = true
        Task {
            let result = await AppLockSession.shared.turnOn(store)
            isTurningLockOn = false
            switch result {
            case .noPasscode:
                lockNote = "ten telefon nie ma kodu, więc blokady nie włączę. Gdy ustawisz kod w ustawieniach telefonu, wróć tu – włączę ją jednym dotknięciem"
            case .on, .notConfirmed:
                break
            }
        }
    }
}

extension ReminderKind {
    /// Her name for it in "ustawienia".
    var title: String {
        switch self {
        case .water: "woda"
        case .weighIn: "ważenie"
        case .periodSoon: "cykl"
        case .dinner: "kolacja"
        case .letter: "list do siebie"
        }
    }

    /// The time to tap: "11:00", or "pon 8:00" for the weigh-in.
    func timeLabel(in reminders: ReminderSettings) -> String {
        let time = reminders[self].time.text
        return self == .weighIn ? "\(SettingsWords.weekdayShort(reminders.weighInWeekday)) \(time)" : time
    }

    /// When it comes and when I skip it, in one line.
    func detail(in reminders: ReminderSettings) -> String {
        let time = reminders[self].time.text
        switch self {
        case .water:
            let times = SettingsWords.list(reminders.waterTimes.map(\.text))
            return "o \(times) · gdy wypijesz \(PolishPlural.glasses(WaterDay.goalGlasses)), resztę dnia pominę"
        case .weighIn:
            return "raz w tygodniu, \(SettingsWords.weekdayPhrase(reminders.weighInWeekday)) o \(time) · nie przypomnę, jeśli już się zważyłaś"
        case .periodSoon:
            return "o \(time), dwa dni przed spodziewanym okresem · na ekranie blokady napiszę tylko, że szykuje się nowy rozdział"
        case .dinner:
            return "o \(time) · nie zapytam, jeśli po \(ReminderPlan.eveningFromHour):00 dopisałaś już posiłek"
        case .letter:
            return "o \(time) w dniu, w którym otwiera się Twój list · bez słowa z jego treści"
        }
    }
}

/// A star that is filled while its setting is on and only outlined while it is off.
private struct SettingsStarToggle: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                OrganicStar()
                    .fill(isOn ? Palette.accent : Color.clear)
                OrganicStar()
                    .stroke(isOn ? Palette.accent : Palette.accentDim, lineWidth: 1.2)
            }
            .frame(width: 20, height: 20)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(StarPressStyle())
        .animation(.snappy(duration: 0.2), value: isOn)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(isOn ? "włączone" : "wyłączone"))
        .sensoryFeedback(.selection, trigger: taps)
    }
}

/// A day of the week for the weigh-in, in the soft capsule the app uses for choices.
private struct SettingsWeekdayChip: View {
    let label: String
    let spoken: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                OrganicStar()
                    .fill(isOn ? Palette.accent : Palette.accentDim.opacity(0.35))
                    .frame(width: 9, height: 9)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(isOn ? Palette.text : Palette.text2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(isOn ? Palette.accent.opacity(0.2) : Color.white.opacity(0.05))
            }
            .overlay {
                Capsule().strokeBorder(isOn ? Palette.accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            }
            // About 44 pt to tap, without changing the layout.
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .padding(.vertical, -6)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isOn)
        .accessibilityLabel(Text(spoken))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Weekdays and lists in Polish, for the lines above.
private enum SettingsWords {
    private static let shortNames = ["pon", "wt", "śr", "czw", "pt", "sob", "nd"]
    private static let names = ["poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela"]
    private static let phrases = ["w poniedziałek", "we wtorek", "w środę", "w czwartek", "w piątek", "w sobotę",
                                  "w niedzielę"]

    /// "pon" for ISO weekday 1.
    static func weekdayShort(_ weekday: Int) -> String {
        shortNames[index(weekday)]
    }

    /// "poniedziałek"
    static func weekdayName(_ weekday: Int) -> String {
        names[index(weekday)]
    }

    /// "w poniedziałek", "we wtorek"
    static func weekdayPhrase(_ weekday: Int) -> String {
        phrases[index(weekday)]
    }

    /// "11:00", "13:00 i 17:00", "11:00, 15:00 i 19:00"
    static func list(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        let rest = items.dropLast()
        return rest.isEmpty ? last : rest.joined(separator: ", ") + " i " + last
    }

    /// ISO 1 = Monday … 7 = Sunday, clamped, as an index into the lists.
    private static func index(_ weekday: Int) -> Int {
        min(max(weekday, 1), 7) - 1
    }
}

/// Reminder times on the wheel. A fixed winter day, so no daylight saving change shifts them.
private enum SettingsClock {
    static func date(of time: ReminderTime) -> Date {
        let components = DateComponents(year: 2001, month: 1, day: 1, hour: time.hour, minute: time.minute)
        return Calendar.current.date(from: components) ?? Date()
    }

    static func time(of date: Date) -> ReminderTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ReminderTime(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
    }
}
