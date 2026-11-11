# -*- coding: utf-8 -*-
"""Sixth set: the phrases of the parser review before 0.1.9 (findings parser-1 to parser-18), of the review of
their fixes, and the look-alikes the fixes must leave alone. Kept as a regression set: the parser handles every one.
E(text, *items, unknown=()): items are "id" (any amount), "?id" (a typo guess), ("id", amount, unit) or
("id", amount, unit, grams); the amount counts the unit's portions, or grams when the unit is None."""

P = []


def E(text, *items, unknown=()):
    P.append((text, list(items), list(unknown)))


# ---------------------------------------------------------------- parser-1: a count after an unknown dish's filling
E("gyoza z kurczakiem 6 sztuk", unknown=["gyoza z kurczakiem"])
E("kołduny z mięsem 10 sztuk", unknown=["kołduny z mięsem"])
E("pyzy z mięsem 4 sztuki", unknown=["pyzy z mięsem"])
E("pyzy z mięsem 4", unknown=["pyzy z mięsem"])
E("4 pyzy z mięsem", unknown=["pyzy z mięsem"])
E("sajgonki z kurczakiem 4 sztuki", unknown=["sajgonki z kurczakiem"])
E("hosomaki z łososiem 8 sztuk", unknown=["hosomaki z łososiem"])
# What is counted in pieces itself keeps the count; a weight is the filling's; a known dish is counted.
E("szakszuka z jajkami 2 sztuki", ("jajko", 2, "piece"), unknown=["szakszuka"])
E("gyoza z kurczakiem 200 g", ("piers-z-kurczaka", 200, None), unknown=["gyoza"])
E("pierogi z mięsem 10 sztuk", ("pierogi-z-miesem", 10, "piece"))
# Review of the fixes: a count in servings counts the dish too.
E("pyzy z mięsem 1 porcja", unknown=["pyzy z mięsem"])
E("kołduny z mięsem 2 porcje", unknown=["kołduny z mięsem"])
E("gyoza z kurczakiem 1 porcja", unknown=["gyoza z kurczakiem"])

# ---------------------------------------------------------------- parser-2: "protein" on a label, "z browaru"
E("mleko protein 500 ml", ("mleko", 500, None))
E("pudding high protein 200g", ("budyn", 200, None))
E("jogurt protein 150 g", ("jogurt-naturalny", 150, None))
E("skyr protein", ("skyr", 1, "package"))
E("jogurt protein", ("jogurt-naturalny", 1, "package"))
E("protein", unknown=["protein"])
E("piwo z browaru", ("piwo", 1, "can"))
E("browar", ("piwo", 1, "can"))
E("2 browary", ("piwo", 2, "can"))
E("shake proteinowy", ("odzywka-bialkowa", 1, "serving"))
E("odżywka białkowa 30 g", ("odzywka-bialkowa", 30, None))
# Review of the fixes: "proteina" is the powder, in any form.
E("owsianka z proteiną", ("owsianka", 1, "bowl"), ("odzywka-bialkowa", 1, "serving", 30))
E("30 g proteiny", ("odzywka-bialkowa", 30, None))
E("jogurt z proteiną", "jogurt-naturalny", ("odzywka-bialkowa", 1, "serving"))
E("miarka proteiny", ("odzywka-bialkowa", 1, "serving"))
E("proteina z mlekiem", "odzywka-bialkowa", "mleko")

# ---------------------------------------------------------------- parser-3: an hour before the meal's name
E("około 8 śniadanie: owsianka", ("owsianka", 1, "bowl"))
E("8 rano owsianka", ("owsianka", 1, "bowl"))
E("ok. 13 obiad: zupa pomidorowa i schabowy", ("zupa-pomidorowa", 1, "serving"), "kotlet-schabowy")
E("koło 19 kolacja: 2 kanapki", ("chleb", 2, "slice"))
E("8 rano: 2 jajka", ("jajko", 2, "piece"))
E("2 śniadanie: jogurt", ("jogurt-naturalny", 1, "package"))
E("12 lunch: sałatka", ("salatka", 1, "serving"))
E("o 8 owsianka", ("owsianka", 1, "bowl"))
E("3 jajka na obiad", ("jajko", 3, "piece"))
E("20 orzechów", ("orzechy", 20, "piece"))
E("ok. 100 g ryżu", ("ryz", 100, None))

