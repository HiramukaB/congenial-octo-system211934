# -*- coding: utf-8 -*-
"""For each one-word alias, inflects it (alias + ending, stem + ending) and reports the forms another
product wins - a quick look for aliases that steal each other's forms.
  py -3 Tools/food/collisions.py [--repo]"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import meal_port as mp  # noqa: E402
from run_phrases import chosen_catalog  # noqa: E402

p = mp.Parser(chosen_catalog(sys.argv))
seen = set()
for a in p.aliases:
    if len(a.words) != 1:
        continue
    w = a.words[0]
    forms = set()
    for e in mp.ENDINGS:
        forms.add(w.text + e)
        if w.vowel_stem:
            forms.add(w.vowel_stem + e)
    for f in sorted(forms):
        if f in seen:
            continue
        m = p.best_match([f], False)
        if m is None or m.alias.item.id == a.item.id:
            continue
        seen.add(f)
        print("%-16s %-22s wins over %-22s (via %s)" % (f, m.alias.item.id, a.item.id,
                                                        " ".join(x.text for x in m.alias.words)))
