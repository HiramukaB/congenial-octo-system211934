# Tools/food – baza produktów i parser posiłków

Skrypty w Pythonie 3 (bez dodatkowych pakietów) do bazy produktów i do sprawdzania parsera posiłków
bez Swifta. Każdy działa z dowolnego katalogu, np. z głównego katalogu repozytorium:
`py -3 Tools/food/<skrypt>.py` (z `-B` nie powstaje `__pycache__`).

## Baza produktów

`Packages/AboutHerCore/Sources/AboutHerCore/Resources/FoodDB.json` jest **generowany** z `catalog_src.py`.
Nie edytuj go ręcznie: każda zmiana idzie do `catalog_src.py`, a potem

```
py -3 Tools/food/build_catalog.py --install
```

| Skrypt | Co robi |
|---|---|
| `catalog_src.py` | źródło bazy: produkty, aliasy, wartości na 100 g (100 ml dla napojów), porcje, tagi |
| `build_catalog.py` | sprawdza bazę; `--install` zapisuje `FoodDB.json` do pakietu, `--check` sprawdza, czy zapisany plik jest dokładnie tym, co wychodzi z `catalog_src.py` |
| `collisions.py` | odmienia jednowyrazowe aliasy i pokazuje formy, które zabiera inny produkt |

Zasady bazy (pilnuje ich `build_catalog.py` i testy Swifta w zestawie „Meal parser with the built-in catalog”):

- wartości na 100 g, napoje na 100 ml;
- kasze, ryż i makaron ugotowane, chyba że alias mówi inaczej („ryż suchy”, „makaron na sucho”);
- chude mięso (pierś z kurczaka, pierś z indyka, polędwiczka) gotowe do jedzenia; surowe to osobne produkty („pierś z kurczaka surowa”);
- każdy alias ma co najmniej 3 litery i należy do jednego produktu;
- `singular` (opcjonalne) to nazwa lub aliasy, które znaczą jedną sztukę („naleśnik”, „pieróg ruski”):
  bez liczby to jedna sztuka, a liczba mnoga („naleśniki”) to porcja; wpisuje się tylko własne nazwy produktu,
  który domyślnie liczy się w sztukach;
- kcal zgadzają się z makro (4 / 4 / 9) z tolerancją 15 % (najmniej 15 kcal), poza alkoholem;
- w aliasie nie ma słów, których parser nigdy nie bierze za nazwę (liczby, jednostki, „ok.”, „z grilla”,
  „różyczki”, „krążki”, „cząstki” …);
- przekąska w misce lub kubku ma własną porcję, a orzechy, pestki i bakalie także w szklance („miseczka lodów”
  150 g, „miseczka żelków” 60 g, „kubek płatków” 110 g, „kubek migdałów” 150 g, „szklanka orzechów” 125 g),
  bo bez niej miska to 350 g, szklanka 250 g, a kubek 300 g jak zupa albo napój;
- żadne gołe słowo z etykiety nie jest aliasem („protein” było odżywką białkową w „mleko protein 500 ml”);
  odżywka to „proteina”, a „protein” jest w parserze fałszywym przyjacielem, żeby nie czytać go jak jej formy;
- częsta literówka w nazwie marki jest aliasem („nutela”, „snikers”), bo słowo z wielkiej litery po innym
  słowie („kanapka z Nutelą”) nie dostaje zgadywania literówek, tak jak imię („kawa z Kasią”).

## Parser

`meal_port.py` to wierne, linijka po linijce, odbicie `Food/MealParser.swift` (i `FoodItem.grams(per:)`
z `FoodModels.swift`). **Musi iść krok w krok ze Swiftem**: każda zmiana reguły albo listy słów
w `MealParser.swift` dostaje tę samą zmianę w `meal_port.py`, w tym samym commicie. Inaczej poniższe
sprawdzenia przestają cokolwiek znaczyć.

