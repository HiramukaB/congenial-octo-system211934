# Tools/food – baza produktów i parser posiłków

Skrypty w Pythonie 3 (bez dodatkowych pakietów) do bazy produktów i do sprawdzania parsera posiłków
bez Swifta. Każdy działa z dowolnego katalogu, np. z głównego katalogu repozytorium:
`py -3 Tools/food/<skrypt>.py`.

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
- w aliasie nie ma słów, których parser nigdy nie bierze za nazwę (liczby, jednostki, „ok.”, „z grilla” …).

## Parser

`meal_port.py` to wierne, linijka po linijce, odbicie `Food/MealParser.swift` (i `FoodItem.grams(per:)`
z `FoodModels.swift`). **Musi iść krok w krok ze Swiftem**: każda zmiana reguły albo listy słów
w `MealParser.swift` dostaje tę samą zmianę w `meal_port.py`, w tym samym commicie. Inaczej poniższe
sprawdzenia przestają cokolwiek znaczyć.

| Skrypt | Co robi |
|---|---|
| `compare_tables.py` | porównuje listy słów (liczby, jednostki, końcówki, słowa łączące …) w Swifcie i w `meal_port.py` |
| `check_swift_tests.py` | czyta każde oczekiwanie z `MealParserTests.swift` (fikstura i baza wbudowana) i przepuszcza je przez `meal_port.py` |
| `run_fixture_tests.py` | to samo tylko dla zestawów z fikstury |
| `run_phrases.py` | odsetek trafień na zestawach zdań: `phrases.py`, `phrases2.py`, `phrases3.py` (wymyślone wpisy), `phrases4.py` (poprawki z przeglądu jedzenia) i `phrases5.py` (świeże zdania z kontroli silnika), dwa ostatnie jako testy regresji |
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
py -3 Tools/food/run_phrases.py
```

Pierwsze trzy kończą się bez błędów. W `run_phrases.py` żadne zdanie, które przechodziło,
nie może zacząć chybiać; każdą zmienioną odpowiedź trzeba umieć wyjaśnić. Po zmianie reguł
w parserze trzeba też puścić `fuzz.py`: 0 błędów.
