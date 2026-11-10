# -*- coding: utf-8 -*-
"""Fourth set: made-up phrases from the food review (catalog-values, parser-real-meals and parser-swift-safety
findings) that the catalog and the parser now handle. Kept so later parser or catalog changes cannot quietly
undo those fixes. Bare mentions name only the product, so a later rule may change which portion a bare name
uses; the parser's part pins the portion where the rule is about it."""

P = []


def E(text, *items, unknown=()):
    P.append((text, list(items), list(unknown)))


# A bowl of flakes or snacks is the dry weight in the bowl, not 350 g.
E("miska płatków z mlekiem", ("platki-owsiane", 1, "bowl"), "mleko")
E("miseczka płatków kukurydzianych", ("platki-kukurydziane", 1, "bowl"))
E("miska musli z jogurtem", ("musli", 1, "bowl"), "jogurt-naturalny")
E("miska granoli", ("granola", 1, "bowl"))
E("miska popcornu", ("popcorn", 1, "bowl"))
E("miska chipsów", ("chipsy", 1, "bowl"))
E("miseczka orzechów", ("orzechy", 1, "bowl"))
E("pół szklanki granoli", ("granola", 0.5, "glass"))

# Milk drinks already contain their milk; "owsiane" alone is no longer oat flakes.
E("latte na owsianym", "latte")
E("latte z owsianym", "latte")
E("kawa z owsianym", "kawa-z-mlekiem")
E("kawa na owsianym", "kawa-z-mlekiem")
E("latte z mlekiem owsianym", "latte")
E("cappuccino na mleku owsianym", "cappuccino")
E("cappuccino z mlekiem sojowym", "cappuccino")
E("latte na mleku bez laktozy", "latte")
E("flat white na owsianym", "cappuccino")
E("owsiane latte", "latte")
E("kawa z napojem owsianym", "kawa-z-mlekiem")
E("americano z mlekiem", "kawa-z-mlekiem")
E("kawa z pianką", "kawa-z-mlekiem")
E("herbata z mlekiem", "herbata-z-mlekiem")
E("kakao z mlekiem", "kakao")
E("50 g płatków owsianych", ("platki-owsiane", 50, None))

# Lean meat as eaten, raw meat on its own.
E("150 g kurczaka z grilla", ("piers-z-kurczaka", 150, None))
E("200 g surowego kurczaka", ("piers-z-kurczaka-surowa", 200, None))
E("150 g surowej piersi z kurczaka", ("piers-z-kurczaka-surowa", 150, None))
E("surowy indyk 150 g", ("indyk-surowy", 150, None))
E("200 g surowej polędwiczki", ("poledwiczka-surowa", 200, None))
E("200 g polędwiczki", ("poledwiczka", 200, None))
E("polędwiczki z kurczaka", "piers-z-kurczaka")
E("200 g twarogu chudego", ("twarog-chudy", 200, None))

# Cutlets that are not a pork schabowy.
E("kotlet z piersi kurczaka", "kotlet-z-kurczaka")
E("kotlet z indyka", "kotlet-z-kurczaka")
E("kotlet sojowy", "kotlet-warzywny")
E("kotlet z ciecierzycy", "kotlet-warzywny")
E("kotlet mielony z indyka", "kotlet-mielony")

# Cocoa, chunks, mugs, portions.
E("owsianka z kakao i bananem", "owsianka", "banan")
E("łyżeczka kakao w proszku", ("kakao-w-proszku", 1, "teaspoon"))
E("kawałek łososia", ("losos", 1, "chunk"))
E("kawałek kurczaka", ("piers-z-kurczaka", 1, "chunk"))
E("kubek jogurtu", ("jogurt-naturalny", 1, "mug"))
E("porcja sernika", ("sernik", 1, "serving"))
E("kawałek tiramisu", ("tiramisu", 1, "chunk"))
E("2 kawałki lasagne", ("lasagne", 2, "chunk"))
E("2 plastry karkówki z grilla", ("karkowka", 2, "thinSlice"))
E("plaster arbuza", ("arbuz", 1, "thinSlice"))

# Juice, dips, ham.
E("szklanka soku wiśniowego", ("sok", 1, "glass"))
E("szklanka soku z malin", ("syrop-malinowy", 1, "glass"))
E("herbata z sokiem z malin", "herbata", ("syrop-malinowy", 1, "tablespoon"))
E("2 łyżki tzatziki", ("tzatziki", 2, "tablespoon"))
E("3 plastry szynki parmeńskiej", ("szynka-parmenska", 3, "thinSlice"))

