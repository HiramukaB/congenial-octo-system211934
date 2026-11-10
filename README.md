# about her

Natywna aplikacja na iPhone'a (iOS 26+, docelowo iPhone 16 Pro), następczyni wersji HTML.
Cykl, jedzenie, ruch, sen i wnętrze w jednym miejscu, w zgodzie z rytmem cyklu i bez presji.

> **Prywatność:** dane zostają w telefonie. W repozytorium nie ma danych osobowych:
> `about-her.html`, `transkrypt.txt` i kopie JSON są w `.gitignore`.

## Stan

| Część | Status |
|---|---|
| Design system: kolory, gwiazdka, animowane tło, karty | gotowe |
| 5 zakładek: dziś · kalendarz · jedzenie · ruch · ja | gotowe |
| Cykl: kalendarz okresu, fazy z poziomem pewności, prognoza, spóźnienia, plamienia | gotowe |
| Zapis danych (plik JSON) z dziennymi kopiami i odtwarzaniem z kopii | gotowe |
| Ikona aplikacji (`Tools/make_app_icon.py`) | gotowe |
| Jedzenie: posiłki wpisywane zwykłym tekstem (polski parser, baza produktów na 100 g, uczenie nowych produktów), bilans dnia z celami z profilu, woda, waga z linią trendu | gotowe |
| Przepisy dopasowane do fazy, plan tygodnia, zakupy | w budowie |
| Samopoczucie, przypomnienia, blokada Face ID, ruch, wnętrze, list do siebie, zdjęcia, chwila dla siebie | wersja podstawowa |
| Powitanie przy pierwszym otwarciu (imię, cykl, liczby, cele, przypomnienia, Face ID) i samouczek | gotowe |
| Humor: żarty i zabawne cytaty, losowanie, „coś na uśmiech” na „dziś” | gotowe |
| Wygląd 0.3: stały pasek zakładek, skale przeciągane 1–10, duże kafelki, krótsze teksty | gotowe |

## Struktura

```
App/                      aplikacja SwiftUI
  DesignSystem/           kolory, typografia, gwiazdka, animowane tło, karty
  Features/               ekrany wszystkich zakładek i ekrany „ja”
  Store/                  stan aplikacji i zapis do pliku
  System/                 blokada Face ID i przypomnienia
Packages/AboutHerCore/    logika bez interfejsu (daty, cykl, jedzenie, ruch, przypomnienia, dane) + testy
Tools/food/               źródło bazy produktów i parser posiłków w Pythonie (sprawdzanie bez Swifta)
UITests/                  zrzuty ekranu zakładek, ekranów „ja”, powitania i samouczka, test zapisu danych
project.yml               definicja projektu dla XcodeGen (.xcodeproj się generuje)
.github/workflows/        budowanie w chmurze
```

## Budowanie bez Maca

Aplikację na iOS da się skompilować tylko na macOS, więc robi to GitHub Actions
przy każdym `git push` na gałąź `main`. Trzy zadania idą równolegle:

1. **Logika – testy na Linuksie:** `swift test` dla pakietu `AboutHerCore`.
2. **Aplikacja – AboutHer.ipa** (`macos-26`): generuje projekt XcodeGenem, buduje aplikację
   bez podpisu i pakuje ją do `AboutHer.ipa`. Wersja to `0.1.<numer przebiegu>`.
3. **Zrzuty ekranu** (`macos-26`): uruchamia każdą zakładkę w symulatorze iPhone'a,
   zapisuje zrzuty jako artefakt `screenshots` i sprawdza, że zaznaczony dzień
   przetrwa ponowne uruchomienie aplikacji, a powitanie da się przejść do końca.

