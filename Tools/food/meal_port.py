# -*- coding: utf-8 -*-
"""Line-by-line Python mirror of Packages/AboutHerCore/Sources/AboutHerCore/Food/MealParser.swift (and of
FoodItem.grams(per:) in FoodModels.swift), so phrases can be checked without a Swift toolchain.
Swift traps (negative index, bad ranges) are emulated with asserts.
Keep it in step with the Swift: every rule or word-table change there gets the same change here, in
the same commit. compare_tables.py compares the word tables, check_swift_tests.py runs every
expectation of MealParserTests.swift through this mirror.
Swift works on Characters (extended grapheme clusters) and compares them by canonical equivalence; the
mirror does the same through graphemes() and nfc(), so NFD text ("o" + U+0301), emoji sequences and
"\r\n" tokenize as on the phone."""
import unicodedata

FOLD = {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z", "ż": "z"}
WHITESPACE = set(" \t\n\r\x0b\x0c\x85\xa0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a"
                 "\u2028\u2029\u202f\u205f\u3000")
NEWLINES = set("\n\r\x0b\x0c\x85\u2028\u2029")
# Other_Alphabetic symbols a Character can start with (circled and squared Latin letters): Swift's isLetter.
_OTHER_ALPHABETIC = ((0x24B6, 0x24E9), (0x1F130, 0x1F149), (0x1F150, 0x1F169), (0x1F170, 0x1F189))


def nfc(c):
    """A Character as Swift compares it: canonically equivalent strings are equal."""
    return c if c.isascii() else unicodedata.normalize("NFC", c)


def is_letter(c):
    """Swift Character.isLetter: the first scalar is Alphabetic (L*, Nl or Other_Alphabetic)."""
    cp = ord(c[0])
    cat = unicodedata.category(c[0])
    return cat.startswith("L") or cat == "Nl" or any(a <= cp <= b for a, b in _OTHER_ALPHABETIC)


def is_whitespace(c):  # Swift Character.isWhitespace: the first scalar is White_Space
    return c[0] in WHITESPACE


def is_newline(c):  # Swift Character.isNewline: the first scalar is LF, VT, FF, CR, NEL, LS or PS
    return c[0] in NEWLINES


def _break_class(ch):
    """The Grapheme_Cluster_Break class of one code point (UAX #29), as far as the parser can meet it."""
    cp = ord(ch)
    if ch == "\r":
        return "CR"
    if ch == "\n":
        return "LF"
    if cp == 0x200D:
        return "ZWJ"
    if 0x1F1E6 <= cp <= 0x1F1FF:
        return "RI"
    if 0x1F3FB <= cp <= 0x1F3FF or 0xE0020 <= cp <= 0xE007F or cp == 0x200C:
        return "Extend"
    if 0x1100 <= cp <= 0x115F or 0xA960 <= cp <= 0xA97C:
        return "L"
    if 0x1160 <= cp <= 0x11A7 or 0xD7B0 <= cp <= 0xD7C6:
        return "V"
    if 0x11A8 <= cp <= 0x11FF or 0xD7CB <= cp <= 0xD7FB:
        return "T"
    if 0xAC00 <= cp <= 0xD7A3:
        return "LV" if (cp - 0xAC00) % 28 == 0 else "LVT"
    cat = unicodedata.category(ch)
    if cat in ("Mn", "Me"):
        return "Extend"
    if cat == "Mc":
        return "SpacingMark"
    if cat in ("Cc", "Zl", "Zp") or (cat == "Cf" and cp != 0x200D):
        return "Control"
    if (0x1F000 <= cp <= 0x1FAFF or 0x2600 <= cp <= 0x27BF or 0x2B00 <= cp <= 0x2BFF
            or cp in (0x00A9, 0x00AE, 0x203C, 0x2049, 0x2122, 0x2139, 0x3030, 0x303D, 0x3297, 0x3299)):
        return "ExtPict"
    return "Other"


def graphemes(text):
    """The text as Swift's Characters: extended grapheme clusters (UAX #29 rules GB3-GB13, no Prepend)."""
    if text.isascii() and "\r\n" not in text:
        return list(text)
    out = []
    prev = None
    pict = False      # the cluster so far is ExtPict Extend* (for GB11)
    pict_zwj = False  # ... followed by ZWJ
    ri = 0            # regional indicators in a row
    for ch in text:
        cls = _break_class(ch)
        join = False
        if prev is not None:
            if prev == "CR" and cls == "LF":
                join = True
            elif prev in ("Control", "CR", "LF") or cls in ("Control", "CR", "LF"):
                join = False
            elif prev == "L" and cls in ("L", "V", "LV", "LVT"):
                join = True
            elif prev in ("LV", "V") and cls in ("V", "T"):
                join = True
            elif prev in ("LVT", "T") and cls == "T":
                join = True
            elif cls in ("Extend", "ZWJ", "SpacingMark"):
                join = True
            elif pict_zwj and cls == "ExtPict":
                join = True
            elif prev == "RI" and cls == "RI" and ri % 2 == 1:
                join = True
        if join:
            out[-1] += ch
        else:
            out.append(ch)
        if cls == "ExtPict":
            pict, pict_zwj = True, False
        elif cls == "Extend" and pict and not pict_zwj:
            pass
        elif cls == "ZWJ" and pict and not pict_zwj:
            pict_zwj = True
        else:
            pict, pict_zwj = False, False
        ri = ri + 1 if cls == "RI" else 0
        prev = cls
    return out


def normalized(text):
    """FoodText.normalized: lowercased scalar by scalar, then folded Character by Character."""
    result = []
    pending = False
    lowered = text.lower() if text.isascii() else "".join(ch.lower() for ch in text)
    for ch in graphemes(lowered):
        if is_whitespace(ch):
            pending = len(result) > 0
            continue
        if pending:
            result.append(" ")
            pending = False
        result.append(FOLD.get(nfc(ch), ch))
    return nfc("".join(result))


GENERIC = {"piece": 100, "slice": 35, "thinSlice": 15, "tablespoon": 15, "teaspoon": 5, "glass": 250,
           "mug": 300, "handful": 30, "serving": 250, "bowl": 350, "can": 400, "package": 150,
           "chunk": 50, "clove": 5}


class Food:
    """FoodItem: id, name, aliases, per100 (kcal, protein, carbs, fat), portions [(unit, grams)],
    default (unit, grams), category, singular (the words in the singular, or None)."""

    def __init__(self, id, name, aliases, per100, portions, default, category="other", singular=None):
        self.id, self.name, self.aliases, self.per100, self.portions, self.default = id, name, aliases, per100, portions, default
        self.category = category
        self.singular = singular

    def grams_per(self, unit):
        if self.default[0] == unit:
            return self.default[1]
        for u, g in self.portions:
            if u == unit:
                return g
        # "porcja X" means the same as a bare "X", "2 sztuki jogurtu" two of its cups: the product's own
        # amount, not a generic 250 g or 100 g.
        if unit == "serving" or unit == "piece":
            return self.default[1]
        return GENERIC[unit]

    def macros(self, grams):
        f = grams / 100
        return tuple(v * f for v in self.per100)


def table(groups):
    r = {}
    for words, value in groups:
        for w in words.split(" "):
            r[w] = value
    return r


NUMBERS = table([
    ("pol polowa polowy polowe polowka polowki polowke", 0.5),
    ("poltora poltorej", 1.5),
    ("cwierc", 0.25),
    ("jeden jedna jedno jednego jednej jednym", 1.0),
    ("dwa dwie dwoch dwoma dwom dwiema", 2.0),
    ("trzy trzech trzema", 3.0),
    ("cztery czterech czterema", 4.0),
    ("piec pieciu piecioma", 5.0),
    ("szesc szesciu szescioma", 6.0),
    ("siedem siedmiu siedmioma", 7.0),
    ("osiem osmiu osmioma", 8.0),
    ("dziewiec dziewieciu dziewiecioma", 9.0),
    ("dziesiec dziesieciu dziesiecioma", 10.0),
    ("pare paru paroma", 2.0),
    ("kilka kilku kilkoma", 3.0),
])
UNITS = table([
    ("g gr gram gramy gramow grama", ("g", 1.0)),
    ("dag dkg deko deka dekagram dekagramy dekagramow", ("g", 10.0)),
    ("kg kilo kilogram kilograma kilogramy kilogramow", ("g", 1000.0)),
    ("ml mililitr mililitra mililitry mililitrow", ("g", 1.0)),
    ("l litr litra litry litrow", ("g", 1000.0)),
    ("lyzka lyzki lyzek lyzke lyzkami lyz lyzce lyzkach", ("p", "tablespoon")),
    ("kes kesa kesy kesow kesem kesek keska lyk lyka lyki lykow lykiem lyczek lyczka", ("p", "tablespoon")),
    ("lyzeczka lyzeczki lyzeczek lyzeczke lyzeczkami lyzeczce odrobina odrobiny odrobine", ("p", "teaspoon")),
    ("kropla kropli krople kroplami kropel kropelka kropelki kropelke kropelek", ("p", "teaspoon")),
    ("szklanka szklanki szklanek szklanke szklankami szklance szkl", ("p", "glass")),
    ("kieliszek kieliszka kieliszki kieliszkow kieliszkiem lampka lampki lampke", ("p", "glass")),
    ("kubek kubka kubki kubkow kubkiem kubku kufel kufla kufle kuflem filizanka filizanki filizanke", ("p", "mug")),
    ("kromka kromki kromek kromke kromkami kromce kromkach", ("p", "slice")),
    ("plaster plastra plastry plastrow plastrem plastrami plastrze plastrach", ("p", "thinSlice")),
    ("plasterek plasterka plasterki plasterkow plasterkiem plasterkami plasterku plasterkach", ("p", "thinSlice")),
    ("rozyczka rozyczki rozyczek rozyczke rozyczkami krazek krazka krazki krazkow krazkiem krazkami",
     ("p", "thinSlice")),
    ("czastka czastki czastek czastke czastkami", ("p", "thinSlice")),
    ("garsc garsci garscia garstka garstki garstke garscie garsciami garsciach", ("p", "handful")),
    ("sztuka sztuki sztuk sztuke szt galka galki galek galke", ("p", "piece")),
    ("kostka kostki kostek kostke kostce kostkami kosteczka kosteczki kosteczke kosteczek", ("p", "piece")),
    ("porcja porcje porcji porcjami", ("p", "serving")),
    ("miska miski misek miske misce miseczka miseczki miseczke talerz talerza talerze talerzy talerzem talerzu",
     ("p", "bowl")),
    ("puszka puszki puszek puszke puszce butelka butelki butelek butelke", ("p", "can")),
    ("opakowanie opakowania opakowan opakowaniem opakowaniu paczka paczki paczek paczke op opak", ("p", "package")),
    ("tabliczka tabliczki tabliczek tabliczke kubeczek kubeczka kubeczki", ("p", "package")),
    ("kawalek kawalka kawalki kawalkow kawalkiem kawalkami kawalku kawaleczek kawaleczka kawaleczki", ("p", "chunk")),
    ("zabek zabka zabki zabkow zabkiem zabkami", ("p", "clove")),
])
TIMES = {"x", "razy"}
FILLER = {"ok", "okolo", "kcal", "kalorii", "kalorie",
          "sniadanie", "sniadania", "sniadaniu", "sniadaniem", "drugie", "obiad", "obiadu", "obiadem",
          "kolacja", "kolacji", "kolacje", "lunch", "lunchu", "lunchem", "przekaska", "przekaski", "przekaske",
          "podwieczorek", "podwieczorku", "zjadlam", "wypilam", "jadlam", "pilam",
          "pizzerii", "restauracji", "kawiarni", "piekarni", "cukierni", "stolowki", "sklepu", "automatu",
          "dostawy", "costy", "starbucks", "starbucksa", "kfc", "mcdonalds", "mcdonaldsa", "mcdonalda", "biedronki",
          "lidla", "ikei", "orlenu", "baru", "barze", "mlecznego", "mlecznym", "browaru",
          "chlopakiem", "mezem", "kolezanka", "kolezankami", "kolega", "kolegami", "przyjaciolka",
          "przyjaciolkami", "przyjacielem", "przyjaciolmi", "znajomymi", "rodzina", "rodzicami", "mama", "tata",
          "siostra", "bratem", "dziecmi", "corka", "synem", "partnerem", "partnerka", "dziewczynami", "babcia",
          "dziadkiem", "ciocia", "u", "mamy", "taty", "babci", "cioci", "pracy", "domu", "obok",
          "o", "godz", "godzina", "godzinie", "tego", "tej", "picia",
          "czwarta", "czwarte", "czwartych", "trzecia", "trzecie", "trzecich"}
JOINING = {"i", "oraz", "plus", "a"}
WITH = {"z", "ze"}
ON = {"na", "w"}
PREPARATION = {"grilla", "grillu", "piekarnika", "patelni", "rusztu", "rozna", "frytkownicy", "airfryera",
               "mikrofali", "mikrofalowki", "ekspresu", "kranu", "woka", "pieca", "tostera", "parowaru"}
MANNER = {"twardo", "miekko", "polmiekko", "parze", "sucho", "surowo", "ostro", "slodko", "goraco", "zimno",
          "cieplo"}
NEG = "bez"
FALSE_FRIENDS = {"pora", "wodka", "wodki", "oliwka", "oliwki", "oliwkami", "protein"}
ENDINGS = {"a", "u", "y", "i", "e", "o", "em", "om", "ie", "ach", "ami", "ow", "owi", "ka", "ki", "kiem", "kami",
           "iem", "ia", "iu", "ej", "iej", "ego", "emu", "ym", "im", "ymi", "imi", "ych", "ich"}
STEM_VOWELS = set("aeoyi")
VOWELS = set("aeiouy")
FRACTIONS = {"½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3}
SEPARATORS = {",", ";", "+", "!", "?", "…"}
ABBREVIATIONS = {"g", "gr", "dag", "dkg", "kg", "ml", "l", "lyz", "szt", "szkl", "op", "opak", "ok", "np", "tzw",
                 "sr", "sw", "wg", "ew", "m", "in", "itp", "itd", "tj", "dr", "godz"}
CLOCK_WORDS = {"o", "godz", "godzina", "godzinie"}
HOUR_WORDS = {"rano", "wieczorem", "h", "sniadanie", "obiad", "kolacja", "lunch"}
BESIDES = {"tego", "tej", "picia"}
FRACTION_WORDS = {"czwarta": 4.0, "czwarte": 4.0, "czwartych": 4.0, "trzecia": 3.0, "trzecie": 3.0, "trzecich": 3.0}
INSTRUMENTAL_LETTERS = {"ą", "Ą"}
INSTRUMENTAL_ENDINGS = {"em", "ami"}
COUNTED_DISHES = {"piece", "slice", "chunk"}
CONTAINERS = {"koktajl", "koktajle", "koktajlu", "koktajlem", "smoothie", "smoothies", "szejk", "szejka", "shake"}
UNIT_SYMBOLS = {"g", "gr", "dag", "dkg", "kg", "ml", "l", "rozyczka", "rozyczki", "rozyczek", "rozyczke",
                "rozyczkami", "krazek", "krazka", "krazki", "krazkow", "krazkiem", "krazkami", "czastka", "czastki",
                "czastek", "czastke", "czastkami"}
ENERGY = {"kcal", "kalorii", "kalorie"}
NUTRIENTS = {"bialka", "bialko", "tluszczu", "weglowodanow", "blonnika", "cukrow"}
PROTEIN_FOODS = {"jaj", "jaja", "jajek", "jajka", "z", "serwatkowego", "serwatkowe", "wpc"}
NAMED_AFTER_NUMBER = {"cm", "sery", "serow", "zboz", "ziaren"}
ADJECTIVE_ENDINGS = {"owy", "owa", "owe", "ny", "na", "ne", "ski", "ska", "skie", "cki", "cka", "ckie"}
NOUN_ENDINGS = {"ina", "ine", "iny", "yna", "yne", "yny"}
ADJECTIVE_FORMS = {"y", "a", "e", "i", "ego", "emu", "ym", "im", "ej", "iej", "ych", "ich", "ymi", "imi"}
FLAVOURED = {"sos", "zupa", "zupka", "sok", "budyn", "kisiel"}
GENITIVE_FOODS = {"meat", "fish"}
DISH_ADJECTIVES = {"schabowy", "mielony", "ruskie"}
CUT_STEMS = {"przekroj", "pokroj", "rozkroj", "kroj", "przekroil", "pokroil", "rozkroil", "kroil", "przeciet",
             "rozciet", "przeciel", "rozciel", "zloz"}
MILKS = {"mleko", "mleko-owsiane", "mleko-sojowe", "mleko-migdalowe"}
MILK_DISHES = {"latte", "cappuccino", "kawa-z-mlekiem", "herbata-z-mlekiem", "kakao", "budyn", "nalesniki",
               "nalesniki-z-serem", "placuszki", "owsianka", "kasza-manna"}
SPLASH_DRINKS = {"kawa", "herbata"}
FOR_DRINKS = {"kawy", "herbaty", "kawki", "herbatki"}
ADD_INS = MILKS | {"cukier", "slodzik", "miod", "smietana", "sos", "majonez", "ketchup", "cytryna", "maslo"}
SINGULAR_ENDINGS = {"em", "u"}
MAX_AMOUNT = 100000.0
SPLASH_MILLILITRES = 30.0
JUICE_PER_FRUIT = 80.0
MAX_SEPARATED_WORDS = 12


def is_joining(w):
    return w in JOINING or w in WITH or w in ON


def is_protectable(w):
    return is_joining(w) or w == NEG


def is_never_name(w):
    return w in NUMBERS or w in TIMES or w in FILLER or w in UNITS or w in PREPARATION


def is_adjective(w):
    return (any(w.endswith(e) for e in ADJECTIVE_ENDINGS)
            and not any(w.endswith(e) for e in NOUN_ENDINGS))


def rng(a, b):
    assert a <= b, "Range requires lowerBound <= upperBound (%d, %d)" % (a, b)
    return range(a, b)


def at(arr, i):
    assert 0 <= i < len(arr), "index out of range %d of %d" % (i, len(arr))
    return arr[i]


class Tok:
    def __init__(self, kind, start, end, norm="", value=0.0, clock=False):
        self.kind, self.norm, self.value, self.start, self.end = kind, norm, value, start, end
        self.clock = clock

    @property
    def is_quantity(self):
        return ((self.kind == "number" and not self.clock) or self.kind == "fraction"
                or (self.kind == "word" and self.norm in NUMBERS))


def is_digit(c):
    return len(c) == 1 and ord(c) < 128 and 48 <= ord(c) <= 57


def swift_int(digits):
    """Int(String) in Swift: nil above Int.max."""
    v = int(digits)
    return v if v <= 2 ** 63 - 1 else None


class MealText:
    def __init__(self, text):
        chars = graphemes(text)
        tokens = []
        n = len(chars)
        i = 0
        while i < n:
            c = chars[i]
            if (is_newline(c) or c in SEPARATORS
                    or (c == "." and not MealText.closes_abbreviation(tokens, i))):
                tokens.append(Tok("separator", i, i + 1))
                i += 1
            elif is_whitespace(c):
                i += 1
            elif is_digit(c):
                j = i
                while j < n and is_digit(chars[j]):
                    j += 1
                if j + 2 < n and chars[j] == ":" and is_digit(chars[j + 1]) and is_digit(chars[j + 2]):
                    k = j + 1
                    while k < n and is_digit(chars[k]):
                        k += 1
                    tokens.append(Tok("time", i, k))
                    i = k
                    continue
                digits = "".join(chars[i:j])
                clock = False
                whole = True
                if j + 1 < n and (chars[j] == "," or chars[j] == ".") and is_digit(chars[j + 1]):
                    k = j + 1
                    while k < n and is_digit(chars[k]):
                        k += 1
                    fraction = "".join(chars[j + 1:k])
                    if chars[j] == "." and len(fraction) == 2:
                        hour = swift_int(digits)
                        minute = swift_int(fraction)
                        if hour is not None and minute is not None:
                            clock = 5 <= hour <= 23 and minute < 60
                    digits += "." + fraction
                    j = k
                    whole = False
                if whole and MealText.follows_clock_word(tokens, chars):
                    hour = swift_int(digits)
                    if hour is not None:
                        clock = hour <= 24
                tokens.append(Tok("number", i, j, value=float(digits), clock=clock))
                i = j
            elif c in FRACTIONS:
                tokens.append(Tok("fraction", i, i + 1, value=FRACTIONS[c]))
                i += 1
            elif is_letter(c):
                j = i
                while j < n and is_letter(chars[j]):
                    j += 1
                tokens.append(Tok("word", i, j, norm=normalized("".join(chars[i:j]))))
                i = j
            else:
                kind = {"/": "slash", "%": "percent", "×": "times", "*": "times", "-": "dash", "–": "dash"}.get(c, "other")
                tokens.append(Tok(kind, i, i + 1))
                i += 1
        self.chars = chars
        self.tokens = tokens

    @staticmethod
    def closes_abbreviation(tokens, offset):
        if not tokens:
            return False
        last = tokens[-1]
        return last.kind == "word" and last.end == offset and last.norm in ABBREVIATIONS

    @staticmethod
    def follows_clock_word(tokens, chars):
        k = len(tokens) - 1
        if k >= 0 and tokens[k].kind == "other" and at(chars, tokens[k].start) == ".":
            k -= 1
        return k >= 0 and tokens[k].kind == "word" and tokens[k].norm in CLOCK_WORDS

    @staticmethod
    def words(phrase):
        words = []
        current = ""
        for ch in graphemes(normalized(phrase)):
            if is_letter(ch):
                current += ch
            elif current:
                words.append(current)
                current = ""
        if current:
            words.append(current)
        return words

    def is_word(self, k, end, word):
        return k < end and at(self.tokens, k).kind == "word" and self.tokens[k].norm == word

    def is_word_in(self, k, end, words):
        return k < end and at(self.tokens, k).kind == "word" and self.tokens[k].norm in words

    def is_word_starting(self, k, end, stems):
        """isWord(_:_:startingWith:): a word that starts with one of `stems` ("przekrojone" with "przekroj")."""
        if not (k < end and at(self.tokens, k).kind == "word"):
            return False
        word = self.tokens[k].norm
        return any(word.startswith(s) for s in stems)

    def is_unit(self, k, end):
        return k < end and at(self.tokens, k).kind == "word" and self.tokens[k].norm in UNITS

    def is_doughnut(self, k):
        """Whether "pączek", "pączki" is written with "ą": normalized it reads like the unit "paczek", "paczki"
        (but "z paczką chipsów" is a package)."""
        token = at(self.tokens, k)
        if not (token.kind == "word" and UNITS.get(token.norm) == ("p", "package") and token.end - token.start >= 2):
            return False
        second = nfc(at(self.chars, token.start + 1))
        return second == "ą" or second == "Ą"

    def is_times(self, k, end):
        return k < end and (at(self.tokens, k).kind == "times" or (self.tokens[k].kind == "word" and self.tokens[k].norm in TIMES))

    def has_name_word(self, r):
        for k in rng(r[0], r[1]):
            t = at(self.tokens, k)
            if t.kind == "word" and not is_never_name(t.norm) and not is_joining(t.norm):
                return True
        return False

    def is_amount_token(self, k):
        token = at(self.tokens, k)
        if token.kind in ("number", "fraction", "slash", "times", "dash"):
            return True
        if token.kind == "word":
            word = token.norm
            return (word in NUMBERS or word in UNITS or word in TIMES or word in FILLER
                    or (word == "i" and self.is_word(k + 1, len(self.tokens), "pol")))
        if token.kind == "other":
            return at(self.chars, token.start) == "."
        return False

    def split(self, r, words, protected):
        parts = []
        start = r[0]
        for k in rng(r[0], r[1]):
            t = at(self.tokens, k)
            if t.kind == "word" and t.norm in words and k not in protected:
                rng(start, k)
                parts.append((start, k))
                start = k + 1
        rng(start, r[1])
        parts.append((start, r[1]))
        return parts

    def is_percentage(self, k, end):
        tokens = self.tokens
        if k + 1 < end and at(tokens, k + 1).kind == "percent":
            return True
        return (k + 3 < end and at(tokens, k + 1).kind == "dash" and at(tokens, k + 2).kind == "number"
                and at(tokens, k + 3).kind == "percent")

    def quantity(self, k, end):
        tokens = self.tokens
        token = at(tokens, k)
        if token.kind == "number":
            if self.is_percentage(k, end):
                return None
            if token.clock and not self.is_unit(k + 1, end):
                return None
            # "8 rano owsianka", "ok. 13 obiad: zupa", "2 śniadanie: jogurt": an hour or the meal's number.
            if (token.value <= 24 and token.value == round_half_away(token.value)
                    and self.is_word_in(k + 1, end, HOUR_WORDS)):
                return None
            if k + 2 < end and at(tokens, k + 1).kind == "slash" and at(tokens, k + 2).kind == "number":
                if tokens[k + 2].value == 0:
                    return None
                value = token.value / tokens[k + 2].value
                nxt = k + 3
            else:
                value = token.value
                nxt = k + 1
                if nxt < end and at(tokens, nxt).kind == "fraction":
                    value += tokens[nxt].value
                    nxt += 1
                elif (nxt + 2 < end and at(tokens, nxt).kind == "number" and at(tokens, nxt + 1).kind == "slash"
                      and at(tokens, nxt + 2).kind == "number"
                      and tokens[nxt].value > 0 and tokens[nxt].value < tokens[nxt + 2].value):
                    value += tokens[nxt].value / tokens[nxt + 2].value
                    nxt += 3
                elif nxt + 1 < end and at(tokens, nxt).kind == "dash" and at(tokens, nxt + 1).kind == "number":
                    value = (value + tokens[nxt + 1].value) / 2
                    nxt += 2
        elif token.kind == "fraction":
            value = token.value
            nxt = k + 1
        elif token.kind == "word":
            if token.norm not in NUMBERS:
                return None
            value = NUMBERS[token.norm]
            nxt = k + 1
        else:
            return None
        if ((token.kind == "word" or token.kind == "number") and nxt < end and at(tokens, nxt).kind == "word"
                and tokens[nxt].norm in FRACTION_WORDS):
            value /= FRACTION_WORDS[tokens[nxt].norm]
            nxt += 1
        if self.is_word_in(nxt, end, ENERGY):
            return None
        # "skyr 20 g białka": the protein on the label, not an amount ("100 g białka jaj" is one).
        if (self.is_unit(nxt, end) and UNITS[self.tokens[nxt].norm] == ("g", 1.0)
                and self.is_word_in(nxt + 1, end, NUTRIENTS) and not self.is_word_in(nxt + 2, end, PROTEIN_FOODS)):
            return None
        if self.is_word(nxt, end, "i") and self.is_word(nxt + 1, end, "pol"):
            return (value + 0.5, nxt + 2)
        return (value, nxt)

    def cleaned(self, r):
        start, end = r
        if start >= end:
            return ""
        tokens, chars = self.tokens, self.chars
        removed = set()
        unit_words = []
        has_name = False
        for k in rng(start, end):
            token = at(tokens, k)
            if token.kind == "number":
                if not self.is_percentage(k, end):
                    removed.add(k)
            elif token.kind in ("fraction", "slash", "times", "time"):
                removed.add(k)
            elif token.kind == "dash":
                if (k > start and at(tokens, k - 1).kind == "number" and k + 1 < end and at(tokens, k + 1).kind == "number"
                        and not self.is_percentage(k + 1, end)):
                    removed.add(k)
            elif token.kind == "word":
                word = token.norm
                if word in NUMBERS or word in TIMES or word in FILLER:
                    removed.add(k)
                elif word == "i" and k > start and at(tokens, k - 1).is_quantity and self.is_word(k + 1, end, "pol"):
                    removed.add(k)
                elif word in UNITS:
                    unit_words.append(k)
                else:
                    has_name = True
        if has_name:
            removed.update(unit_words)
        for k in rng(start, end - 1):
            if (k in removed and at(tokens, k).kind == "word" and at(tokens, k + 1).kind == "other"
                    and at(chars, tokens[k + 1].start) == "." and tokens[k + 1].start == tokens[k].end):
                removed.add(k + 1)
        out = []
        position = at(tokens, start).start
        for k in rng(start, end):
            if k in removed:
                rng(position, tokens[k].start)
                out.extend(chars[position:tokens[k].start])
                out.append(" ")
                position = tokens[k].end
        rng(position, at(tokens, end - 1).end)
        out.extend(chars[position:tokens[end - 1].end])
        return MealText.trimmed_name(MealText.without_empty_brackets(MealText.collapsed(out)))

    @staticmethod
    def collapsed(characters):
        result = []
        pending = False
        for c in characters:
            if is_whitespace(c):
                pending = len(result) > 0
                continue
            if pending:
                result.append(" ")
                pending = False
            result.append(c)
        return result

    @staticmethod
    def without_empty_brackets(characters):
        result = []
        i = 0
        while i < len(characters):
            if characters[i] == "(":
                j = i + 1
                while j < len(characters) and characters[j] == " ":
                    j += 1
                if j < len(characters) and characters[j] == ")":
                    i = j + 1
                    continue
            result.append(characters[i])
            i += 1
        return result

    @staticmethod
    def trimmed_name(characters):
        def keeps(c):
            return is_letter(c) or is_digit(c) or c == "%"
        s = 0
        e = len(characters)
        while s < e and not keeps(characters[s]):
            s += 1
        while e > s and not keeps(characters[e - 1]):
            rng(s, e - 1)
            if characters[e - 1] == ")" and "(" in characters[s:e - 1]:
                break
            e -= 1
        return "".join(characters[s:e])


class AliasWord:
    def __init__(self, text, descriptive):
        # An adjective that only describes ("surowy", "maślana"), not a dish's own name ("pomidorowa"):
        # "surówka" and "maślanka" are no forms of it.
        self.descriptive = descriptive
        letters = list(text)
        count = len(letters)
        self.text = text
        self.length = count
        if count >= 4 and letters[count - 1] in STEM_VOWELS:
            self.vowel_stem = "".join(letters[0:count - 1])
        else:
            self.vowel_stem = None
        # An adjective's stem is no form of it: "pomidorów" is not "pomidorowa".
        self.bare = count >= 5 and not "".join(letters[0:count - 1]).endswith("ow")
        fleeting = None
        if count >= 4 and letters[count - 2] == "e" and letters[count - 1] not in VOWELS:
            cut = 3 if letters[count - 3] == "i" else 2
            stem = "".join(letters[0:count - cut]) + letters[count - 1]
            if len(stem) >= 3:
                fleeting = stem
        self.fleeting = fleeting
        if count >= 4 and letters[count - 1] in "aoi" and letters[count - 2] == "k" and letters[count - 3] not in VOWELS:
            self.gen_plural = "".join(letters[0:count - 2]) + "ek"
        else:
            self.gen_plural = None


class Alias:
    def __init__(self, words, item, order, singular, single_words):
        self.words = [AliasWord(w, is_adjective(w) and w not in single_words) for w in words]
        self.item = item
        self.order = order
        self.letters = sum(len(w) for w in words)
        self.singular = singular


class Cand:
    def __init__(self, alias, position, quality):
        self.alias, self.position, self.quality = alias, position, quality

    def better(self, other):
        if len(self.alias.words) != len(other.alias.words):
            return len(self.alias.words) > len(other.alias.words)
        if self.position != other.position:
            return self.position < other.position
        if self.quality != other.quality:
            return self.quality > other.quality
        if self.alias.letters != other.alias.letters:
            return self.alias.letters > other.alias.letters
        return self.alias.order < other.alias.order


def has_ending(word, stem, or_none=False):
    if not word.startswith(stem):
        return False
    rest = word[len(stem):]
    return or_none if rest == "" else rest in ENDINGS


def edit_distance(a, b):
    if not a:
        return len(b)
    if not b:
        return len(a)
    d = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
    for i in range(len(a) + 1):
        d[i][0] = i
    for j in range(len(b) + 1):
        d[0][j] = j
    for i in range(1, len(a) + 1):
        for j in range(1, len(b) + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            best = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                best = min(best, d[i - 2][j - 2] + 1)
            d[i][j] = best
    return d[len(a)][len(b)]


def quality(word, alias, typos):
    if word == alias.text:
        return 3
    if word in FALSE_FRIENDS:
        return 0
    if alias.length >= 3 and has_ending(word, alias.text):
        return 2
    # "surówka" is no form of "surowy", "maślanka" none of "maślana".
    if (alias.vowel_stem is not None and has_ending(word, alias.vowel_stem, alias.bare)
            and not (alias.descriptive and word[len(alias.vowel_stem):].startswith("k"))):
        return 2
    if alias.fleeting is not None and has_ending(word, alias.fleeting):
        return 2
    if alias.gen_plural is not None and word == alias.gen_plural:
        return 2
    if typos:
        length = len(word)
        if length >= 5:
            limit = 1 if length <= 7 else 2
            if abs(length - alias.length) <= limit and edit_distance(list(word), list(alias.text)) <= limit:
                return 1
    return 0


class Analysis:
    def __init__(self):
        self.quantity = None
        self.unit = None
        self.name_tokens = []
        self.match = None
        self.quantity_is_decimal = False
        self.quantity_follows_name = False
        self.quantity_inside_name = False

    def copy(self):
        other = Analysis()
        other.__dict__.update(self.__dict__)
        other.name_tokens = list(self.name_tokens)
        return other


class Previous:
    """MealPreviousItem: the item made from the part before, in the same group."""

    def __init__(self, index, part, analysis, match):
        self.index, self.part, self.analysis, self.match = index, part, analysis, match


class Item:
    def __init__(self, **kw):
        self.__dict__.update(kw)

    def __repr__(self):
        return "<%s %r %s %s %sg%s>" % (self.food_id, self.text, self.amount, self.unit, self.grams, " ?" if self.is_guess else "")


class Parser:
    def __init__(self, catalog, user_foods=()):
        keys = []
        entries = {}
        product_names = set()
        sources = ((catalog, False), (user_foods, True))
        for items, is_user in sources:
            for item in items:
                product_names.add(" ".join(MealText.words(item.name)))
                for phrase in [item.name] + list(item.aliases):
                    words = MealText.words(phrase)
                    if not words:
                        continue
                    key = " ".join(words)
                    if key in entries:
                        if is_user and not entries[key][2]:
                            entries[key] = (words, item, True)
                    else:
                        keys.append(key)
                        entries[key] = (words, item, is_user)
        aliases = []
        # One-word names: an adjective that is one ("pomidorowa") names a dish, it does not only describe one.
        single_words = set(k for k in keys if len(entries[k][0]) == 1)
        for order, key in enumerate(keys):
            words, item, _ = entries[key]
            singular = any(" ".join(MealText.words(s)) == key for s in (item.singular or []))
            aliases.append(Alias(words, item, order, singular, single_words))
        self.aliases = aliases
        self.joining_aliases = [a for a in aliases if len(a.words) > 1 and any(is_protectable(w.text) for w in a.words)]
        self.multi_word_aliases = [a for a in aliases if len(a.words) > 1]
        seen = set()
        modifiers = []
        for alias in aliases:
            if len(alias.words) != 2:
                continue
            if any(is_protectable(w.text) for w in alias.words):
                continue
            word = alias.words[1]
            if is_adjective(word.text) and word.text not in product_names and word.text not in seen:
                seen.add(word.text)
                modifiers.append(word)
        self.modifiers = modifiers

    def parse(self, text):
        meal = MealText(text)
        items, unknown = [], []
        start = 0
        n = len(meal.tokens)
        # "kawa z cukrem, z mlekiem": the dish the next fragment may go on with.
        carried = None
        for k in range(0, n + 1):
            if k == n or meal.tokens[k].kind == "separator":
                if start < k:
                    carried = self.parse_chunk(meal, (start, k), carried, items, unknown)
                start = k + 1
        totals = (0.0, 0.0, 0.0, 0.0)
        for it in items:
            totals = tuple(a + b for a, b in zip(totals, it.macros))
        return items, unknown, totals

    def cleaned_name(self, fragment):
        meal = MealText(fragment)
        name = meal.cleaned((0, len(meal.tokens)))
        # String.lowercased() maps scalar by scalar (no final-sigma context, unlike str.lower()).
        return name.lower() if name.isascii() else "".join(ch.lower() for ch in name)

    # MARK: - Segments

    def parse_chunk(self, meal, chunk, carried, items, unknown):
        """Returns the fragment's dish, which the next fragment may go on with."""
        protected = self.protected_tokens(meal, chunk)
        # One dish and what came with it, which a group after "i" may carry on: "kawa z cukrem i mlekiem".
        previous = None
        first_item = None
        # "kawa z cukrem, z mlekiem": a fragment may go on with the dish of the one before.
        if carried is not None and self.goes_on(meal, chunk):
            first_item = carried
        drops_first = False
        with_list = False
        # "kawa bez cukru i mleka": the group before ended under "bez".
        negated_before = False
        for group in meal.split(chunk, JOINING, protected):
            parts = self.separated(meal, meal.split(group, WITH | ON, protected), protected)
            # "kawa bez cukru i z mlekiem": a group that starts with "z" carries the dish on too.
            continues = (first_item is not None and (with_list or meal.is_word_in(group[0], group[1], WITH))
                         and self.carries_on(meal, group))
            if not continues:
                if drops_first and first_item is not None:
                    at(items, first_item.index)  # Swift's remove(at:) traps outside the array
                    del items[first_item.index]
                previous = None
                first_item = None
                drops_first = False
                with_list = False
            # Whether this group was only an add-in left out under the "bez" before it.
            left_out = False
            i = 0
            while i < len(parts):
                part = parts[i]
                soft = self.is_soft(meal, parts, i)
                # Split off at z, ze, na or w, or the first part of a list carried on after "i".
                added = (i > 0 and Parser.follows(meal, part, WITH | ON)) or (i == 0 and continues)
                if i > 0 and Parser.follows(meal, part, WITH):
                    with_list = True
                head = self.analyze(meal, part, protected, not soft)
                if head.match is None and (head.quantity is not None or head.unit is not None) \
                        and Parser.says_how_cooked(meal, part):
                    earlier = previous
                    if earlier is not None and earlier.analysis.quantity is None and earlier.analysis.unit is None:
                        merged = earlier.analysis.copy()
                        merged.quantity = head.quantity
                        merged.unit = head.unit
                        merged.quantity_is_decimal = head.quantity_is_decimal
                        merged.quantity_follows_name = True
                        items[earlier.index] = self.make_item(meal, (earlier.part[0], part[1]), merged, earlier.match)
                    previous = None
                    i += 1
                    continue
                # "pizza z szynką na pół z mężem": shared, so half of the dish and of what came with it
                # ("pół na pół" and "przekrojone na pół" are no share).
                share = head.quantity
                dish = first_item
                if (soft and head.match is None and not head.name_tokens and head.unit is None
                        and share is not None and 0 < share < 1 and dish is not None
                        and not Parser.is_no_share(meal, part)):
                    for index in range(len(items)):
                        if index < dish.index:
                            continue
                        food = self.product(at(items, index).food_id)
                        if food is None:
                            continue
                        items[index].amount *= share
                        items[index].grams *= share
                        items[index].macros = food.macros(items[index].grams)
                    previous = None
                    i += 1
                    continue
                if not head.name_tokens:
                    i += 1
                    continue
                if head.match is not None:
                    match = head.match
                    analysis = head
                    # "kawa bez cukru i mleka": an add-in after "bez … i" was left out too.
                    if (negated_before and len(parts) == 1 and analysis.quantity is None and analysis.unit is None
                            and match.quality == 2 and match.alias.item.id in ADD_INS):
                        left_out = True
                        i += 1
                        continue
                    # "pierś z kurczka", "pomidorwa z ryzem": a typo in the dish's own name, not a second food.
                    earliest = first_item
                    if (earliest is not None and (match.quality == 1 or earliest.match.quality == 1)
                            and Parser.follows(meal, part, WITH) and self.continues_name(meal, head, earliest)):
                        i += 1
                        continue
                    # "pierogi ruskie z cebulką 10 sztuk", "jajka na maśle 2 sztuki": the count is the dish's.
                    if earliest is not None and added and Parser.counts_the_dish(head, earliest, match.alias.item):
                        first_item = self.with_count(meal, items, earliest, head, part)
                        if previous is not None and previous.index == earliest.index:
                            previous = first_item
                        analysis = head.copy()
                        analysis.quantity = None
                        analysis.unit = None
                        analysis.quantity_is_decimal = False
                        analysis.quantity_follows_name = False
                    # "mleko do kawy": a splash, not a glass.
                    if (analysis.quantity is None and analysis.unit is None and match.alias.item.id in MILKS
                            and any(meal.is_word(k, part[1], "do") and meal.is_word_in(k + 1, part[1], FOR_DRINKS)
                                    for k in rng(part[0], part[1]))):
                        splash = analysis.copy()
                        splash.quantity = SPLASH_MILLILITRES
                        splash.unit = ("g", 1.0)
                        items.append(self.make_item(meal, part, splash, match))
                        previous = None
                        i += 1
                        continue
                    dish = first_item
                    if (dish is not None and analysis.quantity is None and analysis.unit is None
                            and match.alias.item.id in MILKS):
                        dish_id = at(items, dish.index).food_id
                        if dish_id in MILK_DISHES:
                            previous = None
                            i += 1
                            continue
                        if dish_id in SPLASH_DRINKS:
                            splash = analysis.copy()
                            splash.quantity = SPLASH_MILLILITRES
                            splash.unit = ("g", 1.0)
                            items.append(self.make_item(meal, part, splash, match))
                            previous = None
                            i += 1
                            continue
                    earliest = first_item
                    if (earliest is not None and not drops_first and analysis.quantity is not None
                            and Parser.follows(meal, part, WITH)
                            and self.is_made_of(match.alias.item, Parser.first_word(meal, earliest),
                                                earliest.match.quality == 1)):
                        drops_first = True
                    items.append(self.make_item(meal, part, analysis, match))
                    previous = Previous(len(items) - 1, part, analysis, match)
                    if first_item is None:
                        first_item = previous
                    # "pierogi z mięsem i cebulką": a name with "z" in it starts the list too.
                    if any(w.text in WITH for w in match.alias.words):
                        with_list = True
                    i += 1
                    continue
                if soft:
                    i += 1
                    continue
                # "koktajl z banana i szpinaku": a smoothie is what went into it, counted food by food.
                if (len(head.name_tokens) == 1 and meal.tokens[head.name_tokens[0]].norm in CONTAINERS
                        and i + 1 < len(parts) and Parser.follows(meal, parts[i + 1], WITH)):
                    previous = None
                    i += 1
                    continue
                # "pączek z lukrem 2 sztuki": a count after something unknown that came with the dish.
                earliest = first_item
                if earliest is not None and added and Parser.counts_the_dish(head, earliest, None):
                    first_item = self.with_count(meal, items, earliest, head, part)
                last = part[1]
                j = i + 1
                while j < len(parts):
                    if self.is_soft(meal, parts, j) or not Parser.follows(meal, parts[j], WITH | ON):
                        break
                    following = self.analyze(meal, parts[j], protected, True)
                    if following.quantity is not None or following.unit is not None:
                        # "pyzy z mięsem 4 sztuki", "pyzy z mięsem 1 porcja": a count after what came with an unknown
                        # dish counts the dish, unless that is counted in pieces itself ("… z jajkami 2 sztuki").
                        is_count = (following.unit is None or following.unit == ("p", "piece")
                                    or following.unit == ("p", "serving"))
                        counts_dish = (following.quantity is not None and following.quantity_follows_name and is_count
                                       and (following.match is None
                                            or following.match.alias.item.default[0] != "piece"))
                        if not counts_dish:
                            break
                    if following.name_tokens:
                        last = parts[j][1]
                    j += 1
                name = meal.cleaned((part[0], last))
                if sum(1 for c in graphemes(name) if is_letter(c)) >= 2:
                    unknown.append(name)
                previous = None
                i = j
            # "kawa bez cukru i mleka": the group ended under "bez".
            if parts:
                last = parts[-1]
                negated_before = left_out or any(meal.is_word(k, last[1], NEG) and k not in protected
                                                 for k in rng(last[0], last[1]))
        if drops_first and first_item is not None:
            at(items, first_item.index)  # Swift's remove(at:) traps outside the array
            del items[first_item.index]
            return None
        return first_item

    def goes_on(self, meal, chunk):
        """Whether a fragment goes on with the dish of the one before: it starts with "z" and an amount ("jajecznica,
        z 3 jajek") or a food in the form it takes after "z" ("kawa z cukrem, z mlekiem"), not with a name or a dish
        of its own ("Z Kasią kawa", "z pizza")."""
        if not meal.is_word_in(chunk[0], chunk[1], WITH):
            return False
        for k in rng(chunk[0] + 1, chunk[1]):
            token = at(meal.tokens, k)
            if token.is_quantity:
                return True
            if token.kind != "word":
                continue
            word = token.norm
            if word in UNITS:
                return True
            if word in FILLER:
                continue
            instrumental = (nfc(at(meal.chars, token.end - 1)) in INSTRUMENTAL_LETTERS
                            or any(word.endswith(e) for e in INSTRUMENTAL_ENDINGS))
            return instrumental and self.best_match([word], False) is not None
        return False

    def carries_on(self, meal, group):
        """Whether a group after "i" carries on what came with the dish: "kawa z cukrem i mlekiem" (the form
        of a food after "z"), "kurczak z ryżem i z surówką"."""
        if meal.is_word_in(group[0], group[1], WITH):
            return True
        for k in rng(group[0], group[1]):
            token = at(meal.tokens, k)
            if token.kind != "word" or token.norm in NUMBERS or token.norm in FILLER:
                continue
            return (nfc(at(meal.chars, token.end - 1)) in INSTRUMENTAL_LETTERS
                    or any(token.norm.endswith(e) for e in INSTRUMENTAL_ENDINGS))
        return False

    @staticmethod
    def counts_the_dish(analysis, earliest, food):
        """Whether a count written after what came with the dish counts the dish: "pierogi z cebulką 10 sztuk",
        "chleb z masłem 2 kromki", but not "barszcz z uszkami 12 sztuk" or "jogurt grecki z granolą 2 łyżki"."""
        if analysis.quantity is None or not analysis.quantity_follows_name:
            return False
        if earliest.analysis.quantity is not None or earliest.analysis.unit is not None:
            return False
        dish = earliest.match.alias.item
        unit = analysis.unit
        if unit is None or unit == ("p", "piece"):
            if dish.default[0] in COUNTED_DISHES:
                return True
            if food is not None and food.default[0] == "piece":
                return False
            return Parser.lists(dish, "piece")
        if unit[0] == "p":
            return Parser.lists(dish, unit[1]) and not (food is not None and Parser.lists(food, unit[1]))
        return False

    @staticmethod
    def lists(item, unit):
        return item.default[0] == unit or any(u == unit for u, _ in item.portions)

    def with_count(self, meal, items, earliest, analysis, part):
        """The dish rebuilt with the count written after what came with it."""
        merged = earliest.analysis.copy()
        merged.quantity = analysis.quantity
        merged.unit = analysis.unit
        merged.quantity_is_decimal = analysis.quantity_is_decimal
        merged.quantity_follows_name = True
        items[earliest.index] = self.make_item(meal, (earliest.part[0], part[1]), merged, earliest.match)
        return Previous(earliest.index, earliest.part, merged, earliest.match)

    def is_made_of(self, item, word, typos):
        for alias in self.joining_aliases:
            if (alias.item.id == item.id and len(alias.words) >= 3 and alias.words[1].text in WITH
                    and quality(word, alias.words[0], typos) > 0):
                return True
        return False

    def continues_name(self, meal, analysis, dish):
        """Whether the part is the rest of the dish's own name "<dish> z …", with a typo in one of them."""
        match = analysis.match
        if match is None:
            return False
        word = meal.tokens[at(analysis.name_tokens, match.position)].norm
        first = Parser.first_word(meal, dish)
        typos = dish.match.quality == 1
        for alias in self.joining_aliases:
            if (alias.item.id == dish.match.alias.item.id and len(alias.words) >= 3 and alias.words[1].text in WITH
                    and quality(first, alias.words[0], typos) > 0 and quality(word, alias.words[2], True) > 0):
                return True
        return False

    @staticmethod
    def first_word(meal, earlier):
        return meal.tokens[at(earlier.analysis.name_tokens, earlier.match.position)].norm

    @staticmethod
    def is_no_share(meal, part):
        """Whether the word before "na" makes "na pół" no share: "pół na pół" is half and half,
        "przekrojone na pół" only cut."""
        if part[0] < 2:
            return False
        k = part[0] - 2
        return meal.is_word(k, part[0], "pol") or meal.is_word_starting(k, part[0], CUT_STEMS)

    @staticmethod
    def is_soft(meal, parts, index):
        return index > 0 and Parser.follows(meal, at(parts, index), ON)

    @staticmethod
    def follows(meal, part, words):
        return part[0] > 0 and meal.is_word_in(part[0] - 1, len(meal.tokens), words)

    @staticmethod
    def says_how_cooked(meal, part):
        cooked = False
        for k in rng(part[0], part[1]):
            if meal.tokens[k].kind != "word":
                continue
            word = meal.tokens[k].norm
            if word in PREPARATION or word in MANNER:
                cooked = True
            elif word not in NUMBERS and word not in UNITS and word not in FILLER and word not in TIMES:
                return False
        return cooked

    def protected_tokens(self, meal, chunk):
        protected = set()
        words = [k for k in rng(chunk[0], chunk[1])
                 if meal.tokens[k].kind == "word" and not is_never_name(meal.tokens[k].norm)]
        for alias in self.joining_aliases:
            count = len(alias.words)
            if not len(words) >= count:
                continue
            for s in range(0, len(words) - count + 1):
                matches = True
                for t in range(count):
                    if quality(meal.tokens[words[s + t]].norm, alias.words[t], False) == 0:
                        matches = False
                        break
                if not matches:
                    continue
                if self.starts_inside_another_name(meal, words, s, alias):
                    continue
                for t in range(count):
                    if is_protectable(alias.words[t].text):
                        k = words[s + t]
                        if not meal.is_unit(k + 1, chunk[1]):
                            protected.add(k)
        if chunk[1] - chunk[0] >= 3:
            for k in rng(chunk[0] + 1, chunk[1] - 1):
                if meal.is_word(k, chunk[1], "i") and meal.is_word(k + 1, chunk[1], "pol") and at(meal.tokens, k - 1).is_quantity:
                    protected.add(k)
        return protected

    def starts_inside_another_name(self, meal, words, s, alias):
        if s == 0:
            return False
        for other in self.multi_word_aliases:
            if other.item.id == alias.item.id:
                continue
            count = len(other.words)
            for t in range(1, count):
                begin = s - t
                if begin < 0 or begin + count > len(words):
                    continue
                matches = True
                for u in range(count):
                    if quality(meal.tokens[words[begin + u]].norm, other.words[u], False) == 0:
                        matches = False
                        break
                if matches:
                    return True
        return False

    # MARK: - Foods typed without commas

    def separated(self, meal, parts, protected):
        result = []
        pending = list(reversed(parts))
        while pending:
            part = pending.pop()
            cut = self.second_food(meal, part, protected)
            if cut is not None and part[0] < cut < part[1]:
                pending.append((cut, part[1]))
                pending.append((part[0], cut))
            else:
                result.append(part)
        return result

    def second_food(self, meal, part, protected):
        head = self.analyze(meal, part, protected, False)
        match = head.match
        if match is None or len(head.name_tokens) > MAX_SEPARATED_WORDS:
            return None
        names = head.name_tokens
        first = match.position
        last = first + len(match.alias.words)
        j = last
        while j < len(names):
            k = names[j]
            word = meal.tokens[k].norm
            if word == "do" and not meal.is_word_in(k + 1, part[1], BESIDES):
                break
            other = self.separate_food(meal, k, match)
            if other is not None and not (j == last and self.belongs_to_head(meal, names, match, word)):
                start = Parser.amount_start(meal, k, at(names, j - 1))
                genitive = word.endswith("a") or word.endswith("u")
                if (start == k and other.quality < 3 and match.quality == 3 and genitive
                        and other.alias.item.category in GENITIVE_FOODS and not Parser.follows(meal, part, WITH)):
                    j += 1
                    continue
                return self.cut(meal, part, k, start, other.quality == 3, protected)
            j += 1
        for b in range(0, first):
            other = self.separate_food(meal, names[b], match)
            if other is not None and other.alias.item.category != match.alias.item.category:
                k = names[first]
                start = Parser.amount_start(meal, k, at(names, first - 1))
                return self.cut(meal, part, k, start, match.quality == 3, protected)
        if first == 0:
            k = names[0]
            start = Parser.amount_start(meal, k, part[0])
            if start < k and Parser.says_how_cooked(meal, (part[0], start)):
                return self.cut(meal, part, k, start, match.quality == 3, protected)
        return None

    def separate_food(self, meal, k, head):
        word = at(meal.tokens, k).norm
        if word in NAMED_AFTER_NUMBER and k > 0 and meal.tokens[k - 1].is_quantity:
            return None
        # "rosół schabowy", "zupa pomidorowa mielony": after a dish, a dish named by an adjective is a second food.
        names_dish = word in DISH_ADJECTIVES and head.alias.item.category == "dishes"
        other = self.best_match([word], False)
        if (other is None or other.alias.item.id == head.alias.item.id
                or (self.is_modifier(word) and not names_dish)):
            return None
        return other

    def belongs_to_head(self, meal, names, match, word):
        if at(match.alias.words, len(match.alias.words) - 1).text in FLAVOURED:
            return True
        if len(match.alias.words) == 1:
            pair = self.best_match([word, at(meal.tokens, at(names, match.position)).norm], False)
            return pair is not None and len(pair.alias.words) == 2 and pair.alias.item.id == match.alias.item.id
        return False

    def is_modifier(self, word):
        for m in self.modifiers:
            if word == m.text:
                return True
            if m.vowel_stem is not None and word.startswith(m.vowel_stem) and word[len(m.vowel_stem):] in ADJECTIVE_FORMS:
                return True
        return False

    @staticmethod
    def amount_start(meal, k, floor):
        start = k
        while start - 1 > floor and meal.is_amount_token(start - 1):
            start -= 1
        return start

    def cut(self, meal, part, k, start, plain_second, protected):
        if start == k:
            return k
        # "2 jajka 4 kromki chleba 2 plastry sera": an amount with a food after it is that food's,
        # so the second food is read only up to it.
        second_end = part[1]
        for m in rng(k + 1, part[1]):
            found = meal.quantity(m, part[1])
            if found is None:
                continue
            nxt = found[1] + 1 if meal.is_unit(found[1], part[1]) else found[1]
            if meal.has_name_word((nxt, part[1])):
                second_end = m
            break
        second = self.analyze(meal, (k, second_end), protected, False)
        first = self.analyze(meal, (part[0], start), protected, False)
        if second.quantity is not None or (first.quantity is None and plain_second):
            return k
        return start

    # MARK: - One fragment

    def analyze(self, meal, part, protected, typos):
        result = Analysis()
        end = part[1]
        used = set()
        unit_token = None
        quantity_token = None
        q = part[0]
        while q < end:
            found = meal.quantity(q, end)
            if found is None:
                q += 1
                continue
            if meal.is_word_in(found[1], end, NAMED_AFTER_NUMBER) and meal.has_name_word((part[0], q)):
                q = found[1]
                continue
            value, after = found
            is_decimal = at(meal.tokens, q).kind == "number" and after == q + 1 and value != round_half_away(value)
            used.update(rng(q, after))
            # "2 pączki" is a count of doughnuts, not of packages.
            if meal.is_unit(after, end) and not meal.is_doughnut(after):
                unit_token = after
                after += 1
            if meal.is_times(after, end) and after + 1 < end:
                second = meal.quantity(after + 1, end)
                if second is not None:
                    used.update(rng(after, second[1]))
                    value *= second[0]
                    is_decimal = False
                    after = second[1]
                    if meal.is_unit(after, end) and not meal.is_doughnut(after):
                        unit_token = after
            if is_finite(value) and value <= MAX_AMOUNT:
                quantity_token = q
                result.quantity = value
                result.quantity_is_decimal = is_decimal
                result.quantity_follows_name = meal.has_name_word((part[0], q))
            else:
                unit_token = None
            break
        names, unit_words = [], []
        negated = False
        for k in rng(part[0], part[1]):
            token = meal.tokens[k]
            if not (token.kind == "word" and k not in used):
                continue
            word = token.norm
            if word == NEG and k not in protected:
                negated = True
            if negated:
                continue
            if word in NUMBERS or word in TIMES or word in FILLER or word in PREPARATION:
                continue
            if is_joining(word) and k not in protected:
                continue
            if word in UNITS and not meal.is_doughnut(k):
                unit_words.append(k)
                continue
            names.append(k)
        loose = [k for k in unit_words
                 if not (k > part[0] and at(meal.tokens, k - 1).is_quantity and (k - 1) not in used)]
        if unit_token is not None:
            result.unit = UNITS[meal.tokens[unit_token].norm]
        elif loose and (result.quantity is not None or meal.tokens[loose[0]].norm not in UNIT_SYMBOLS):
            result.unit = UNITS[meal.tokens[loose[0]].norm]
        if names:
            result.name_tokens = names
            # "kawa z Kasią": a capitalised word right after another word is a name, never a typo of a food.
            is_name = any(k > 0 and at(meal.tokens, k - 1).kind == "word"
                          and at(meal.chars, meal.tokens[k].start).isupper() for k in names)
            result.match = self.best_match([meal.tokens[k].norm for k in names], typos and not is_name)
            # "sok z 4 pomarańczy": the count stands inside the name.
            match = result.match
            if quantity_token is not None and match is not None and len(match.alias.words) > 1:
                result.quantity_inside_name = (at(names, match.position) < quantity_token
                                               < at(names, match.position + len(match.alias.words) - 1))
        elif unit_words:
            match = self.best_match([meal.tokens[k].norm for k in unit_words], False)
            if match is not None:
                result.unit = None
                result.name_tokens = unit_words
                result.match = match
        return result

    def make_item(self, meal, span, analysis, match):
        item = match.alias.item
        q = analysis.quantity
        u = analysis.unit
        if u is not None and u[0] == "g":
            amount = (1.0 if q is None else q) * u[1]
            unit = None
            grams = amount
        elif u is not None:
            amount = 1.0 if q is None else q
            unit = u[1]
            grams = amount * item.grams_per(unit)
        else:
            count = None if (q == 0 and item.category == "drinks") else q
            if (count is not None and count < 3 and analysis.quantity_is_decimal and analysis.quantity_follows_name
                    and item.category == "drinks"):
                amount = count * 1000
                unit = None
                grams = amount
            elif count is not None and count > 20:
                amount = count
                unit = None
                grams = count
            elif count is not None and analysis.quantity_inside_name and item.category == "drinks":
                # "sok z 4 pomarańczy": the juice of four oranges, not four glasses.
                amount = count * JUICE_PER_FRUIT
                unit = None
                grams = amount
            elif count is not None:
                portion = Parser.counted_portion(item)
                amount = count
                unit = portion[0]
                grams = count * portion[1]
            else:
                serving = None
                for pu, pg in item.portions:
                    if pu == "serving":
                        serving = pg
                        break
                if serving is not None and item.default[0] != "serving" and not Parser.names_one_piece(meal, analysis, match):
                    amount = 1.0
                    unit = "serving"
                    grams = serving
                else:
                    amount = 1.0
                    unit = item.default[0]
                    grams = item.default[1]
        first = at(meal.tokens, span[0]).start
        last = at(meal.tokens, span[1] - 1).end
        return Item(text="".join(meal.chars[first:last]), food_id=item.id, food_name=item.name, amount=amount,
                    unit=unit, grams=grams, macros=item.macros(grams), is_guess=match.quality == 1)

    @staticmethod
    def names_one_piece(meal, analysis, match):
        if not match.alias.item.singular:
            return False
        if match.quality == 3:
            return match.alias.singular
        word = meal.tokens[at(analysis.name_tokens, match.position)].norm
        return match.quality == 2 and any(word.endswith(e) for e in SINGULAR_ENDINGS)

    @staticmethod
    def counted_portion(item):
        if item.default[0] == "serving" or item.default[0] == "chunk":
            for pu, pg in item.portions:
                if pu == "piece":
                    if pg > item.default[1]:
                        return (pu, pg)
                    break
        return item.default

    def product(self, id):
        """The product an item was made from (an item always has one)."""
        for alias in self.aliases:
            if alias.item.id == id:
                return alias.item
        return None

    # MARK: - Matching

    def best_match(self, words, typos):
        found = self.best_candidate(words, False)
        if found is not None:
            return found
        return self.best_candidate(words, True) if typos else None

    def best_candidate(self, words, typos):
        best = None
        for alias in self.aliases:
            count = len(alias.words)
            if not len(words) >= count:
                continue
            for s in range(0, len(words) - count + 1):
                q = 3
                for t in range(count):
                    q = min(q, quality(words[s + t], alias.words[t], typos))
                    if q == 0:
                        break
                if q == 0:
                    continue
                cand = Cand(alias, s, q)
                if best is not None and not cand.better(best):
                    continue
                best = cand
        return best


def round_half_away(x):
    """Double.rounded() in Swift: to the nearest, halves away from zero (inf and nan stay)."""
    if not is_finite(x):
        return x
    import math
    return math.floor(x + 0.5) if x >= 0 else math.ceil(x - 0.5)


def is_finite(x):
    return x == x and x not in (float("inf"), float("-inf"))
