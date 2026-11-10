# -*- coding: utf-8 -*-
"""Prints what the mirror parser makes of each phrase, with the total kcal.
  py -3 Tools/food/probe.py "miska płatków z mlekiem" "kostka czekolady" [--repo]
The catalog is catalog_src.py as it is now; --repo uses the installed FoodDB.json."""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meal_port as mp  # noqa: E402
from run_phrases import chosen_catalog, describe  # noqa: E402

p = mp.Parser(chosen_catalog(sys.argv))
for s in sys.argv[1:]:
    if s.startswith("--"):
        continue
    items, unknown, totals = p.parse(s)
    print("%-45s -> %s  [%.0f kcal]" % (s, describe(items, unknown), totals[0]))
