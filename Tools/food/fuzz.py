# -*- coding: utf-8 -*-
"""Fuzzes the mirror parser (meal_port.py, so MealParser.swift) with random and adversarial inputs: phrases
built from catalog words, numbers, units and punctuation, mutated phrases from phrases*.py (typos, NFD,
emoji, stray numbers), random Unicode, long pastes and a fixed list of edge cases (huge numbers, clock
times, runs of punctuation, combining marks). Lists the parser indexes are wrapped so a negative or
out-of-range index, or a slice whose start is above its end, fails like a Swift trap instead of wrapping
around. Every result is checked (finite amounts and grams within bounds, totals equal to the sum of the
items, item texts taken from the input) and the slowest parses are listed.
  py -3 Tools/food/fuzz.py [count] [seed]      (default 50000 inputs, seed 1; about 6 minutes)"""
import math
import os
import random
import sys
import time
import traceback
import unicodedata

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import meal_port as mp  # noqa: E402
from run_phrases import source_catalog  # noqa: E402
import phrases  # noqa: E402
import phrases2  # noqa: E402
import phrases3  # noqa: E402
import phrases4  # noqa: E402
import phrases5  # noqa: E402

FOLD = str.maketrans("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ", "acelnoszzACELNOSZZ")


class Strict(list):
    """A list that traps like a Swift Array: no negative indices, no out-of-range slices."""

    def __getitem__(self, i):
        if isinstance(i, slice):
            assert i.step is None, "step"
            start = 0 if i.start is None else i.start
            stop = len(self) if i.stop is None else i.stop
            assert 0 <= start <= stop <= len(self), "slice %r of %d" % (i, len(self))
            return Strict(list.__getitem__(self, i))
        assert 0 <= i < len(self), "index %d of %d" % (i, len(self))
        return list.__getitem__(self, i)

    def __setitem__(self, i, v):
        assert not isinstance(i, slice) and 0 <= i < len(self), "set %r of %d" % (i, len(self))
        list.__setitem__(self, i, v)

    def __delitem__(self, i):
        assert not isinstance(i, slice) and 0 <= i < len(self), "del %r of %d" % (i, len(self))
        list.__delitem__(self, i)


_orig_init = mp.MealText.__init__


def _strict_init(self, text):
    _orig_init(self, text)
    self.chars = Strict(self.chars)
    self.tokens = Strict(self.tokens)


mp.MealText.__init__ = _strict_init

_orig_analyze = mp.Parser.analyze


def _strict_analyze(self, meal, part, protected, typos):
    assert 0 <= part[0] <= part[1] <= len(meal.tokens), "part %r of %d" % (part, len(meal.tokens))
    result = _orig_analyze(self, meal, part, protected, typos)
    result.name_tokens = Strict(result.name_tokens)
    return result


mp.Parser.analyze = _strict_analyze


def strict_parse(self, text):
    """Parser.parse with a trapping items list (same code as meal_port.Parser.parse)."""
    meal = mp.MealText(text)
    items, unknown = Strict(), []
    start = 0
    n = len(meal.tokens)
    for k in range(0, n + 1):
        if k == n or meal.tokens[k].kind == "separator":
            if start < k:
                self.parse_chunk(meal, (start, k), items, unknown)
            start = k + 1
    totals = (0.0, 0.0, 0.0, 0.0)
    for it in items:
        totals = tuple(a + b for a, b in zip(totals, it.macros))
    return items, unknown, totals


mp.Parser.parse = strict_parse

catalog = source_catalog()
parser = mp.Parser(catalog)
for alias in parser.aliases:
    alias.words = Strict(alias.words)
by_id = {f.id: f for f in catalog}
max_portion = max(max([f.default[1]] + [g for _, g in f.portions]) for f in catalog)
MAX_GRAMS = mp.MAX_AMOUNT * max(1000.0, max_portion, max(mp.GENERIC.values()))

# ---------------------------------------------------------------- vocabularies
RAW = [text for module in (phrases, phrases2, phrases3, phrases4, phrases5) for text, _, _ in module.P]
FOOD_WORDS = sorted({w for f in catalog for ph in [f.name] + f.aliases for w in ph.split()})
NUM_WORDS = sorted(mp.NUMBERS)
UNIT_WORDS = sorted(mp.UNITS)
JOIN = ["i", "oraz", "plus", "a", "z", "ze", "na", "w", "bez", "do", "tego", "o", "godz.", "x", "razy"]
FILLER = sorted(mp.FILLER)
PUNCT = [",", ";", "+", "!", "?", "…", ".", ":", "(", ")", "/", "%", "-", "–", "×", "*", "½", "¼", "¾", "⅓", "⅔",
         "\n", "\r\n", "\t", "\u00a0", "\u2028", "\u200b", "\u200d", "\ufe0f", "\u0301", "\u0328", "  "]
