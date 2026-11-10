import SwiftUI
import UIKit
import AboutHerCore

/// "ustawienia", opened from "ja": her reminders, the Face ID lock and the short guide again.
///
/// Each reminder is one row: its name, its time and a switch. Every reminder is off until she
/// turns it on; the first one she turns on asks iOS whether the app may send notifications. A tap
/// on the name or the time opens a wheel in place with a line about when it comes; each turn of
/// the wheel is saved at once, and another tap closes it – there is nothing to confirm.
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
    /// The reminder she is turning on while iOS asks about notifications; its switch shows on.
    @State private var askingKind: ReminderKind?
    @State private var isTurningLockOn = false
    /// A gentle line under the lock when it couldn't be turned on.
    @State private var lockNote: String?
    /// The short guide (`TutorialView`) is open.
    @State private var isShowingTutorial = false

    var body: some View {
        let settings = store.data.settings
        Screen {
            ScreenHeader(title: "ustawienia")
            remindersCard(settings.reminders)
            lockCard(isOn: settings.isLockEnabled)
            tutorialCard
        }
        .navigationBarTitleDisplayMode(.inline)
        // Slot: owner A builds the guide; it closes itself.
        .fullScreenCover(isPresented: $isShowingTutorial) {
            TutorialView()
        }
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
            VStack(alignment: .leading, spacing: Spacing.item) {
                SectionHeader("przypomnienia", subtitle: "tylko te, które sama włączysz")
                if permission == .denied && reminders.isAnyOn {
                    deniedNote
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ReminderKind.allCases, id: \.self) { kind in
                        if kind != ReminderKind.allCases.first {
                            RowDivider()
                        }
                        reminderRow(kind, reminders: reminders)
                    }
                }
                MoreInfo("jak przypominam?",
                         text: "planuję przypomnienia na tydzień naprzód i odświeżam je, gdy zaglądasz do aplikacji. Na ekranie blokady piszę ogólnie, bez Twoich danych")
            }
        }
    }

    /// One reminder: name and time on the left (a tap opens the time), a switch on the right.
    private func reminderRow(_ kind: ReminderKind, reminders: ReminderSettings) -> some View {
        let setting = reminders[kind]
        let isOpen = openKind == kind
        return VStack(alignment: .leading, spacing: Spacing.item) {
            HStack(alignment: .center, spacing: Spacing.item) {
                Button {
                    openOrClose(kind)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.text)
                        HStack(spacing: Spacing.tight) {
                            Text(kind.whenLabel(in: reminders))
                                .font(.body.monospacedDigit())
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .rotationEffect(.degrees(isOpen ? 180 : 0))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(setting.isOn ? Palette.accent : Palette.text2)
                    }
                    .padding(.vertical, Spacing.tight)
                    .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(kind.title), \(kind.spokenWhen(in: reminders))"))
                .accessibilityHint(Text(isOpen ? "zwija godzinę" : "zmienia godzinę"))
                SettingsSwitch(label: "przypomnienie: \(kind.title)", isOn: setting.isOn || askingKind == kind) {
                    toggle(kind)
                }
            }
            if isOpen {
                timeEditor(kind, reminders: reminders)
                    .padding(.bottom, Spacing.item)
                    .transition(.opacity)
            }
        }
    }

    /// The wheel – for the weigh-in with its day above it – and when the reminder comes.
    private func timeEditor(_ kind: ReminderKind, reminders: ReminderSettings) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            if kind == .weighIn {
                weekdayMenu(selected: reminders.weighInWeekday)
            }
            DatePicker("godzina", selection: $wheelTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "pl_PL"))
                .frame(maxWidth: .infinity)
            Text(polish: kind.detail(in: reminders))
                .hintText()
        }
    }

    /// The day of the weigh-in: a large button that opens the seven days.
    private func weekdayMenu(selected: Int) -> some View {
        Menu {
            ForEach(1...7, id: \.self) { weekday in
                Button {
                    setWeighInDay(weekday)
                } label: {
                    if weekday == selected {
                        Label(SettingsWords.weekdayName(weekday), systemImage: "checkmark")
                    } else {
                        Text(SettingsWords.weekdayName(weekday))
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.tight) {
                Text(SettingsWords.weekdayPhrase(selected))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, Spacing.cardGap)
            .frame(minHeight: TapSize.minimum)
            .background {
                Capsule()
                    .fill(Palette.accentBackground)
            }
            .overlay {
                Capsule()
                    .strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .accessibilityLabel(Text("dzień ważenia: \(SettingsWords.weekdayName(selected))"))
    }

    private var deniedNote: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text(polish: "powiadomienia od about her są wyłączone w ustawieniach telefonu, więc moje przypomnienia nie dotrą")
                .font(.footnote)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
            StarActionButton("otwórz ustawienia telefonu", size: .regular) {
                openNotificationSettings()
            }
        }
        .padding(.vertical, Spacing.hairline)
    }

    /// Turns a reminder off, or on. The first one she turns on asks iOS for permission; once she
    /// allows notifications, the day a letter opens is on too.
    private func toggle(_ kind: ReminderKind) {
        guard !store.data.settings.reminders[kind].isOn else {
            store.updateSettings { $0.reminders[kind].isOn = false }
            return
        }
        guard askingKind == nil else { return }
        askingKind = kind
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
            askingKind = nil
        }
    }

    private func openOrClose(_ kind: ReminderKind) {
        withAnimation(.snappy(duration: 0.25)) {
            if openKind == kind {
                openKind = nil
            } else {
                openKind = kind
                wheelTime = SettingsClock.date(of: store.data.settings.reminders[kind].time)
            }
        }
    }

    private func setWeighInDay(_ weekday: Int) {
        guard weekday != store.data.settings.reminders.weighInWeekday else { return }
        store.updateSettings { $0.reminders.weighInWeekday = weekday }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: - Lock

    private func lockCard(isOn: Bool) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.item) {
                SectionHeader("blokada")
                HStack(alignment: .center, spacing: Spacing.item) {
                    Text("Face ID przy otwieraniu")
                        .rowTitle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SettingsSwitch(label: "blokada Face ID", isOn: isOn || isTurningLockOn) {
                        toggleLock(isOn: isOn)
                    }
                }
                .frame(minHeight: TapSize.large)
                if let lockNote {
                    Text(polish: lockNote)
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MoreInfo("jak działa?",
                         text: "zanim pokażę Twoje dane, poproszę o Face ID albo kod telefonu. W przełączaniu aplikacji zakryję ekran gwiazdką")
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
                withAnimation(.smooth) {
                    lockNote = "blokady bez kodu nie włączę – ustaw kod w ustawieniach telefonu i wróć tu"
                }
            case .on, .notConfirmed:
                break
            }
        }
    }

    // MARK: - Guide

    /// "samouczek": the short guide to the app, once more. (Slot from the foundation round: the
    /// row and the cover it opens stay.)
    private var tutorialCard: some View {
        Card(padding: 0) {
            Button {
                isShowingTutorial = true
            } label: {
                MePlaceRow(title: "samouczek", detail: "jak korzystać z aplikacji", symbol: "lightbulb")
            }
            .buttonStyle(MePlacePressStyle())
            .accessibilityLabel(Text("samouczek, jak korzystać z aplikacji"))
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, Spacing.hairline)
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

    /// When it comes, as the row shows it: every water time ("11:00, 15:00 i 19:00"), the
    /// weigh-in with its day ("pon 8:00"), otherwise the time.
    func whenLabel(in reminders: ReminderSettings) -> String {
        switch self {
        case .water:
            SettingsWords.list(reminders.waterTimes.map(\.text))
        default:
            timeLabel(in: reminders)
        }
    }

    /// `whenLabel` for VoiceOver: "w poniedziałek o 8:00".
    func spokenWhen(in reminders: ReminderSettings) -> String {
        switch self {
        case .water:
            "o \(SettingsWords.list(reminders.waterTimes.map(\.text)))"
        case .weighIn:
            "\(SettingsWords.weekdayPhrase(reminders.weighInWeekday)) o \(reminders[self].time.text)"
        default:
            "o \(reminders[self].time.text)"
        }
    }

    /// When it comes and when I skip it, in one short line (the time is on the row already).
    func detail(in reminders: ReminderSettings) -> String {
        switch self {
        case .water:
            "gdy wypijesz \(PolishPlural.glasses(WaterDay.goalGlasses)), resztę dnia pominę"
        case .weighIn:
            "raz w tygodniu · nie przypomnę, jeśli już się zważyłaś"
        case .periodSoon:
            "dwa dni przed spodziewanym okresem · dyskretnie, bez słowa o nim"
        case .dinner:
            "nie zapytam, jeśli po \(ReminderPlan.eveningFromHour):00 dopisałaś już posiłek"
        case .letter:
            "w dniu, w którym otwiera się Twój list · bez słowa z jego treści"
        }
    }
}

/// A clear on/off switch, larger than the system one: a capsule that fills with the accent and a
/// knob that slides across – light on the dark track, dark with a small star on the champagne
/// one, so the two states never look alike. A tick on every change.
private struct SettingsSwitch: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Capsule()
                .fill(isOn ? Palette.accent : Color.white.opacity(0.1))
                .overlay {
                    Capsule()
                        .strokeBorder(isOn ? Color.clear : Color.white.opacity(0.14), lineWidth: 1)
                }
                .frame(width: 56, height: 34)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Palette.onAccent : Palette.text2)
                        .overlay {
                            if isOn {
                                OrganicStar()
                                    .fill(Palette.accent)
                                    .padding(7)
                            }
                        }
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .padding(3)
                }
                .frame(minWidth: TapSize.minimum, minHeight: TapSize.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isOn)
        .sensoryFeedback(.selection, trigger: taps)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(isOn ? "włączone" : "wyłączone"))
        .accessibilityAddTraits(.isToggle)
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