# A count of small things counts the things, not servings.
E("parę frytek", ("frytki", 2, "piece"))
E("kilka chipsów", ("chipsy", 3, "piece"))
E("kilka borówek", ("borowki", 3, "piece"))
E("5 suszonych śliwek", ("suszone-owoce", 5, "piece"))
E("3 żeberka", ("zeberka", 3, "piece"))
E("2 paluszki rybne", ("paluszki-rybne", 2, "piece"))
E("frytki", "frytki")
E("paluszki rybne", "paluszki-rybne")

# Dishes counted together with their own ingredient.
E("jajecznica 2 jajka", ("jajko", 2, "piece"))
E("omlet 2 jajka ze szpinakiem", ("jajko", 2, "piece"), "szpinak")
E("owsianka (40 g płatków)", ("platki-owsiane", 40, None))
E("nuggetsy z kurczaka 9 sztuk", ("nuggetsy", 9, "piece"))
E("frytki z batatów", "frytki-z-batatow")
E("rosół z kurczaka z makaronem", "rosol")
E("drożdżówka z budyniem", "drozdzowka")
E("kebab z kurczakiem", "kebab")
E("ziemniaki z wody 300 g", ("ziemniaki", 300, None))

# Dishes and sweets that used to be guessed as something else.
E("dorsz w panierce z frytkami", "ryba-panierowana", "frytki")
E("smażony ser z frytkami", "ser-smazony", "frytki")
E("placek po węgiersku", "placek-po-wegiersku")
E("kanapka z pastą warzywną", "chleb", "pasta-warzywna")
E("barszcz z pasztecikiem", "barszcz", "krokiety")
E("serek danio", "serek-homogenizowany")
E("zupka chińska", "ramen")
E("80 g makaronu na sucho", ("makaron-suchy", 80, None))
E("żurek w chlebie", "zurek-w-chlebie")
E("papryka faszerowana", "papryka-faszerowana")
E("filet z mintaja", "ryba")
E("rurki z kremem", "rurki-z-kremem")
E("pierożki z mięsem", "pierogi-z-miesem")
E("serniczek", "sernik")
E("kremówka", "kremowka")
E("grzaniec", "wino")
E("2 ptasie mleczka", ("ptasie-mleczko", 2, "piece"))
E("woda z lodem", "woda", "lod")
E("makaron bolognese", "spaghetti-bolognese")
E("pizza salami", "pizza")
E("truskawki w czekoladzie", "truskawki", "czekolada")
E("żeberka w miodzie", "zeberka", "miod")

# Sugar-free drinks.
E("cola bez cukru", "cola-zero")
E("fanta zero", "cola-zero")
E("monster zero", "energetyk-zero")
E("red bull bez cukru", "energetyk-zero")


# ---------------------------------------------------------------- parser rules
# Sentences end a fragment; "szt." and "ok." do not.
E("Jabłko. Banan.", "jablko", "banan")
E("Jajecznica z 3 jajek. Kromka chleba. Pomidor.", ("jajko", 3, "piece"), ("chleb", 1, "slice"), "pomidor")
E("Owsianka z bananem. Kawa z mlekiem.", "owsianka", "banan", "kawa-z-mlekiem")
E("Kawa bez cukru. Ciastko.", "kawa", ("ciastko", 1, "piece"))
E("2. kawa", ("kawa", 1, "mug"))
E("Ryż 100 g. Kurczak 150 g.", ("ryz", 100, None), ("piers-z-kurczaka", 150, None))
E("3 szt. jajek", ("jajko", 3, "piece"))
# A clock time is no amount.
E("8:30 owsianka z bananem", ("owsianka", 1, "bowl"), "banan")
E("7:30 owsianka, 13:00 zupa pomidorowa, 19:00 2 kanapki z serem", ("owsianka", 1, "bowl"),
  ("zupa-pomidorowa", 1, "serving"), ("chleb", 2, "slice"), "ser-zolty")
