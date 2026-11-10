# -*- coding: utf-8 -*-
"""Runs the phrase sets through the mirror parser and reports the hit rate: a phrase is fully
recognised when the products come out in order, with the expected amount and unit (and grams) where
given, and nothing is left unknown.
  py -3 Tools/food/run_phrases.py [1] [2] [3] [4] [5] [6] [-v] [--repo]
Sets: 1 = phrases.py, 2 = phrases2.py, 3 = phrases3.py (the hit-rate sets), 4 = phrases4.py (fixes from
the food review, kept as regressions), 5 = phrases5.py (fresh phrases from the engine check), 6 =
phrases6.py (the parser review before 0.1.9, kept as regressions). All six when none is named.
The catalog is catalog_src.py as it is now (what --install would write); --repo uses the installed
FoodDB.json instead. -v also prints the phrases that pass."""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import meal_port as mp  # noqa: E402
import phrases  # noqa: E402
import phrases2  # noqa: E402
import phrases3  # noqa: E402
import phrases4  # noqa: E402
import phrases5  # noqa: E402
import phrases6  # noqa: E402
from paths import FOODDB as REPO  # noqa: E402


def foods_from_items(items):
    """mp.Food objects from FoodDB.json items (or catalog_src.ITEMS, which have the same shape)."""
    foods = []
    for it in items:
        m = it["per100"]
        foods.append(mp.Food(it["id"], it["name"], it["aliases"],
                             (float(m["kcal"]), float(m["protein"]), float(m["carbs"]), float(m["fat"])),
                             [(p["unit"], float(p["grams"])) for p in it["portions"]],
                             (it["defaultPortion"]["unit"], float(it["defaultPortion"]["grams"])),
                             category=it["category"], singular=it.get("singular")))
    return foods


def load_catalog(path):
    with open(path, encoding="utf-8") as f:
        return foods_from_items(json.load(f)["items"])


def source_catalog():
    """The catalog as catalog_src.py defines it now, before it is installed."""
    import catalog_src
    return foods_from_items(catalog_src.ITEMS)


def chosen_catalog(argv):
    return load_catalog(REPO) if "--repo" in argv else source_catalog()


def describe(items, unknown):
    parts = []
    for i in items:
        unit = "g" if i.unit is None else i.unit
        parts.append("%s %g %s (%gg%s)" % (i.food_id, i.amount, unit, i.grams, "?" if i.is_guess else ""))
    if unknown:
        parts.append("UNKNOWN %r" % unknown)
    return "; ".join(parts)


def check(parser, text, want, want_unknown):
    items, unknown, _ = parser.parse(text)
    ok = len(items) == len(want) and unknown == want_unknown
    if ok:
        for got, w in zip(items, want):
            if isinstance(w, str):
                guess = w.startswith("?")
                ok = ok and got.food_id == w.lstrip("?") and got.is_guess == guess
            else:
                wid, amount, unit = w[:3]
                ok = ok and got.food_id == wid and abs(got.amount - amount) < 1e-9 and got.unit == unit \
                    and not got.is_guess
                # ("id", amount, unit, grams) pins the weight too.
                if len(w) > 3:
                    ok = ok and abs(got.grams - w[3]) < 1e-9
    return ok, items, unknown


def main():
    parser = mp.Parser(chosen_catalog(sys.argv))
    verbose = "-v" in sys.argv
    sets = {"1": phrases.P, "2": phrases2.P, "3": phrases3.P, "4": phrases4.P, "5": phrases5.P,
            "6": phrases6.P}
    chosen = [a for a in sys.argv[1:] if a in sets] or sorted(sets)
    hits = total = 0
    per_set = []
    for name in chosen:
        set_hits = 0
        for text, want, want_unknown in sets[name]:
            ok, items, unknown = check(parser, text, want, want_unknown)
            set_hits += ok
            if not ok or verbose:
                print("%s %-50s -> %s" % ("OK  " if ok else "MISS", text, describe(items, unknown)))
                if not ok:
                    print("     want %r%s" % (want, (" unknown %r" % want_unknown) if want_unknown else ""))
        per_set.append("set %s %d/%d" % (name, set_hits, len(sets[name])))
        hits += set_hits
        total += len(sets[name])
    print("hit rate: %d / %d (%s)" % (hits, total, ", ".join(per_set)))


if __name__ == "__main__":
    main()
