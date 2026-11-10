# -*- coding: utf-8 -*-
"""Prints Swift `typed(...)` lines for MealParserTests.swift with what the mirror makes of each phrase.
  py -3 Tools/food/emit_swift.py "phrase" ...             -> against the installed FoodDB.json
  py -3 Tools/food/emit_swift.py --fixture "phrase" ...   -> against the test fixture (MealFixture)
Check every line by hand before it goes into a test: it records what the parser does, right or wrong."""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import meal_port as mp  # noqa: E402
from run_phrases import load_catalog, REPO  # noqa: E402


def num(x):
    return ("%d" % x) if float(x).is_integer() else repr(float(x))


def swift_string(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def emit(parser, text):
    items, unknown, _ = parser.parse(text)
    parts = []
    for i in items:
        unit = "nil" if i.unit is None else "." + i.unit
        guess = ", guess: true" if i.is_guess else ""
        parts.append('parsedAs("%s", %s, %s, %s%s)' % (i.food_id, num(i.amount), unit, num(i.grams), guess))
    unk = (", unknown: [%s]" % ", ".join('"%s"' % swift_string(u) for u in unknown)) if unknown else ""
    print('        typed("%s", [%s]%s),' % (swift_string(text), ", ".join(parts), unk))


if "--fixture" in sys.argv:
    from run_fixture_tests import FIX
    parser = mp.Parser(FIX)
else:
    parser = mp.Parser(load_catalog(REPO))
for t in [a for a in sys.argv[1:] if not a.startswith("--")]:
    emit(parser, t)
