# about her – design rules (round 0.3)

For developers. The owner's verdict on 0.1.19: badly managed whitespace, a tab bar that hides,
chips too small to hit, scales that should be dragged, every screen a little tiring. The goal is
**simplicity and usability inside the existing aesthetic** – a calm, warm, inviting app she wants
to open, never a chore. Change layout, hierarchy, spacing, controls and copy length. Keep the
identity: the dark warm palette, the organic four-point star as the sign of every action, serif
lowercase headings, calm motion, Liquid Glass only where iOS gives it (tab bar, bars, sheets).

`App/DesignSystem` is owned by the foundation round. Screen owners use it and do not edit it;
anything missing goes into the screen's own file (private), not into a copy of a component.

## Principles

1. **One clear purpose per screen.** The first card is what she came for. Information she only
   sometimes needs goes lower or behind a tap.
2. **Fewer, calmer cards.** Merge cards that belong together; no card inside a card; no card for a
   single line of text. A screen should rarely need more than 4–5 cards.
3. **Short copy.** A title, a value, at most one short hint per card (≤ ~70 characters). Long
   explanations move behind `MoreInfo` ("dlaczego?", "jak to liczę?"). No instructions that
   describe the UI ("dotknij gwiazdki, a zapiszę…") – make the control say it instead.
4. **Progressive disclosure.** Details on tap: history, explanations, editors open in place.
5. **Big targets.** Every action ≥ 44 × 44 pt; primary actions and tiles ~56 pt. No chips.
6. **Scales are dragged.** Every 1–10 rating is a `DragScale` (drag or tap anywhere, haptic tick
   per step). Yes/no items are `ToggleTile`s, one-of-a-few choices `ChoiceTiles`.
7. **Generous but consistent whitespace.** Only the spacing tokens below; the same gaps in every
   card. Never stack a header row that is taller than its title.
8. **Nothing under the tab bar.** The bar is always visible (`.tabBarMinimizeBehavior(.never)`);
   `Screen` ends with 32 pt above it. Don't add `ignoresSafeArea` to content.
9. **Positive, inviting feedback.** A haptic on every change, a soft `ConfirmationNote` after a
   meaningful one ("zapisałam"), warm empty states (`EmptyState`). Never red, never alarming,
   never judging numbers ("ponad cel" is fine, "za dużo" is not).

## Her rules (all strings and interactions)

- Inputs appear on tap and save themselves; closing saves. **No save / cancel buttons** (also not
  in sheets – "anuluj" + "✓" in `NutritionProfileSheet`/`TeachFoodSheet` break this).
- Swipe left to delete (`.swipeToDelete`), tap to edit.
- Headings and labels lowercase. `Twój/Twoje/Twoja/Twoich/Ciebie/Ci/Tobie` capitalised.
- The app speaks as a woman in the first person ("zapisałam", "przypomnę Ci") and addresses her as
  a woman ("zrobiłaś"). Warm, gentle, short sentences. Nothing medical or judgemental.
- Use `Text(polish:)` for running Polish text (keeps one-letter words off line ends).
- Privacy: never her real name or data in code, tests, demo data or comments. Demo name: "Ola".

## Spacing (`Spacing`, `Radius`, `TapSize` – Spacing.swift)

| Token | pt | Use |
|---|---|---|
| `Spacing.hairline` | 4 | title → its one-line detail |
| `Spacing.tight` | 8 | icon → label, tiles in a grid, lines of one block |
| `Spacing.item` | 12 | items of one group inside a card |
| `Spacing.cardGap` | 16 | between cards (`Screen` does it); card header → content |
| `Spacing.card` | 20 | card padding (`Card` does it); screen side margins (`Screen` does it) |
| `Spacing.group` | 24 | between groups in a card (one scale → the next, list → action) |
| `Spacing.section` | 32 | after a screen header; below the last card (`Screen` does it) |
| `Radius.card` / `.tile` / `.field` | 24 / 16 / 14 | cards / tiles & buttons inside cards / open fields |
| `TapSize.minimum` / `.large` | 44 / 56 | every target / primary actions, tiles, scale tracks |

A card's content is one `VStack(alignment: .leading, spacing: Spacing.cardGap)` (header + groups);
inside a group use `Spacing.item`. Don't hand-tune 6, 10, 14 pt gaps.