# ---------------------------------------------------------------- parser-4: florets, rings and segments
E("5 różyczek kalafiora", ("kalafior", 5, "thinSlice", 75))
E("kilka różyczek brokuła", ("brokul", 3, "thinSlice", 45))
E("2 krążki ananasa", ("ananas", 2, "thinSlice", 100))
E("2 cząstki melona", ("melon", 2, "thinSlice"))
E("4 cząstki pomarańczy", ("pomarancza", 4, "thinSlice", 60))
E("3 cząstki jabłka", ("jablko", 3, "thinSlice", 45))
E("3 plastry ananasa", ("ananas", 3, "thinSlice", 150))
E("różyczki brokuła", ("brokul", 1, "serving", 150))
# Review of the fixes: a "cząstka" of garlic is its clove.
E("2 cząstki czosnku", ("czosnek", 2, "thinSlice", 10))
E("2 ząbki czosnku", ("czosnek", 2, "clove", 10))

# ---------------------------------------------------------------- parser-5: a bowl or a mug of a snack
E("miseczka lodów", ("lody", 1, "bowl", 150))
E("miska lodów", ("lody", 1, "bowl", 150))
E("miseczka żelków", ("zelki", 1, "bowl", 60))
E("miseczka pestek dyni", ("pestki-dyni", 1, "bowl", 50))
E("miseczka słonecznika", ("slonecznik", 1, "bowl", 50))
E("miseczka rodzynek", ("rodzynki", 1, "bowl", 50))
E("miseczka bakalii", ("suszone-owoce", 1, "bowl", 50))
E("miseczka oliwek", ("oliwki", 1, "bowl", 80))
E("miska cukierków", ("cukierki", 1, "bowl", 60))
E("kubek płatków", ("platki-owsiane", 1, "mug", 110))
E("pół kubka płatków owsianych", ("platki-owsiane", 0.5, "mug", 55))
E("kubek orzechów", ("orzechy", 1, "mug", 150))
E("szklanka płatków", ("platki-owsiane", 1, "glass", 90))
E("miseczka orzechów", ("orzechy", 1, "bowl", 50))
# Review of the fixes: the mugs and glasses of the same snacks.
E("kubek migdałów", ("migdaly", 1, "mug", 150))
E("kubek pestek dyni", ("pestki-dyni", 1, "mug", 150))
E("kubek orzechów włoskich", ("orzechy-wloskie", 1, "mug", 120))
E("kubek rodzynek", ("rodzynki", 1, "mug", 150))
E("kubek żelków", ("zelki", 1, "mug", 150))
E("kubek lodów", ("lody", 1, "mug", 150))
E("kubek granoli", ("granola", 1, "mug", 130))
E("kubek popcornu", ("popcorn", 1, "mug", 12))
E("miseczka daktyli", ("daktyle", 1, "bowl", 50))
E("szklanka orzechów", ("orzechy", 1, "glass", 125))
E("pół szklanki orzechów włoskich", ("orzechy-wloskie", 0.5, "glass", 50))

# ---------------------------------------------------------------- parser-6: "pączki" with "ą" are doughnuts
E("2 duże pączki", ("paczek", 2, "piece"))
E("tłusty czwartek: 3 pączki", ("paczek", 3, "piece"))
E("mini pączki", ("paczek", 1, "piece"))
E("duży pączek", ("paczek", 1, "piece"))
E("pączek kawa", ("paczek", 1, "piece"), ("kawa", 1, "mug"))
E("kawa pączek", ("kawa", 1, "mug"), ("paczek", 1, "piece"))
E("2 pączki", ("paczek", 2, "piece"))
E("2 x 3 pączki", ("paczek", 6, "piece"))
E("pół pączka", ("paczek", 0.5, "piece"))
E("2 paczki chipsów", ("chipsy", 2, "package"))
E("paczka chipsów", ("chipsy", 1, "package"))
E("kawa z paczką chipsów", "kawa", ("chipsy", 1, "package"))
E("kawa z tabliczką czekolady", "kawa", ("czekolada", 1, "package"))
E("paczka gum", unknown=["gum"])

