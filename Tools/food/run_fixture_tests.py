# -*- coding: utf-8 -*-
"""Reads the fixture and every expectation straight out of MealParserTests.swift (not from the
Python tables) and checks them against meal_port.py, the line-by-line mirror of MealParser.swift.
Also recomputes each expected gram value from the fixture by hand: grams = amount (no unit) or
amount x the item's weight of that unit. Fixture suites only; check_swift_tests.py also runs the
built-in catalog suite.
  py -3 Tools/food/run_fixture_tests.py"""
import re
import sys
import os

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meal_port as sp  # noqa: E402

from paths import MEAL_PARSER_TESTS as TESTS  # noqa: E402

with open(TESTS, encoding="utf-8") as _f:
    src = _f.read()


def swift_to_python(code):
    """Converts the literal-only Swift used in the tables into a Python expression."""
    out = []
    i = 0
    while i < len(code):
        c = code[i]
        if c == '"':
            j = i + 1
            while code[j] != '"':
                if code[j] == "\\":
                    j += 1
                j += 1
            out.append(code[i:j + 1])
            i = j + 1
            continue
        if c == "/" and code.startswith("//", i):
            while i < len(code) and code[i] != "\n":
                i += 1
            continue
        m = re.match(r"\.([A-Za-z][A-Za-z0-9]*)", code[i:])
        if m and (i == 0 or not (code[i - 1].isalnum() or code[i - 1] in ")]_")):
            out.append('"%s"' % m.group(1))
            i += m.end()
            continue
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*:(?!:)", code[i:])
        if m and (i == 0 or not code[i - 1].isalnum()):
            out.append(m.group(1) + "=")
            i += m.end()
            continue
        m = re.match(r"\b(nil|true|false)\b", code[i:])
        if m and (i == 0 or not code[i - 1].isalnum()):
            out.append({"nil": "None", "true": "True", "false": "False"}[m.group(1)])
            i += m.end()
            continue
        out.append(c)
        i += 1
    return "".join(out)


def food(id, name, aliases, category, kcal, protein, carbs, fat, unit, grams, portions=(), tags=(), singular=None):
    return sp.Food(id, name, aliases, (float(kcal), float(protein), float(carbs), float(fat)),
                   [(u, float(g)) for (u, g) in portions], (unit, float(grams)), category=category,
                   singular=None if singular is None else list(singular))


def parsedAs(foodID, amount, unit, grams, guess=False):
    return (foodID, float(amount), unit, float(grams), guess)


def typed(text, items, unknown=()):
    return (text, list(items), list(unknown))


def CleanedNameCase(fragment, name):
    return (fragment, name)


def block(start_marker, end_marker):
    a = src.index(start_marker)
    b = src.index(end_marker, a)
    return src[a:b]


# Fixture
fx = block("static let items: [FoodItem] = [", "    ]\n")
fx = fx[fx.index("[", fx.index("=")):] + "]"
FIX = eval(swift_to_python(fx))
print("fixture items:", len(FIX))
by_id = {f.id: f for f in FIX}

# Phrase tables of the fixture suites (BuiltInMealPhrases runs against FoodDB.json: check_swift_tests.py)
tables = {}
BUILTIN_AT = src.find("enum BuiltInMealPhrases")
for m in re.finditer(r"static let (\w+): \[MealPhrase\] = \[", src):
    if 0 <= BUILTIN_AT < m.start():
        continue
    start = m.end() - 1
    depth = 0
    i = start
    while True:
        ch = src[i]
        if ch == '"':
            i += 1
            while src[i] != '"':
                if src[i] == "\\":
                    i += 1
                i += 1
        elif ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                break
        i += 1
    tables[m.group(1)] = eval(swift_to_python(src[start:i + 1]))
print({k: len(v) for k, v in tables.items()}, "total", sum(len(v) for v in tables.values()))

cm = re.search(r"static let cleanedNames: \[CleanedNameCase\] = (\[.*?\n    \])", src, re.S)
CLEAN = eval(swift_to_python(cm.group(1)))
print("cleaned cases:", len(CLEAN))



