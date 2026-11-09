# about her

Natywna aplikacja na iPhone'a (iOS 26+, docelowo iPhone 16 Pro), następczyni wersji HTML.
Cykl, jedzenie, ruch, sen i wnętrze w jednym miejscu, w zgodzie z rytmem cyklu i bez presji.

> **Prywatność:** dane zostają w telefonie. W repozytorium nie ma danych osobowych:
> `about-her.html`, `transkrypt.txt` i kopie JSON są w `.gitignore`.

## Stan

| Część | Status |
|---|---|
| Design system: kolory, gwiazdka, animowane tło, karty | gotowe |
| 5 zakładek: dziś · kalendarz · jedzenie · ruch · ja | szkielet |
| Cykl: kalendarz okresu, fazy z poziomem pewności, prognoza, spóźnienia | gotowe |
| Zapis danych (plik JSON) z dziennymi kopiami | gotowe |
| Import dni okresu z kopii wersji HTML | gotowe |
| Jedzenie, ruch, wnętrze | w budowie |

## Struktura

```
App/                      aplikacja SwiftUI
  DesignSystem/           kolory, typografia, gwiazdka, animowane tło, karty
  Features/               ekrany: Today, Calendar, Me i zakładki w budowie
  Store/                  stan aplikacji i zapis do pliku
Packages/AboutHerCore/    logika bez interfejsu (daty, silnik cyklu, dane) + testy
UITests/                  test robiący zrzuty ekranu każdej zakładki
project.yml               definicja projektu dla XcodeGen (.xcodeproj się generuje)
.github/workflows/        budowanie w chmurze
```

## Budowanie bez Maca

Aplikację na iOS da się skompilować tylko na macOS, więc robi to GitHub Actions
przy każdym `git push` na gałąź `main`. Trzy zadania idą równolegle:

1. **Logika – testy na Linuksie:** `swift test` dla pakietu `AboutHerCore`.
2. **Aplikacja – AboutHer.ipa** (`macos-26`): generuje projekt XcodeGenem, buduje aplikację
   bez podpisu i pakuje ją do `AboutHer.ipa`.
3. **Zrzuty ekranu** (`macos-26`): uruchamia każdą zakładkę w symulatorze iPhone'a
   i zapisuje zrzuty jako artefakt `screenshots`.

Gdy testy logiki przejdą, a IPA się zbuduje, czwarte zadanie publikuje ją
w wydaniu **[najnowsza](https://github.com/HiramukaB/congenial-octo-system211934/releases/tag/najnowsza)**.
Aplikację podpisuje dopiero AltStore przy instalacji, darmowym Apple ID.

## Instalacja na iPhonie (AltStore + Windows)

**Jednorazowo**
1. Zainstaluj AltServer na Windowsie według [instrukcji AltStore](https://faq.altstore.io/).
   iTunes i iCloud muszą być pobrane ze strony Apple, nie z Microsoft Store.
2. Podłącz iPhone'a kablem, przez AltServer zainstaluj na nim AltStore i zaloguj się swoim Apple ID.
3. Na iPhonie:
   - włącz Tryb dewelopera (Ustawienia → Prywatność i ochrona; telefon się zrestartuje),
   - w Ustawienia → Ogólne → VPN i urządzenia zaufaj swojemu profilowi dewelopera.

**Instalacja i aktualizacje**
1. Na iPhonie otwórz w Safari
   [AboutHer.ipa z wydania najnowsza](https://github.com/HiramukaB/congenial-octo-system211934/releases/download/najnowsza/AboutHer.ipa).
   Plik trafi do Pobranych rzeczy.
2. W AltStore wybierz: Moje aplikacje → `+` i wskaż pobrany plik.
3. Nowa wersja instaluje się na starą, **dane zostają**.

**Co 7 dni** AltStore musi odświeżyć podpis. Robi to sam w tle, gdy telefon jest w tej samej sieci
Wi-Fi co komputer z włączonym AltServerem. Jeśli podpis wygaśnie, aplikacja się nie otworzy,
ale dane są bezpieczne – wystarczy odświeżyć.

> ⚠️ **Nie usuwaj aplikacji z telefonu.** Usunięcie kasuje jej dane.
> Aplikacja trzyma 14 dziennych kopii, ale na tym samym telefonie.

## Ograniczenia darmowego Apple ID

- Podpis jest ważny 7 dni.
- Z AltStore działają naraz maksymalnie 3 aplikacje (AltStore też się liczy).
- Nie działają iCloud, powiadomienia push ani (najpewniej) Apple Zdrowie.
- Działają: lokalne przypomnienia, widżety, Face ID, Skróty i przycisk Czynności.
- Płatne konto Apple Developer (99 USD/rok) znosi te limity.

## Dla dewelopera

- Testy logiki: `cd Packages/AboutHerCore && swift test` (Linux, macOS albo Docker z obrazem `swift`).
- Projekt Xcode na Macu: `brew install xcodegen && xcodegen generate`.
- Argumenty uruchomienia:
  - `-demoData` – fikcyjna historia, nic nie zapisuje;
  - `-startTab calendar` – otwiera wybraną zakładkę (`today`, `calendar`, `food`, `movement`, `me`).