## Typography (Typography.swift)

| Role | Modifier / component | Look |
|---|---|---|
| Screen title | `ScreenHeader(title:subtitle:)` or `.screenTitle()` | serif 30 medium, `text` |
| Card heading | `SectionHeader(_:subtitle:trailing:)` or `.sectionTitle()` | serif 19 medium, `accent`, lowercase |
| Big number | `.bigNumber()` | serif 52, `text` (cycle day, trend weight) |
| Her own sentence | `.displayFont(18–22, italic: true, relativeTo: .body)` | serif italic, `text` |
| Body copy | `.bodyText()` | `.body` 17, `text2`, wraps |
| Row title | `.rowTitle()` | `.body` 17, `text` |
| Row detail | `.rowDetail()` | `.subheadline` 15, `muted` |
| Value | `.valueText()` | `.body` monospaced digits, `text` |
| Hint | `.hintText()` | `.footnote` 13, `muted`, wraps – max one per card |
| Eyebrow | `.eyebrow()` | caption uppercase, `muted` – sparingly |

Everything scales with Dynamic Type (`displayFont` uses `@ScaledMetric`). Don't use `.caption2`
for anything she has to read.

## Colour and contrast (Palette.swift)

- `text` #F0EEEA: her words, values, titles. `text2` #C9C7C2: body copy (≈10:1 on a card).
- `muted` #A8A6A1 (raised from #A09F9B, ≈6.5:1 on a card): **only** hints and metadata. Never for
  something she must read to act, never for whole paragraphs.
- `accent` #D6CDB4: card headings, links, stars, what is on/chosen. `accentDim`: quiet stars.
- `onAccent`: text/stars on a filled accent shape (`StarActionButton(.large)`, scale handle).
- `removeBackground`: behind a swiped-open bin. There is no red in the palette – keep it that way.
- Phase tints (`CyclePhase.tint`) only for cycle meaning (calendar, phase pill, background tint).

## Cards (Card.swift)

`Card(style:)`: 20 pt padding, 24 pt corners.
- `.standard` – frosted dark; almost everything.
- `.highlight` – a warm accent wash and border; **one per screen at most**: the card the screen is
  about (today's cycle day, the current welcome step, today's suggestion in "ruch").
- `.quiet` – no fill, hairline only; secondary info that shouldn't compete (notes, history).
No nested cards (the question card in "chwila dla siebie" is a card in a card – fix it).
`.fieldBox()` is the one look for an open text field.

## Components – when to use which

| Need | Use | API |
|---|---|---|
| a screen | `Screen` + `ScreenHeader` | `Screen(tint:) { ScreenHeader(title: "jedzenie", subtitle: nil) … }` |
| card heading (+ star/accessory) | `SectionHeader` | `SectionHeader("woda")`, `SectionHeader("co zjadłaś", subtitle: nil) { StarButton(…) }` |
| rating 1–10 | `DragScale` | `DragScale("energia", value: Int?, range: 1...10, words: [ScaleWord(1...3, "niska"), …], tint:) { (Int?) in save }` or `DragScale("…", value: $binding, …)` |
| yes/no items | `ToggleTile` in `TileGrid` | `TileGrid(columns: 2) { ToggleTile(title:isOn:action:) }` |
| one of a few | `ChoiceTiles` | `ChoiceTiles(options:selection:columns:label:onSelect:)` |
| the primary action | `StarActionButton` | `StarActionButton("dalej", size: .large, isEnabled: true) { … }` – `.large` 56 pt full width; `.regular` 44 pt for actions inside a card |
| tiny icon action (header +) | `StarButton` | existing; 44 pt target |
| previous / next day or month | `ChevronStepButton` (Features/Shared) | `ChevronStepButton(systemImage: "chevron.left", label: "poprzedni dzień", isEnabled:) { … }` – the same on "dziś", "kalendarz" and "jedzenie" |
| list rows | `ListRow` + `.swipeToDelete` + `RowDivider` | `ListRow(text, detail:) { trailing }.swipeToDelete(label:onTap:perform:)` |
| nothing yet | `EmptyState` | `EmptyState(title:message:actionTitle:action:)` |
| long explanation | `MoreInfo` | `MoreInfo("dlaczego?", text: "…")` |
| "zapisałam" | `ConfirmationNote` | `ConfirmationNote(text:)`, insert with `withAnimation(.smooth)` |
| inline link | `LinkButtonStyle` | `.buttonStyle(LinkButtonStyle())` – secondary actions only |
| wrapping chips | `FlowLayout` | only for short read-only tags, not for choices |