# ---------------------------------------------------------------- parser-7: a dish named by an adjective
E("rosół schabowy ziemniaki mizeria", "rosol", "kotlet-schabowy", "ziemniaki", "mizeria")
E("zupa pomidorowa mielony ziemniaki buraczki", "zupa-pomidorowa", "kotlet-mielony", "ziemniaki", "buraki")
E("barszcz ruskie", "barszcz", "pierogi-ruskie")
E("pomidorowa schabowy", "zupa-pomidorowa", "kotlet-schabowy")
E("kanapka pomidorowa", "chleb")
E("sałatka pomidorowa", "salatka")
E("sałatka ogórkowa", "salatka")
E("sałatka fasolowa", "salatka")
E("zapiekanka warzywna", "zapiekanka")
E("lasagne warzywna", "lasagne")
E("pizza grzybowa", "pizza")
E("twaróg mielony", "twarog")
E("mąka gryczana", "maka")
E("kawa z mlekiem owsianym", "kawa-z-mlekiem")
# Review of the fixes: filled like pierogi ruskie, it is one dish. Second review: naleśniki ruskie count as
# naleśniki z serem, not as plain ones of 60 g; krokiety with no count are a plate of two, one after "z" is one.
E("krokiety ruskie", ("krokiety", 1, "serving", 200))
E("krokiet ruski", ("krokiety", 1, "piece", 100))
E("2 krokiety ruskie", ("krokiety", 2, "piece"))
E("krokiety", ("krokiety", 1, "serving", 200))
E("barszcz z krokietem", "barszcz", ("krokiety", 1, "piece", 100))
E("barszcz z pasztecikiem", "barszcz", ("krokiety", 1, "piece", 100))
E("naleśniki ruskie", ("nalesniki-z-serem", 1, "serving", 200))
E("naleśnik ruski", ("nalesniki-z-serem", 1, "piece", 100))
E("2 naleśniki ruskie", ("nalesniki-z-serem", 2, "piece", 200))
E("naleśniki ruskie ze śmietaną", ("nalesniki-z-serem", 1, "serving"), "smietana")

# ---------------------------------------------------------------- parser-8: "surówka" is no raw chicken
E("kurczak surówka ziemniaki", "piers-z-kurczaka", "surowka", "ziemniaki")
E("pierś z kurczaka surówka ryż", "piers-z-kurczaka", "surowka", "ryz")
E("indyk surówka", "indyk", "surowka")
E("polędwiczka surówka", "poledwiczka", "surowka")
E("300 g ziemniaków 200 g kurczaka 100 g surówki", ("ziemniaki", 300, None), ("piers-z-kurczaka", 200, None),
  ("surowka", 100, None))
E("bułka maślanka", "bulka", "maslanka")
E("kurczak surowy", "piers-z-kurczaka-surowa")
E("surowa pierś z kurczaka", "piers-z-kurczaka-surowa")
E("kurczak i surówka", "piers-z-kurczaka", "surowka")
E("pomidorówka", "zupa-pomidorowa")
E("jaglanka", "kasza-jaglana")
E("surówki", "surowka")
E("surówką", "surowka")

# ---------------------------------------------------------------- parser-9: three foods without commas
E("2 jajka 4 kromki chleba 2 plastry sera", ("jajko", 2, "piece"), ("chleb", 4, "slice"), ("ser-zolty", 2, "thinSlice"))
E("150 g kurczaka 100 g ryżu 200 g brokułów", ("piers-z-kurczaka", 150, None), ("ryz", 100, None),
  ("brokul", 200, None))
E("200 g twarogu 2 łyżki jogurtu 1 łyżeczka miodu", ("twarog", 200, None), ("jogurt-naturalny", 2, "tablespoon"),
  ("miod", 1, "teaspoon"))