E("21:30 jogurt naturalny", ("jogurt-naturalny", 1, "package"))
E("8.30 owsianka", ("owsianka", 1, "bowl"))
E("12.30 kanapka z serem", ("chleb", 1, "slice"), "ser-zolty")
E("8:30 szakszuka", unknown=["szakszuka"])
E("1.50 kg ziemniaków", ("ziemniaki", 1500, None))
# Energy from the wrapper is no amount.
E("baton 250 kcal", ("baton", 1, "piece"))
E("baton 200-250 kcal", ("baton", 1, "piece"))
E("kanapka z serem 300 kcal", ("chleb", 1, "slice"), ("ser-zolty", 1, "serving"))
E("jogurt naturalny 120 kcal", ("jogurt-naturalny", 1, "package"))
E("szakszuka 300 kcal", unknown=["szakszuka"])
# A size letter is no litre; a run of digits is no amount.
E("frytki L", ("frytki", 1, "serving"))
E("pizza L", ("pizza", 1, "piece"))
E("kawa latte L", ("latte", 1, "mug"))
E("99999999999999999999 g masła", ("maslo", 1, "teaspoon"))
E("woda 99999999999999999999", ("woda", 1, "glass"))

# Foods typed without commas.
E("kurczak ryż brokuł", "piers-z-kurczaka", "ryz", "brokul")
E("jogurt granola banan", "jogurt-naturalny", "granola", "banan")
E("kanapka szynka ser pomidor", "chleb", "szynka", "ser-zolty", "pomidor")
E("2 jajka chleb pomidor", ("jajko", 2, "piece"), "chleb", "pomidor")
E("owsianka banan orzechy", "owsianka", "banan", "orzechy")
E("schabowy ziemniaki surówka", "kotlet-schabowy", "ziemniaki", "surowka")
E("kurczak ryż i brokuł", "piers-z-kurczaka", "ryz", "brokul")
E("jajecznica z 3 jajek 2 kromki chleba", ("jajko", 3, "piece"), ("chleb", 2, "slice"))
E("owsianka z bananem kawa z mlekiem", "owsianka", "banan", "kawa-z-mlekiem")
E("kurczak 150 g ryż", ("piers-z-kurczaka", 150, None), ("ryz", 1, "serving"))
E("kawa ciastka", "kawa", ("ciastko", 1, "serving"))
E("herbata ciasto", "herbata", "ciasto")
# ... but a name of two words stays whole.
E("herbata miętowa", "herbata")
E("jogurt grecki", "jogurt-grecki")
E("chleb tostowy", "chleb-tostowy")
E("ser feta", "feta")
E("makaron carbonara", "makaron-carbonara")
E("kurczak curry", "curry")
E("pizza margherita", "pizza")
E("bułka grahamka", "grahamka")
E("woda gazowana", "woda")
E("pizza pepperoni", "pizza")
E("ryż curry", "ryz")
E("jaglana owsianka", "owsianka")
E("kawa cappuccino", "cappuccino")
E("wafelek prince polo", "baton")
E("miód do herbaty", "miod")
E("sos curry", "sos")
E("rosół kurczaka", "rosol")
E("udko indyka", "udko-kurczaka")

# Milk in coffee or tea is a splash; milk drinks and dishes already have theirs.
E("czarna kawa z mlekiem", "kawa", ("mleko", 30, None))
E("herbata zielona z mlekiem", "herbata", ("mleko", 30, None))
E("kawa mrożona z owsianym", "kawa", ("mleko-owsiane", 30, None))
E("kawa z kroplą mleka", "kawa", ("mleko", 1, "teaspoon"))
E("budyń waniliowy na mleku", "budyn")
E("naleśniki na mleku", "nalesniki")
E("owsianka z kakao na mleku", "owsianka")
E("owsianka na owsianym", "owsianka")
E("matcha latte na mleku owsianym", "latte")
E("owsianka z łyżeczką kakao", ("owsianka", 1, "bowl"), "kakao")