| Skrypt | Co robi |
|---|---|
| `compare_tables.py` | porównuje listy słów i stałe w Swifcie i w `meal_port.py` (liczby, jednostki, końcówki, słowa łączące, godziny, składniki pomijane po „bez … i”, napoje do mleka, wartości z etykiet, sok z owocu, krojenie przed „na pół” …: 47 tabel); zgłasza też tabelę z `MealWords`, której nie porównuje |
| `check_swift_tests.py` | czyta każde oczekiwanie z `MealParserTests.swift` (fikstura i baza wbudowana) i przepuszcza je przez `meal_port.py` |
| `run_fixture_tests.py` | to samo tylko dla zestawów z fikstury |
| `run_phrases.py` | odsetek trafień na zestawach zdań: `phrases.py`, `phrases2.py`, `phrases3.py` (wymyślone wpisy), `phrases4.py` (poprawki z przeglądu jedzenia), `phrases5.py` (świeże zdania z kontroli silnika) i `phrases6.py` (przegląd parsera przed 0.1.9 i przegląd jego poprawek: zdania z uwag i podobne, których poprawki nie mogą ruszyć), trzy ostatnie jako testy regresji; pozycja `("id", ilość, jednostka, gramy)` pilnuje też gramów |
| `probe.py` | pokazuje, co parser robi z podanymi zdaniami, z sumą kcal |
| `fuzz.py` | 50 000 losowych i złośliwych wpisów (długie wklejki, emoji, tekst NFD, ogromne liczby, godziny, ciągi znaków interpunkcyjnych): szuka miejsc, w których Swift by się wysypał (indeks poza tablicą, zły zakres), niepoliczalnych gramów i bardzo wolnych wpisów; trwa kilka minut |
| `emit_swift.py` | wypisuje linijki `typed(...)` do `MealParserTests.swift` (każdą trzeba sprawdzić ręcznie) |
| `paths.py` | ścieżki w repozytorium, liczone od tego katalogu |

`run_phrases.py`, `probe.py` i `collisions.py` biorą bazę prosto z `catalog_src.py`, więc zmianę
widać przed `--install`; z `--repo` czytają zapisany `FoodDB.json`.

## Przed commitem

```
py -3 Tools/food/build_catalog.py --check
py -3 Tools/food/compare_tables.py
py -3 Tools/food/check_swift_tests.py
py -3 Tools/food/run_fixture_tests.py
py -3 Tools/food/run_phrases.py
py -3 Tools/food/run_phrases.py --repo
py -3 Tools/food/fuzz.py 50000 7
```

Pierwsze cztery kończą się bez błędów (w 0.1.9: 47 tabel bez różnic, 312 oczekiwań z fikstury i 210 z bazy
wbudowanej). W `run_phrases.py` (1226 zdań w sześciu zestawach, z obiema bazami) żadne zdanie, które
przechodziło, nie może zacząć chybiać; każdą zmienioną odpowiedź trzeba umieć wyjaśnić. Po zmianie reguł
w parserze trzeba też puścić `fuzz.py`: 0 błędów.

## Znane ograniczenia

Zostały świadomie, po przeglądzie parsera przed 0.1.9:

- „kawa bez cukru, mleka i miodu” – „bez” nie sięga za przecinek, więc mleko i miód się liczą; fragment po
  przecinku ciągnie danie sprzed niego tylko wtedy, gdy zaczyna się od „z” i ilości albo jedzenia w formie
  po „z” („kawa z cukrem, z mlekiem”, „jajecznica, z 3 jajek”), a nie od imienia („Z Kasią kawa z mlekiem”);
- „sok wyciskany z 3 pomarańczy” – szklanka soku i trzy pomarańcze, bo liczba nie stoi w środku aliasu
  („sok z 3 pomarańczy” to 240 ml soku);
- „maki z łososiem 8 sztuk” – „maki” czyta się jak „mąki”, więc to łyżka mąki i 8 porcji łososia;
- „pizza na pół z szynką” – „na pół” przed dodatkiem dzieli tylko to, co było przed nim; po słowie
  o krojeniu („przekrojona”, „pokroiłam”, „złożony”) „na pół” niczego nie dzieli;
- „uszka ruskie”, „placki ruskie” – dodają porcję pierogów ruskich („ruskie” po daniu to danie); jedno danie
  to tylko „krokiety ruskie” i „naleśniki ruskie”, które mają własne aliasy;
- „kotlety z cukinii” – to wciąż schabowy z cukinią, bo „kotlet z cukinią” to zwykle schabowy z warzywem;
- „z kasią” małą literą – wciąż zgaduje kaszę; imię rozpoznaje tylko wielka litera w środku zdania („z Kasią”);
- „około 8 owsianka” – bez słowa o posiłku („rano”, „śniadanie” …) 8 to nadal 8 misek;
- „krążki cebulowe” – nieznane, do nauczenia jako „cebulowe”, bo „krążki” to jednostka.