E("jajka 2 kromki chleba 100 g sera", "jajko", ("chleb", 2, "slice"), ("ser-zolty", 100, None))
E("2 jajka 4 kromki chleba", ("jajko", 2, "piece"), ("chleb", 4, "slice"))
E("kurczak 150 g ryż 100 g brokuł", ("piers-z-kurczaka", 150, None), ("ryz", 100, None), "brokul")
E("kurczak 150 g ryż", ("piers-z-kurczaka", 150, None), "ryz")

# ---------------------------------------------------------------- parser-10: "bez X i Y"
E("kawa bez cukru i mleka", ("kawa", 1, "mug"))
E("herbata bez cukru i mleka", ("herbata", 1, "mug"))
E("czarna kawa bez cukru i mleka", ("kawa", 1, "mug"))
E("kawa bez mleka i cukru", ("kawa", 1, "mug"))
E("burger bez bułki i sosu", "hamburger")
E("owsianka bez cukru i miodu", "owsianka")
E("herbata bez cukru i cytryny", "herbata")
E("kawa bez cukru i śmietanki", "kawa")
E("kawa bez cukru i mleka owsianego", "kawa")
E("kawa bez cukru i mleka i miodu", "kawa")
E("kawa bez mleka, bez cukru", "kawa")
# Another food after "i" was eaten, and so was milk named as it is.
E("kawa bez cukru i ciastko", "kawa", ("ciastko", 1, "piece"))
E("kawa bez cukru i ciastka", "kawa", "ciastko")
E("kawa bez cukru i kanapki", "kawa", "chleb")
E("kawa bez cukru i 2 ciastka", "kawa", ("ciastko", 2, "piece"))
E("kawa bez cukru i jabłko", "kawa", "jablko")
E("kawa bez cukru i mleko", "kawa", ("mleko", 1, "glass"))

# ---------------------------------------------------------------- parser-11: "na pół"
E("pizza na pół z mężem", ("pizza", 0.5, "piece", 200))
E("kebab na pół", ("kebab", 0.5, "piece"))
E("sushi zestaw 16 sztuk na pół z koleżanką", ("sushi", 8, "piece"))
E("sushi 16 na pół", ("sushi", 8, "piece"))
E("pizza 2 kawałki na pół", ("pizza", 1, "chunk"))
E("pół pizzy z mężem", ("pizza", 0.5, "piece"))
E("pierogi na pół z mężem", ("pierogi-ruskie", 0.5, "serving"))
E("pizza z szynką na pół", ("pizza", 0.5, "piece"), ("szynka", 0.5, "serving"))
E("pizza 400 g na pół", ("pizza", 200, None))
E("pizza na 2 osoby", ("pizza", 1, "piece"))
E("pizza pół na pół", ("pizza", 0.5, "piece"))
E("pizza pół na pół z mężem", ("pizza", 0.5, "piece"))
E("kawa pół na pół z mlekiem", ("kawa", 0.5, "mug"), ("mleko", 30, None))
E("jajka na twardo 3 sztuki", ("jajko", 3, "piece"))
# Review of the fixes: only cut in half, not shared.
E("2 jajka przekrojone na pół z majonezem", ("jajko", 2, "piece"), "majonez")
E("bułka przekrojona na pół", ("bulka", 1, "piece"))
E("banan pokrojony na pół", ("banan", 1, "piece"))
E("jajko przecięte na pół", ("jajko", 1, "piece"))
E("naleśnik złożony na pół", ("nalesniki", 1, "piece"))
E("awokado na pół z mężem", ("awokado", 0.5, "serving"))

# ---------------------------------------------------------------- parser-12: patties are no pork chop
E("kotlety z kaszy jaglanej 2 sztuki", ("kotlet-warzywny", 2, "piece"))
E("kotlety jaglane", "kotlet-warzywny")
E("kotlet z łososia", "ryba-panierowana")
E("kotlety z tuńczyka", "ryba-panierowana")
E("kotlety rybne", "ryba-panierowana")
E("kotlet rybny", "ryba-panierowana")
E("kotlet z ryby", "ryba-panierowana")
E("kotlet z kalafiora", "kotlet-warzywny")
E("kotlet z kaszą", "kotlet-schabowy", "kasza-gryczana")
E("kotlet z cukinią", "kotlet-schabowy", "cukinia")
E("kotlet z ziemniakami i surówką", "kotlet-schabowy", "ziemniaki", "surowka")