Gdy wszystkie trzy przejdą, czwarte zadanie publikuje IPA
w wydaniu **[najnowsza](https://github.com/HiramukaB/congenial-octo-system211934/releases/tag/najnowsza)**.
Aplikację podpisuje dopiero AltStore przy instalacji, darmowym Apple ID.

## Instalacja na iPhonie (AltStore + Windows)

**Jednorazowo**
1. Zainstaluj AltServer dla Windows – AltStore Classic, nie AltStore PAL, w wersji 1.7.4 lub nowszej –
   według [instrukcji AltStore dla Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
   iTunes i iCloud muszą być pobrane ze strony Apple, nie z Microsoft Store.
2. Podłącz iPhone'a kablem, odblokuj go i stuknij „Zaufaj”, jeśli zapyta o ten komputer.
   W iTunes kliknij przycisk iPhone'a (lewy górny róg) → Podsumowanie, zaznacz
   „Synchronizuj z tym iPhone'em przez Wi-Fi” i kliknij **Zastosuj**. Bez tego AltServer
   nie zobaczy telefonu przez Wi-Fi i odświeżanie w tle nie zadziała.
3. Kliknij ikonę AltServera w zasobniku → Install AltStore → swój iPhone i zaloguj się swoim Apple ID.
   AltServer zostaw włączony (najlepiej uruchamiany razem z Windowsem).
4. Na iPhonie:
   - w Ustawienia → Ogólne → VPN i urządzenia zarządzane stuknij swój Apple ID i wybierz „Zaufaj”,
   - włącz Tryb dewelopera (Ustawienia → Prywatność i ochrona → Tryb dewelopera). Telefon się
     zrestartuje; po restarcie odblokuj go i potwierdź włączenie kodem.

**Instalacja i aktualizacje**
1. Na iPhonie otwórz w Safari
   [AboutHer.ipa z wydania najnowsza](https://github.com/HiramukaB/congenial-octo-system211934/releases/download/najnowsza/AboutHer.ipa).
   Plik trafi do Pobranych rzeczy.
2. Komputer z AltServerem musi być włączony i w tej samej sieci Wi-Fi co iPhone (albo iPhone
   podłączony do niego kablem) – inaczej AltStore pokaże błąd „AltServer could not be found”.
   W AltStore wybierz Moje aplikacje (My Apps) → `+` i wskaż pobrany plik.
3. Nowa wersja instaluje się na starą i **dane zostają**, o ile AltStore jest zalogowany tym samym
   Apple ID co przy pierwszej instalacji. Z innym Apple ID pojawi się druga, pusta kopia aplikacji –
   nie usuwaj wtedy starej (to w niej są dane), tylko zaloguj AltStore z powrotem pierwotnym
   Apple ID i zainstaluj plik jeszcze raz.
4. Numer wersji jest na dole zakładki „ja” i w tytule wydania. Po instalacji usuń pobrany plik
   z Pobranych rzeczy, żeby przy następnej aktualizacji nie wybrać starego.

**Co 7 dni** AltStore musi odświeżyć podpis – swój i tej aplikacji. Robi to w tle, gdy komputer
z działającym AltServerem jest w tej samej sieci Wi-Fi. Dla pewności raz na kilka dni, będąc w domu,
otwórz AltStore → Moje aplikacje (My Apps) → Refresh All. Jeśli podpis wygaśnie, aplikacja się
nie otworzy, ale dane są bezpieczne – odśwież ją w AltStore. Jeśli nie otwiera się też sam AltStore,
podłącz iPhone'a kablem i w AltServerze wybierz ponownie Install AltStore (nie usuwa aplikacji
ani danych, jeśli to ten sam Apple ID), a potem w AltStore Refresh All.

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
- Baza produktów (`FoodDB.json`) jest generowana z `Tools/food/catalog_src.py`, a zmiany parsera
  posiłków idą krok w krok z `Tools/food/meal_port.py` – szczegóły i sprawdzenia przed commitem
  w [Tools/food/README.md](Tools/food/README.md).
- Zasady wyglądu i komponenty wspólne dla wszystkich ekranów: [App/DesignSystem/DESIGN.md](App/DesignSystem/DESIGN.md).
- Argumenty uruchomienia:
  - `-demoData` – fikcyjna historia, nic nie zapisuje (powitanie uznane za ukończone);
  - `-showOnboarding` – powitanie (pierwsza konfiguracja) na fikcyjnej historii, do zrzutów ekranu;
  - `-skipOnboarding` – bez powitania, np. w teście zapisu danych na czystym symulatorze;
  - `-startTab calendar` – otwiera wybraną zakładkę (`today`, `calendar`, `food`, `movement`, `me`);
  - `-stillBackground` – nieruchome tło (testy UI: animowane tło nie pozwala aplikacji „odpocząć”,
    przez co automatyczne dotknięcia są wolne i niestabilne).
- Zapis danych: plik `Application Support/AboutHer/about-her.json`, kopie w `Kopie/`.
  Dopóki plik nie zostanie odczytany, aplikacja niczego nie zapisuje (np. zaraz po restarcie
  telefonu, przed pierwszym odblokowaniem). Uszkodzony plik jest odkładany na bok, a dane
  wracają z najnowszej dobrej kopii. Plik z nowszej wersji (z wyższym `schemaVersion`, z nieznanym
  polem na najwyższym poziomie albo poprawny JSON, którego nie da się odczytać, np. przez nową wartość
  wyliczenia) starsza wersja otwiera tylko do odczytu i nigdy go nie nadpisuje. Nieznanych pól głębiej
  w pliku nie zauważa, dlatego każde nowe pole i każda nowa wartość wyliczenia, także zagnieżdżone,
  wymagają podniesienia `schemaVersion`.
- Zdjęcia postępów: pliki JPEG w `Application Support/AboutHer/Zdjecia/`, obok pliku danych, ale poza
  nim i poza dziennymi kopiami – usunięcie aplikacji je kasuje, a po wczytaniu kopii wpis może wskazywać
  brakujące zdjęcie (aplikacja pokazuje wtedy łagodny zastępnik).
