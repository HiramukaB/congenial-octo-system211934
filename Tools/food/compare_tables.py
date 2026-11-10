# -*- coding: utf-8 -*-
"""Compares the word tables in MealParser.swift (numbers, units, filler, joining, cooking words,
endings, abbreviations, milk drinks ...) and its constants with the ones in meal_port.py.
  py -3 Tools/food/compare_tables.py"""
import re, sys, os
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meal_port as mp
from paths import MEAL_PARSER as SWIFT
with open(SWIFT, encoding="utf-8") as _f:
    src = _f.read()
bad = 0
def block(name):
    m = re.search(r"static let %s: [^=]+= (?:table\()?\[(.*?)\]" % name, src, re.S)
    return m.group(1)
def groups(name):
    out = {}
    seen = []
    for words, value in re.findall(r'\("([^"]*)",\s*([^)]*\)?)\)', block(name)):
        for w in words.split(" "):
            seen.append(w)
            out[w] = value.strip()
    dups = sorted(set(w for w in seen if seen.count(w) > 1))
    return out, dups
units, dups = groups("units")
if dups:
    print("duplicate unit words", dups); bad += 1
def conv(v):
    m = re.match(r"\.grams\(([\d.]+)\)", v)
    if m: return ("g", float(m.group(1)))
    m = re.match(r"\.portion\(\.(\w+)\)", v)
    return ("p", m.group(1))
su = {w: conv(v) for w, v in units.items()}
if su != mp.UNITS:
    print("units differ:", set(su.items()) ^ set(mp.UNITS.items())); bad += 1
nums, dups = groups("numbers")
sn = {w: float(v) for w, v in nums.items()}
if sn != mp.NUMBERS or dups:
    print("numbers differ", dups); bad += 1
def strset(name):
    m = re.search(r"static let %s: Set<(?:String|Character)> = \[(.*?)\]" % name, src, re.S)
    if m is None:
        print("no Set named", name, "in MealParser.swift")
        return None
    items = re.findall(r'"([^"]*)"', m.group(1))
    if len(items) != len(set(items)):
        print(name, "lists a word twice")
    return set(items)
for name, py in [("times", mp.TIMES), ("filler", mp.FILLER), ("joining", mp.JOINING), ("withWords", mp.WITH),
                 ("softWords", mp.ON), ("preparation", mp.PREPARATION), ("manner", mp.MANNER),
                 ("falseFriends", mp.FALSE_FRIENDS), ("endings", mp.ENDINGS), ("stemVowels", mp.STEM_VOWELS),
                 ("vowels", mp.VOWELS), ("separators", mp.SEPARATORS), ("abbreviations", mp.ABBREVIATIONS),
                 ("unitSymbols", mp.UNIT_SYMBOLS),
                 ("energy", mp.ENERGY), ("namedAfterNumber", mp.NAMED_AFTER_NUMBER),
                 ("adjectiveEndings", mp.ADJECTIVE_ENDINGS), ("nounEndings", mp.NOUN_ENDINGS),
                 ("adjectiveForms", mp.ADJECTIVE_FORMS), ("flavoured", mp.FLAVOURED), ("milks", mp.MILKS),
                 ("milkDishes", mp.MILK_DISHES), ("splashDrinks", mp.SPLASH_DRINKS),
                 ("singularEndings", mp.SINGULAR_ENDINGS), ("clockWords", mp.CLOCK_WORDS),
                 ("besides", mp.BESIDES), ("instrumentalLetters", mp.INSTRUMENTAL_LETTERS),
                 ("instrumentalEndings", mp.INSTRUMENTAL_ENDINGS), ("containers", mp.CONTAINERS)]:
    s = strset(name)
    if s != set(py):
        print(name, "differs:", None if s is None else s ^ set(py)); bad += 1
m = re.search(r"static let genitiveFoods: Set<FoodCategory> = \[(.*?)\]", src, re.S)
if m is None or set(re.findall(r"\.(\w+)", m.group(1))) != mp.GENITIVE_FOODS:
    print("genitiveFoods differs"); bad += 1
m = re.search(r"static let countedDishes: Set<PortionUnit> = \[(.*?)\]", src, re.S)
if m is None or set(re.findall(r"\.(\w+)", m.group(1))) != mp.COUNTED_DISHES:
    print("countedDishes differs"); bad += 1
m = re.search(r"static let fractionWords: \[String: Double\] = \[(.*?)\]", src, re.S)
if m is None or {w: float(v) for w, v in re.findall(r'"(\w+)": ([\d.]+)', m.group(1))} != mp.FRACTION_WORDS:
    print("fractionWords differs"); bad += 1
m = re.search(r"static let fractions: \[Character: Double\] = \[(.*?)\]\n", src, re.S)
fractions = {}
for ch, value in re.findall(r'"(.)": ([\d.]+(?: / \d+)?)', m.group(1)):
    a, _, b = value.partition(" / ")
    fractions[ch] = float(a) / float(b) if b else float(a)
if fractions != mp.FRACTIONS:
    print("fractions differ"); bad += 1
for name, py in [("maxAmount", mp.MAX_AMOUNT), ("splashMillilitres", mp.SPLASH_MILLILITRES),
                 ("maxSeparatedWords", mp.MAX_SEPARATED_WORDS)]:
    m = re.search(r"static let %s(?:: \w+)? = ([\d_.]+)" % name, src)
    if m is None or float(m.group(1).replace("_", "")) != float(py):
        print(name, "differs"); bad += 1
neg = re.search(r'static let negation = "(\w+)"', src).group(1)
if neg != mp.NEG:
    print("negation differs"); bad += 1
print("tables compared, problems:", bad)