# ---------------------------------------------------------------- parser-13: "z kilkoma", "z paroma", "z dwiema"
E("owsianka z kilkoma orzechami", "owsianka", ("orzechy", 3, "piece"))
E("jogurt z kilkoma migdałami", "jogurt-naturalny", ("migdaly", 3, "piece"))
E("jogurt z paroma orzechami", "jogurt-naturalny", ("orzechy", 2, "piece"))
E("owsianka z dwiema łyżkami masła orzechowego", "owsianka", ("maslo-orzechowe", 2, "tablespoon"))
E("kanapka z dwiema plasterkami sera", "chleb", ("ser-zolty", 2, "thinSlice"))

# ---------------------------------------------------------------- parser-14: a flavoured serek
E("serek truskawkowy", ("serek-homogenizowany", 1, "package"))
E("serek czekoladowy", ("serek-homogenizowany", 1, "package"))
E("serek truskawkowy 150 g", ("serek-homogenizowany", 150, None))
E("serek proteinowy", ("skyr", 1, "package"))
E("serek", ("serek-smietankowy", 1, "tablespoon"))
E("serek kanapkowy", "serek-smietankowy")
E("bułka z serkiem", "bulka", "serek-smietankowy")

# ---------------------------------------------------------------- parser-15: the juice of a few fruits
E("świeży sok z 4 pomarańczy", ("sok", 320, None))
E("sok z 2 pomarańczy", ("sok", 160, None))
E("sok z 2 jabłek", ("sok", 160, None))
E("kompot z 3 jabłek", ("kompot", 240, None))
E("sok z pomarańczy", ("sok", 1, "glass"))
E("2 szklanki soku z pomarańczy", ("sok", 2, "glass"))
E("sok z 3 cytryn", ("sok-z-cytryny", 3, "piece"))
E("jajecznica z 3 jajek", ("jajko", 3, "piece"))

# ---------------------------------------------------------------- parser-16: the protein on a label
E("skyr 20 g białka", ("skyr", 1, "package"))
E("serek wiejski 25 g białka", ("serek-wiejski", 1, "package"))
E("baton proteinowy 20 g białka", ("baton-proteinowy", 1, "piece"))
E("jogurt 10 g białka 150 g", ("jogurt-naturalny", 150, None))
E("100 g białka jaj", ("bialko-jaja", 100, None))
# Review of the fixes: whey and "białko z jajka" are a food too, a nutrient after "z" is still a label.
E("100 g białka z jajka", ("bialko-jaja", 100, None))
E("50 g białka serwatkowego", ("odzywka-bialkowa", 50, None))
E("owsianka z 30 g białka serwatkowego", "owsianka", ("odzywka-bialkowa", 30, None))
E("50 g białka WPC", ("odzywka-bialkowa", 50, None))
E("skyr 20 g białka z owocami", ("skyr", 1, "package"), "owoce")
E("20 g białka skyr", ("skyr", 1, "package"))
E("białka jaj 100 g", ("bialko-jaja", 100, None))
E("kawa z 5 g cukru", "kawa", ("cukier", 5, None))
E("baton 250 kcal", ("baton", 1, "piece"))