def main():
    global failures
    failures = 0


    def fail(msg):
        global failures
        failures += 1
        print("FAIL", msg)


    def check(parser, case, catalog_by_id):
        text, want, want_unknown = case
        items, unknown, totals = parser.parse(text)
        got = [(i.food_id, i.amount, i.unit, i.grams, i.is_guess) for i in items]
        if [g[0] for g in got] != [w[0] for w in want]:
            fail("%r ids %r want %r" % (text, got, want))
        if unknown != want_unknown:
            fail("%r unknown %r want %r" % (text, unknown, want_unknown))
        for g, w in zip(got, want):
            if abs(g[1] - w[1]) >= 1e-9 or g[2] != w[2] or abs(g[3] - w[3]) >= 1e-9 or g[4] != w[4]:
                fail("%r item %r want %r" % (text, g, w))
        # independent arithmetic of the expectation itself
        for w in want:
            f = catalog_by_id[w[0]]
            expect_grams = w[1] if w[2] is None else w[1] * f.grams_per(w[2])
            if abs(expect_grams - w[3]) >= 1e-9:
                fail("%r expectation arithmetic %r -> %r" % (text, w, expect_grams))
        # totals == sum of items (same order) and each item's macros follow from its grams
        s = (0.0, 0.0, 0.0, 0.0)
        for it in items:
            s = tuple(a + b for a, b in zip(s, it.macros))
            if it.macros != catalog_by_id[it.food_id].macros(it.grams):
                fail("%r macros" % text)
        if s != totals:
            fail("%r totals" % text)


    parser = sp.Parser(FIX)
    for name, cases in tables.items():
        for case in cases:
            check(parser, case, by_id)

    # withoutALatteProductCoffeeWithMilkIsTwoItems (the expectation is read from the Swift test)
    no_latte = sp.Parser([f for f in FIX if f.id != "kawa-z-mlekiem"])
    latte = re.search(r"func withoutALatteProductCoffeeWithMilkIsTwoItems\(\) \{(.*?)\n    \}\n", src, re.S).group(1)
    latte_cases = re.findall(r"expectParse\((typed\(.*?\)),\s*with: MealParser", latte, re.S)
    if len(latte_cases) != 1:
        fail("withoutALatteProductCoffeeWithMilkIsTwoItems: %d cases" % len(latte_cases))
    for c in latte_cases:
        check(no_latte, eval(swift_to_python(c)), by_id)

    for fragment, want in CLEAN:
        got = parser.cleaned_name(fragment)
        if got != want:
            fail("cleanedName %r -> %r want %r" % (fragment, got, want))

    for text in ["", "   ", "\n \t ", ", ;", " i  z "]:
        items, unknown, totals = parser.parse(text)
        if items or unknown or totals != (0, 0, 0, 0):
            fail("blank %r" % text)

    # herProductsWinOverTheCatalog
    cheese = sp.Food("user-ser", "ser", [], (300.0, 20.0, 1.0, 24.0), [], ("thinSlice", 20.0), category="dairy")
    pierogi = sp.Food("user-pierogi", "pierogi ruskie", ["pierogi", "pierogów"], (200.0, 6.0, 30.0, 6.0), [], ("piece", 40.0),
                      category="dishes")
    dish = sp.Food("user-pierogi-z-miesem", "pierogi z mięsem", [], (230.0, 10.0, 28.0, 8.0), [], ("serving", 250.0),
                   category="dishes")
    taught = sp.Parser(FIX, [cheese, pierogi, dish])
    all_by_id = dict(by_id)
    all_by_id.update({f.id: f for f in (cheese, pierogi, dish)})
    her = re.search(r"func herProductsWinOverTheCatalog\(\) \{(.*?)\n    \}\n", src, re.S).group(1)
    her_cases = re.findall(r"expectParse\((typed\(.*?\)),\s*with: taught\)", her, re.S)
    print("her-products cases:", len(her_cases))
    for c in her_cases:
        check(taught, eval(swift_to_python(c)), all_by_id)

    # macrosFollowFromTheGramsAndAddUp
    items, unknown, totals = parser.parse("trzy jajka, łyżeczka masła, kromka chleba żytniego")
    if abs(totals[0] - (231 + 36.75 + 90)) >= 1e-9:
        fail("kcal total %r" % totals[0])
    print("kcal total", totals[0], "exact 357.75?", totals[0] == 357.75)

    # eachItemKeepsTheTextAsTyped
    items, unknown, totals = parser.parse("Trzy JAJKA,  kromka chleba żytniego\n2 x 50g sera")
    if [i.text for i in items] != ["Trzy JAJKA", "kromka chleba żytniego", "2 x 50g sera"]:
        fail("texts %r" % [i.text for i in items])
    if [i.food_name for i in items] != ["jajko", "chleb żytni", "ser żółty"]:
        fail("names %r" % [i.food_name for i in items])

    # roundTripsThroughJSON
    items, unknown, totals = parser.parse("100 g ryżu, 6 pierogów")
    print("json phrase:", items, unknown, [i.macros for i in items], totals)
    if unknown != ["pierogów"]:
        fail("json unknown %r" % unknown)

    # editDistanceCountsASwapAsOne
    for a, b, d in [("kurczka", "kurczak", 1), ("bannan", "banan", 1), ("deser", "ser", 2), ("", "ser", 3)]:
        if sp.edit_distance(list(a), list(b)) != d:
            fail("edit %s %s" % (a, b))

    print("failures:", failures)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