Notes:
- `DragScale` saves on every step through its closure – hand it straight to the store
  (`store.setSymptomScale(\.energy, to: value, on: day)`). It has its own haptics; don't add more.
  In a `ScrollView` vertical swipes still scroll. Unset shows "przeciągnij"; "wyczyść" clears.
- Words for the symptom scales: `SymptomScaleWords.energy/.mood/.sleep/.appetite`.
- Tiles and `StarActionButton` have haptics built in.
- A trailing accessory in `SectionHeader` keeps its 44 pt target without making the header taller.

## Motion

Calm and short: `.snappy(duration: 0.2)` for state changes, `.smooth` for content appearing,
springs only on press feedback (built into the components). Respect Reduce Motion (the ambient
background already does). No bouncing lists, no confetti.

## Accessibility checklist

Every control has a Polish label; values read naturally ("7 z 10, średnia", "4 z 8 szklanek",
not "4 / 8"); toggles expose `.isSelected`; headings expose `.isHeader` (`ScreenHeader` and
`SectionHeader` do); decorative stars are `accessibilityHidden`; nothing relies on colour alone;
layouts survive the largest Dynamic Type sizes (wrap, don't truncate).

## App shell and slots (do not move)

- `RootView`: five tabs, tab bar always visible, `.onChange` hooks (scene phase → `refreshToday`,
  `saveNow`, reminders; midnight; food day reset), `.problemAlert`, `.appLock()`.
- Welcome: `RootView` presents `OnboardingView()` (owner A) as a full-screen cover while
  `store.needsOnboarding` is true; it closes only through `store.completeOnboarding()`. Never call
  `dismiss()` inside the welcome. The cover has its own `.problemAlert()`.
- `SettingsView` → row "samouczek" → `TutorialView()` (owner A) as a full-screen cover; it closes
  itself, or calls `onFinish` when embedded in the welcome.
- `MeView` → `MeLink "humor"` → `HumorView()` (owner F).
- `TodayView` → `HumorTodayCard(day:)` (owner F) after `SymptomsCard`; it shows itself only when
  there is something to show.
- Launch arguments: `-demoData`, `-showOnboarding` (welcome on demo data), `-skipOnboarding`
  (UI tests on real storage), `-startTab`, `-stillBackground` (see `LaunchArguments`).

## Data notes for screens

- Symptom scales are `Int?` 1–10 (`SymptomDay.energy/mood/sleep/appetite`); `SymptomScale.low` is
  1–3, `.high` 8–10. Old files' words map to 2/5/8 (mood 9/7/5/3/1) on load.
- `MoodLevel(score:)` gives the five mood bands (meditation, intentions) and `.label`.
- Her name: `store.preferredName` (may be nil – greet without a name then).

## What we saw (0.1.19 screenshots) – per screen

**Everywhere**
- The tab bar shrank to one round button on scroll (fixed in `RootView`).
- Chips of ~30 pt (symptoms, mood in "chwila", workout kinds 34 pt, weekday chips) – hard to hit.
- Nearly every card ends in a 2–4 line muted paragraph; with 15 pt body text the screens read like
  fine print. Body copy is now 17 pt (`bodyText`), so cut the words.
- Headers with a 44 pt star on the right ("co zjadłaś", "waga", "Twój ruch", "intencja",
  "pytanie do przemyślenia") sit lower and leave a gap above the content; plain headers don't.
- Gaps of 6/8/10/12/14 pt mixed in one card; rows with 44 pt swipe height next to 6 pt padded rows
  (e.g. "dziś" → "spacer · 30 min" in "Twój ruch" has a hole).
- Instructions instead of labelled actions ("zrobione? Dotknij gwiazdki, a zapiszę: joga · 10 min").
- Pushed screens: back button, then a large title, then an intro paragraph – ~200 pt before content.

**dziś** – Motto + "dziś" switcher + date + cycle card: four header layers before anything she
does. Cycle card stacks number, pill, a 2-line confidence note, next period and range – keep number
+ pill + one line; the rest on tap. "intencja na dziś" is a full card for one sentence. "dzień w
skrócie" duplicates the food tab – make it one compact tappable row. "jak się dziś czujesz?" was the
heaviest card (4 rows of chips + 7 symptom chips + hint); the scales are now `DragScale`s (minimal
swap) – redesign: scales first, symptoms as `ToggleTile`s behind "objawy", no hint. The phase guide
is 4 rows of text + disclaimer – one line visible, details on tap.

**kalendarz** – The month card carries a 3-row legend and a 2-line hint; long-press for "jak się
czułaś" is only explained there. Make the legend one compact line, the hint a `MoreInfo` or a first
-use note; consider a visible way to open a day's feelings for the selected day. Month switch stars
are tiny glyphs. "Twój rytm" and history are fine; history could be `.quiet`.

**jedzenie** – "jedzenie" + "dziś" + date are three headings. Balance: four bars + "w tym ruch" +
summary – keep kcal and protein prominent, others smaller. Adding a meal is a small unlabeled star
in the header – give it a `StarActionButton(.regular)` "dopisz posiłek". Each meal is three lines
(text, products, macros) – make rows compact (text + kcal), details on tap. Water: 11 pt "minus"
star, 4-line hint – bigger +/− targets, one short line. Weight: 4-line hint above the numbers,
4 stat lines, chart, list of 6 – show the trend number big, chart, history on tap; hint into
`MoreInfo`. Targets sheet (07): grey system `Form`, "anuluj" + "✓" buttons – against her rules
and the look.

**ruch** – "na dziś": headline + paragraph + video tile + instruction text with a star; make it one
`.highlight` card with the video and a `StarActionButton` "zrobione". "Twój ruch": week strip,
summary, day labels, rows with uneven gaps; adding is a header star; the editor has 11 small kind
chips and a tiny minutes field – use `ChoiceTiles` (3 columns) or a short list of common kinds +
"inne", and a larger minutes input. "Twój etap": three long stage texts + footnote – show the
current stage, others on tap.

**ja** – Five (now six) full cards used as a menu, each with a 2-line detail; heavy for a list of
places. Group into one or two cards of `ListRow`s with chevrons; keep the version footer.

**chwila dla siebie** – Intro paragraph; meditation card asks the mood again with 5 chips (use the
mood she marked today, change it with a `DragScale`); intention card has a 2-line hint + link;
breathing card has a long instruction; the question is a card inside a card. Five cards make a long
scroll – lead with one thing (meditation or breathing), the rest below, notes `.quiet`.

**wnętrze** – Mostly calm. The intention card repeats "dziś"; hints under every card; the "dopisz
małe zwycięstwo" row is an 11 pt star + text – make it a clear action. "kim się stajesz" is good.

**ustawienia** – 4-line intro, then five reminders each with 2–3 lines of detail and an outlined
20 pt star that doesn't read as a switch, plus a time link. Make each reminder one row: name, time
(tap to change), a clear on/off control; details on tap. The lock card has a 3-line text. The new
"samouczek" row is a slot (keep it, restyle freely).

**list do siebie / zdjęcia / sheets** – long intro paragraphs (photos: two). Sheets use grey
`Form`s and toolbar buttons; make them match the cards and close-to-save.

## Don't change (contract with the screen agents)

- Anything in `App/DesignSystem`, `RootView.swift`, `App/System/LaunchArguments.swift`,
  `App/Store/AppStore.swift`, `AppStore+Onboarding.swift`, `AppStore+Humor.swift`,
  `AppStore+Symptoms.swift`, Core's `AppData`, `Symptoms`, `Onboarding`, `Humor` and schema 4.
  Need more? Add a new file (`AppStore+Feature.swift`, a private view) instead.
- The slots listed above and the screenshot names in `UITests`.
- Accessibility identifiers used by UI tests: `day-YYYY-MM-DD`, `meal-field`, `workout-minutes`,
  the labels "dopisz posiłek", "Twoje cele dzienne", and the "ja" entries' titles
  ("chwila dla siebie", "wnętrze", "ustawienia") at the start of their labels.