# ---------------------------------------------------------------- parser-17: a name after "z" is no typo of a food
E("kawa z Kasią", "kawa", unknown=["Kasią"])
E("kawa z Kingą", "kawa", unknown=["Kingą"])
E("kawa z Kaśką", "kawa", unknown=["Kaśką"])
E("kawa z Majką", "kawa", unknown=["Majką"])
E("kawa z Maćkiem", "kawa", unknown=["Maćkiem"])
E("obiad z Markiem", unknown=["Markiem"])
E("Bannan", "?banan")
E("kawa. Bannan", "kawa", "?banan")
E("- Bannan", "?banan")
E("pierś z kurczka", "piers-z-kurczaka")
E("kanapka z Nutellą", "chleb", "krem-czekoladowy")
# Review of the fixes: the usual misspellings of brands are aliases.
E("kanapka z Nutelą", "chleb", "krem-czekoladowy")
E("kawa z Nutelą", "kawa", "krem-czekoladowy")
E("zjadłam Snikersa", ("baton", 1, "piece"))

# ---------------------------------------------------------------- parser-18: milk for the coffee
E("mleko do kawy", ("mleko", 30, None))
E("kawa, mleko do kawy", "kawa", ("mleko", 30, None))
E("kawa bez cukru i z mlekiem", "kawa", ("mleko", 30, None))
E("mleko owsiane do kawy", ("mleko-owsiane", 30, None))
E("50 ml mleka do kawy", ("mleko", 50, None))
E("szklanka mleka", ("mleko", 1, "glass"))
E("mleko", ("mleko", 1, "glass"))
E("kawa z cukrem i mlekiem", "kawa", "cukier", ("mleko", 30, None))
# Review of the fixes: a fragment that starts with "z" and a food or an amount goes on with the dish before it.
E("kawa z cukrem, z mlekiem", "kawa", "cukier", ("mleko", 30, None))
E("kawa, z mlekiem", "kawa", ("mleko", 30, None))
E("kawa bez cukru, z mlekiem", "kawa", ("mleko", 30, None))
E("Kawa z cukrem. Z mlekiem.", "kawa", "cukier", ("mleko", 30, None))
E("owsianka, z mlekiem", ("owsianka", 1, "bowl"))
E("pierogi, z cebulką 10 sztuk", ("pierogi-ruskie", 10, "piece"), ("cebula", 1, "serving"))
E("chleb, z masłem 2 kromki", ("chleb", 2, "slice"), ("maslo", 1, "teaspoon"))
E("jajecznica, z 3 jajek", ("jajko", 3, "piece"))
# A name or a dish of its own after "z" starts afresh.
E("owsianka. Z Kasią kawa z cukrem i mlekiem", "owsianka", "kawa", "cukier", ("mleko", 30, None))
E("kurczak z ryżem. Z mężem pizza na pół", ("piers-z-kurczaka", 1, "serving"), ("ryz", 1, "serving"),
  ("pizza", 0.5, "piece"))
E("kawa, z mlekiem owsianym", "kawa", ("mleko-owsiane", 30, None))
# Second review: after someone only a share goes on with the dish before; an amount or a name that reads like
# a food (still counted as oliwa or borówki) starts afresh, so "na pół" leaves the dish before whole.
E("pizza z szynką. Z mężem na pół", ("pizza", 0.5, "piece"), ("szynka", 0.5, "serving"))
E("pizza, z mężem na pół", ("pizza", 0.5, "piece"))
E("Kebab. Z koleżanką na pół.", ("kebab", 0.5, "piece"))
E("kebab. Z Kasią na pół", ("kebab", 0.5, "piece"), unknown=["Kasią"])
E("pizza, z mężem na połowę", ("pizza", 0.5, "piece"))
E("kurczak z ryżem. Z mężem dwie pizze na pół", ("piers-z-kurczaka", 1, "serving"), ("ryz", 1, "serving"),
  ("pizza", 1, "piece"))
E("Kurczak z ryżem. Z Oliwią pizza na pół.", ("piers-z-kurczaka", 1, "serving"), ("ryz", 1, "serving"), "oliwa",
  ("pizza", 0.5, "piece"))
E("Obiad: kurczak z ryżem. Z Maliną pizza na pół.", ("piers-z-kurczaka", 1, "serving"), ("ryz", 1, "serving"),
  "maliny", ("pizza", 0.5, "piece"))
E("pizza, z mężem na 2 osoby", ("pizza", 1, "piece"))
E("jajecznica, z ok. 3 jajek", ("jajko", 3, "piece"))