EMOJI = ["🍌", "☕", "👍🏽", "👨‍👩‍👧", "🇵🇱", "1️⃣", "❤️", "🥑", "🍕", "😋", "🫶🏻", "🏳️‍🌈"]
NUMBERS = ["0", "1", "2", "3", "5", "8", "10", "12", "20", "21", "24", "25", "99", "100", "150", "250", "1000",
           "0,5", "1,5", "2.5", "0.33", "7.50", "8.30", "12.30", "23.59", "24.00", "5.00", "4.99", "1/2", "3/4",
           "1/0", "0/0", "1 1/2", "1½", "2-3", "2-3%", "2%", "0%", "8:30", "13:00", "25:61", "8:30:15", "00:00",
           "99999999999999999999", "9" * 40, "1" + "0" * 400, "0," + "0" * 30 + "1", "1e400", "2x50", "2 x 50",
           "50x2", "3x", "x3", "1--2", "-1", "1-", "100000", "100001", "0,0", "0.0"]


def nfd(s):
    return unicodedata.normalize("NFD", s)


def random_phrase(rng):
    parts = []
    for _ in range(rng.randint(1, 12)):
        r = rng.random()
        if r < 0.35:
            parts.append(rng.choice(FOOD_WORDS))
        elif r < 0.5:
            parts.append(rng.choice(NUMBERS))
        elif r < 0.6:
            parts.append(rng.choice(UNIT_WORDS))
        elif r < 0.7:
            parts.append(rng.choice(JOIN))
        elif r < 0.75:
            parts.append(rng.choice(NUM_WORDS))
        elif r < 0.8:
            parts.append(rng.choice(FILLER))
        elif r < 0.92:
            parts.append(rng.choice(PUNCT))
        else:
            parts.append(rng.choice(EMOJI))
    sep = rng.choice([" ", " ", " ", "", ", ", ". "])
    s = sep.join(parts)
    if rng.random() < 0.1:
        s = nfd(s)
    if rng.random() < 0.1:
        s = s.upper()
    return s


def mutate(rng, s):
    chars = list(s)
    for _ in range(rng.randint(1, 4)):
        op = rng.random()
        pos = rng.randint(0, len(chars))
        if op < 0.25 and chars:
            del chars[min(pos, len(chars) - 1)]
        elif op < 0.5:
            chars.insert(pos, rng.choice(list("aąbcćdeęfghijklłmnńoóprsśtuwyzźż0123456789 ,.;:!?-/%()") + PUNCT + EMOJI))
        elif op < 0.65 and len(chars) > 1:
            p = min(pos, len(chars) - 2)
            chars[p], chars[p + 1] = chars[p + 1], chars[p]
        elif op < 0.8:
            chars.insert(pos, " " + rng.choice(NUMBERS) + " ")
        else:
            chars.insert(pos, " " + rng.choice(UNIT_WORDS + JOIN) + " ")
    out = "".join(chars)
    r = rng.random()
    if r < 0.1:
        out = nfd(out)
    elif r < 0.2:
        out = out.translate(FOLD)
    return out


def random_unicode(rng):
    n = rng.randint(1, 40)
    out = []
    for _ in range(n):
        r = rng.random()
        if r < 0.5:
            cp = rng.randint(0x20, 0x2FF)
        elif r < 0.7:
            cp = rng.randint(0x300, 0x36F)  # combining marks
        elif r < 0.8:
            cp = rng.randint(0x1F300, 0x1FAFF)
        elif r < 0.9:
            cp = rng.randint(0x2000, 0x2BFF)
        else:
            cp = rng.randint(0x0, 0xFFFF)
        if 0xD800 <= cp <= 0xDFFF:
            cp = 0x20
        out.append(chr(cp))
    return "".join(out)


def long_paste(rng, words, separators):
    pieces = []
    for _ in range(words):
        r = rng.random()
        if r < 0.6:
            pieces.append(rng.choice(FOOD_WORDS))
        elif r < 0.75:
            pieces.append(rng.choice(NUMBERS))
        elif r < 0.85:
            pieces.append(rng.choice(UNIT_WORDS))
        else:
            pieces.append(rng.choice(JOIN))
        if separators and rng.random() < 0.15:
            pieces.append(rng.choice([",", ".", "\n", ";"]))
    return " ".join(pieces)


def prose(rng, words):
    vocab = ("dzisiaj byłam bardzo zmęczona po pracy więc wieczorem spotkałam się z koleżanką i rozmawiałyśmy "
             "długo o wszystkim potem wróciłam do domu i oglądałam film jutro planuję trening rano spacer").split()
    return " ".join(rng.choice(vocab) for _ in range(words))


