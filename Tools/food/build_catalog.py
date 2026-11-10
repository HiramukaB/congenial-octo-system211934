# -*- coding: utf-8 -*-
"""Validates catalog_src.ITEMS and writes the package's FoodDB.json (generated: never edit it by hand).
  py -3 Tools/food/build_catalog.py            -> validate only
  py -3 Tools/food/build_catalog.py --install  -> validate, then write Packages/.../Resources/FoodDB.json
  py -3 Tools/food/build_catalog.py --check    -> validate, and fail if the installed file is not what
                                                  catalog_src.py generates
Rules (same as the Swift catalog tests): Codable shape and enum values; unique ids; every normalized
alias (name included) belongs to exactly one product and has at least 3 letters; no alias word the
parser can never match (amount, unit, filler or cooking words); |kcal - (4P + 4C + 9F)| <= max(15, 15 % of kcal)
except alcoholic drinks; non-negative values; positive portion weights; the optional "singular" (the forms
that mean one piece) lists only the product's own name or aliases, written as they are."""
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog_src  # noqa: E402
import meal_port as mp  # noqa: E402
from paths import FOODDB as REPO, ROOT  # noqa: E402

UNITS = ["piece", "slice", "thinSlice", "tablespoon", "teaspoon", "glass", "mug", "handful", "serving", "bowl",
         "can", "package", "chunk", "clove"]
CATEGORIES = ["bread", "dairy", "eggs", "meat", "fish", "legumes", "grains", "fats", "nuts", "fruit", "vegetables",
              "sweets", "drinks", "dishes", "other"]
TAGS = ["protein", "iron", "magnesium", "fiber", "omega3", "calcium"]
ALCOHOL = {"wino", "piwo", "wodka", "drink"}
KEYS = ["id", "name", "aliases", "category", "per100", "portions", "defaultPortion", "tags"]
# FoodItem.singular is optional (her own products and older files have none): written only when there is one.
OPTIONAL_KEYS = ["singular"]


def key_of(phrase):
    return " ".join(mp.MealText.words(phrase))


def energy_ok(m):
    implied = 4 * m["protein"] + 4 * m["carbs"] + 9 * m["fat"]
    return abs(m["kcal"] - implied) <= max(15.0, 0.15 * m["kcal"]), implied


def validate(items):
    errors = []
    ids = set()
    owner = {}
    for it in items:
        keys = list(it.keys())
        if keys[:len(KEYS)] != KEYS or any(k not in OPTIONAL_KEYS for k in keys[len(KEYS):]):
            errors.append("%s keys %r" % (it.get("id"), keys))
        iid = it["id"]
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", iid):
            errors.append("bad id %r" % iid)
        if iid in ids:
            errors.append("duplicate id %r" % iid)
        ids.add(iid)
        if it["category"] not in CATEGORIES:
            errors.append("%s category %r" % (iid, it["category"]))
        for t in it["tags"]:
            if t not in TAGS:
                errors.append("%s tag %r" % (iid, t))
        if len(set(it["tags"])) != len(it["tags"]):
            errors.append("%s duplicate tags" % iid)
        m = it["per100"]
        if list(m.keys()) != ["kcal", "protein", "carbs", "fat"]:
            errors.append("%s per100 keys" % iid)
        if any((not isinstance(v, (int, float))) or v < 0 for v in m.values()):
            errors.append("%s negative or non-number macros" % iid)
        if m["protein"] + m["carbs"] + m["fat"] > 100:
            errors.append("%s more than 100 g of macros" % iid)
        ok, implied = energy_ok(m)
        if iid in ALCOHOL:
            if m["kcal"] < implied:
                errors.append("%s alcohol below macros" % iid)
        elif not ok:
            errors.append("%s energy %s vs 4/4/9 %.1f" % (iid, m["kcal"], implied))
        portions = [it["defaultPortion"]] + it["portions"]
        seen_units = {}
        for p in portions:
            if list(p.keys()) != ["unit", "grams"]:
                errors.append("%s portion keys" % iid)
            if p["unit"] not in UNITS:
                errors.append("%s unit %r" % (iid, p["unit"]))
            if not (isinstance(p["grams"], (int, float)) and p["grams"] > 0):
                errors.append("%s grams %r" % (iid, p["grams"]))
            if p["unit"] in seen_units:
                errors.append("%s unit %s listed twice" % (iid, p["unit"]))
            seen_units[p["unit"]] = p["grams"]
        own = set()
        for phrase in [it["name"]] + it["aliases"]:
            words = mp.MealText.words(phrase)
            k = " ".join(words)
            letters = sum(len(w) for w in words)
            if letters < 3:
                errors.append("%s alias %r shorter than 3 letters" % (iid, phrase))
            if k in own:
                errors.append("%s alias %r repeats another form of the same product" % (iid, phrase))
            own.add(k)
            if k in owner and owner[k] != iid:
                errors.append("alias %r of %s already belongs to %s" % (phrase, iid, owner[k]))
            owner.setdefault(k, iid)
            for w in words:
                # A one-word unit name ("pączek" ~ "paczek") is still found: the parser falls back to unit words.
                if mp.is_never_name(w) and not (len(words) == 1 and w in mp.UNITS):
                    errors.append("%s alias %r has the never-a-name word %r" % (iid, phrase, w))
            if words and (mp.is_joining(words[0]) or mp.is_joining(words[-1]) or words[0] == mp.NEG):
                errors.append("%s alias %r starts or ends with a joining word" % (iid, phrase))
            if phrase != phrase.strip() or "  " in phrase:
                errors.append("%s alias %r spacing" % (iid, phrase))
        if "singular" in it:
            singular = it["singular"]
            # The parser takes the default portion for these only when one matches exactly, so each must be
            # one of the product's own phrases ("naleśnik"), not a form the endings find.
            if not (isinstance(singular, list) and singular and all(isinstance(w, str) for w in singular)):
                errors.append("%s singular %r" % (iid, singular))
            else:
                if len(set(singular)) != len(singular):
                    errors.append("%s singular lists a form twice" % iid)
                if it["defaultPortion"]["unit"] != "piece":
                    errors.append("%s singular without a piece as the default portion" % iid)
                for phrase in singular:
                    if phrase not in [it["name"]] + it["aliases"]:
                        errors.append("%s singular %r is not its name or an alias" % (iid, phrase))
    return errors


def dump(items):
    lines = ['{', '  "version": 1,', '  "items": [']
    for n, it in enumerate(items):
        line = "    " + json.dumps(it, ensure_ascii=False, separators=(", ", ": "))
        lines.append(line + ("," if n + 1 < len(items) else ""))
    lines += ['  ]', '}', '']
    return "\n".join(lines)


def main():
    items = catalog_src.ITEMS
    errors = validate(items)
    for e in errors:
        print("ERROR", e)
    text = dump(items)
    data = json.loads(text)
    assert data["items"] == items
    aliases = sum(1 + len(it["aliases"]) for it in items)
    print("items:", len(items), "names+aliases:", aliases, "errors:", len(errors), "bytes:", len(text.encode("utf-8")))
    shown = os.path.relpath(REPO, ROOT).replace(os.sep, "/")
    if "--install" in sys.argv:
        if errors:
            print("not installed: fix the errors first")
            sys.exit(1)
        with open(REPO, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("installed", shown)
    elif "--check" in sys.argv:
        with open(REPO, encoding="utf-8", newline="") as f:
            installed = f.read()
        if installed != text:
            print("%s is not what catalog_src.py generates: run build_catalog.py --install" % shown)
            sys.exit(1)
        print(shown, "matches catalog_src.py")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