# A count of something big counts whole ones; a cube is one cube.
E("pół melona", ("melon", 0.5, "piece"))
E("pół ananasa", ("ananas", 0.5, "piece"))
E("pół bagietki", ("bagietka", 0.5, "piece"))
E("pół makreli", ("makrela", 0.5, "piece"))
E("pół kaszanki", ("kaszanka", 0.5, "piece"))
E("2 kolby kukurydzy", ("kukurydza", 2, "piece"))
E("kostka czekolady", ("czekolada", 1, "piece"))
E("2 kostki czekolady", ("czekolada", 2, "piece"))
E("kostka gorzkiej czekolady", ("czekolada-gorzka", 1, "piece"))
E("kostka cukru", ("cukier", 1, "piece"))
E("pół kostki twarogu", ("twarog", 0.5, "piece"))
E("kostka tofu", ("tofu", 1, "piece"))
# A singular is one piece, a plural the serving.
E("naleśnik z dżemem", ("nalesniki", 1, "piece"), "dzem")
E("gołąbek", ("golabki", 1, "piece"))
E("parówka z ketchupem", ("parowki", 1, "piece"), "ketchup")
E("kabanos", ("kabanosy", 1, "piece"))
E("pieróg ruski", ("pierogi-ruskie", 1, "piece"))
E("skrzydełko", ("skrzydelka", 1, "piece"))
E("placek ziemniaczany", ("placki-ziemniaczane", 1, "piece"))
E("pulpet", ("pulpety", 1, "piece"))
E("jajka na twardo", ("jajko", 1, "serving"))
E("kanapka z jajkiem", "chleb", ("jajko", 1, "piece"))
E("ciastka", ("ciastko", 1, "serving"))
E("kawa z ciastkiem", "kawa", ("ciastko", 1, "piece"))
# "porcja" of a product with no serving of its own is its usual amount.
E("porcja kotleta schabowego", ("kotlet-schabowy", 1, "serving"))
E("porcja masła", ("maslo", 1, "serving"))

# An amount after the cooking words belongs to the food.
E("kurczak z grilla 400 g", ("piers-z-kurczaka", 400, None))
E("łosoś z piekarnika 200g", ("losos", 200, None))
E("dorsz na parze 180 g", ("dorsz", 180, None))
E("pierś z kurczaka z patelni 200 g", ("piers-z-kurczaka", 200, None))
E("jajka na twardo 3 sztuki", ("jajko", 3, "piece"))
E("jajka na twardo 2 szt.", ("jajko", 2, "piece"))
E("kurczak z grilla 250 g ryż", ("piers-z-kurczaka", 250, None), ("ryz", 1, "serving"))
E("pizza na 2 osoby", ("pizza", 1, "piece"))

# Handfuls, bites and sips.
E("2 garście orzechów nerkowca", ("nerkowce", 2, "handful"))
E("dwie garście winogron", ("winogrona", 2, "handful"))
E("kilka kęsów pizzy", ("pizza", 3, "tablespoon"))
E("kęs ciasta", ("ciasto", 1, "tablespoon"))
E("parę łyków coli", ("cola", 2, "tablespoon"))
E("łyk soku", ("sok", 1, "tablespoon"))

# The meal, the place and the company are no food and nothing to teach.
E("kolacja z przyjaciółką: pizza i wino", "pizza", "wino")
E("zjadłam z koleżanką pizzę", "pizza")
E("obiad w pracy: sałatka z kurczakiem", "salatka", "piers-z-kurczaka")
E("lunch na mieście: zupa dnia i makaron", "zupa-jarzynowa", "makaron")
E("pół pizzy z chłopakiem", ("pizza", 0.5, "piece"))
E("kawa z koleżanką", "kawa")
E("wino z mężem", "wino")
E("lasagne z pizzerii", "lasagne")
E("makaron z pizzerii", "makaron")
E("pizza z pizzerii obok pracy", "pizza")
E("kawa z costy", "kawa")
E("latte ze starbucksa", "latte")
E("kawa z automatu", "kawa")

# A number of the name is no amount; a decimal after a drink is litres.
E("pizza cztery sery", ("pizza", 1, "piece"))
E("pizza 30 cm z pieczarkami", ("pizza", 1, "piece"), "pieczarki")
E("kromka chleba 7 zbóż", ("chleb", 1, "slice"))
E("chleb 7 zbóż 2 kromki", ("chleb", 2, "slice"))
E("pepsi 0,5", ("cola", 500, None))
E("woda mineralna 1,5", ("woda", 1500, None))
E("cola zero 0,33", ("cola-zero", 330, None))
E("piwo 0,0", ("piwo", 1, "can"))
E("1,5 piwa", ("piwo", 1.5, "can"))

# A dish counted by its ingredient is that ingredient, also with something said in between.
E("jajecznica na łyżce masła z 3 jajek", ("maslo", 1, "tablespoon"), ("jajko", 3, "piece"))
E("omlet ze szpinakiem z 2 jajek", "szpinak", ("jajko", 2, "piece"))
E("jajecznica z boczkiem z 3 jajek", "boczek", ("jajko", 3, "piece"))