ADVERSARIAL = [
    "", " ", ".", "..", "....", ",,,,", ";;;;", "!!!", "???", "……", "+++", "---", "///", "%%%", "×××", "***",
    "(", ")", "()", "(()", "())", "( )", "z", "i", "a", "na", "w", "bez", "do", "z z z z", "i i i i", "bez bez",
    "na na na", "o", "o o o", "godz.", "godz. godz.", "o 99", "o 25", "o 8", "o 8.30", "o 8,5", "godz. 13:00",
    "0", "00", "0/0", "1/0", "0,0", "0.0", "½", "½½", "½ ½", "1½½", "⅓⅔", "1/2/3", "1 1/2 1/2", "2-3-4", "2--3",
    "-", "–", "2-", "-2", "2x", "x2", "x", "x x", "2 x x 3", "2 x 3 x 4 g", "2 razy razy 3", "2 x 50 x 2 g",
    "99999999999999999999", "9" * 400, "1" + "0" * 400 + " g masła", "0," + "0" * 400 + "1 kg", "1e400 g",
    "100000 kg masła", "100000 x 100000 g", "100001 g", "1/0,0000001 jajka", "0,0000001 kg",
    "8:30", "8:30:15", "25:61 owsianka", "00:00 kawa", "24.00 jajko", "23.59 kawa", "5.00 jajek", "4.99 g",
    "12.30.45", "8:", ":30", "8::30", "8:3", "1:2:3:4:5", "7.50 g", "8.30 g owsianka",
    "jajko" * 50, "z" * 200, ("jajko " * 300), ("i " * 300), ("z kurczakiem " * 100), ("2 " * 300),
    ("kostka " * 100), ("pół " * 50) + "jajka", "i pół", "dwa i pół i pół", "trzy czwarte czwarte",
    "jedna trzecia trzecia", "czwarte", "trzecie trzecie", "do tego", "do tego tego", "o tego", "tego 8",
    "\u0301", "\u0301jajko", "jajko\u0301", "\u200d", "\u200djajko", "\ufe0f", "\r\n\r\n", "\r", "\u2028\u2029",
    "jajko\u00a0\u00a0banan", "\t\tjajko", "ЯЙЦО", "ΣΟΦΙΑ", "İ", "ß", "ﬁ", "ǅ", "Ⓐ", "🄰🄱", "ⓙⓐⓙⓚⓞ",
    "1️⃣ jajko", "#️⃣", "🇵🇱🇵🇱🇵", "👨‍👩‍👧‍👦 kawa", "kawa👍🏽", "e\u0301\u0301\u0301\u0301",
    nfd("pierś z kurczaka z ryżem, łyżka masła, żółty ser, śliwki, ćwierć arbuza"),
    nfd("ŻÓŁTY SER Z SZYNKĄ I MLEKIEM"), "kawa z cukrem i \u0105", "kawa z cukrem i mlekiem\u0328",
]


def check(text):
    t0 = time.perf_counter()
    items, unknown, totals = parser.parse(text)
    name = parser.cleaned_name(text)
    dt = time.perf_counter() - t0
    s = (0.0, 0.0, 0.0, 0.0)
    for it in items:
        assert math.isfinite(it.amount) and math.isfinite(it.grams), "non-finite %r" % it
        assert 0 <= it.grams <= MAX_GRAMS, "grams %r" % it
        assert all(math.isfinite(v) for v in it.macros), "macros %r" % it
        assert it.text and it.text in text, "text %r" % it.text
        assert it.food_id in by_id
        s = tuple(a + b for a, b in zip(s, it.macros))
    assert s == totals, "totals"
    for u in unknown:
        assert u and u == u.strip(), "unknown %r" % u
    assert isinstance(name, str)
    return dt


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 50000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    rng = random.Random(seed)
    inputs = list(ADVERSARIAL)
    # long pastes: with and without separators, prose with no food at all
    for words in (200, 500, 1000):
        inputs.append(long_paste(rng, words, True))
        inputs.append(long_paste(rng, words, False))
        inputs.append(prose(rng, words))
    while len(inputs) < count:
        r = rng.random()
        if r < 0.45:
            inputs.append(random_phrase(rng))
        elif r < 0.85 and RAW:
            inputs.append(mutate(rng, rng.choice(RAW)))
        else:
            inputs.append(random_unicode(rng))
    failures = []
    times = []
    t_start = time.perf_counter()
    for n, text in enumerate(inputs):
        try:
            dt = check(text)
            times.append((dt, text))
        except Exception as e:  # noqa: BLE001
            failures.append((text, "%s: %s" % (type(e).__name__, e), traceback.format_exc(limit=3)))
        if n and n % 10000 == 0:
            print("  %d done, %d failures, %.0f s" % (n, len(failures), time.perf_counter() - t_start), flush=True)
    times.sort(key=lambda x: -x[0])
    print("inputs:", len(inputs), "failures:", len(failures), "total %.0f s" % (time.perf_counter() - t_start))
    for text, err, tb in failures[:15]:
        print("FAIL %r\n   %s\n%s" % (text[:120], err, tb))
    print("slowest:")
    for dt, text in times[:12]:
        print("  %.3f s  %d chars  %r" % (dt, len(text), text[:80]))
    short = [dt for dt, text in times if len(text) <= 200]
    if short:
        short.sort()
        print("<=200 chars: median %.4f s, p99 %.4f s, max %.4f s" % (short[len(short) // 2],
                                                                      short[int(len(short) * 0.99)], short[-1]))


if __name__ == "__main__":
    main()
