# -*- coding: utf-8 -*-
"""Source of FoodDB.json: generic Polish products and dishes, values per 100 g (100 ml for drinks).
Values are rounded table values (USDA / Polish food tables, Polish labels), estimates - not her data.
Each entry: id, name, aliases, category, kcal, protein, carbs, fat, default portion, portions, tags,
and singular: the names and aliases that mean one piece ("naleśnik"), so that a bare one is the
default portion and not the serving of several ("naleśniki").
Carbs are total carbohydrates; aliases list only forms the parser cannot derive itself.
Conventions: grains, pasta and lean meats (chicken and turkey breast, pork tenderloin) as eaten,
i.e. cooked; dry grains and raw meat are products of their own ("ryż suchy", "pierś z kurczaka surowa").
Every alias has at least 3 letters and belongs to exactly one product. FoodDB.json is generated from
this file by build_catalog.py --install: never edit the JSON by hand."""

ITEMS = []


def I(id, name, aliases, cat, kcal, p, c, f, default, portions=(), tags=(), singular=()):
    item = dict(id=id, name=name, aliases=list(aliases), category=cat,
                per100=dict(kcal=kcal, protein=p, carbs=c, fat=f),
                portions=[dict(unit=u, grams=g) for (u, g) in portions],
                defaultPortion=dict(unit=default[0], grams=default[1]),
                tags=list(tags))
    if singular:
        item["singular"] = list(singular)
    ITEMS.append(item)


# ---------------------------------------------------------------- bread
I("chleb", "chleb", ["chleb pszenny", "chleb biały", "chlebek", "pieczywo", "kanapka", "kanapeczka", "kanapce",
                     "chleb mieszany", "chleb baltonowski"],
  "bread", 250, 8.5, 49, 2.5, ("slice", 35))
I("chleb-zytni", "chleb żytni", ["chleb razowy", "razowiec", "chleb na zakwasie", "chleb żytni razowy"],
  "bread", 230, 6, 46, 1.7, ("slice", 40), tags=["fiber", "magnesium"])
I("chleb-pelnoziarnisty", "chleb pełnoziarnisty", ["chleb wieloziarnisty", "chleb ze ziarnami", "chleb orkiszowy",
                                                   "chleb graham", "chleb słonecznikowy"],
  "bread", 245, 9, 43, 3.5, ("slice", 40), tags=["fiber", "magnesium"])
I("chleb-tostowy", "chleb tostowy", ["tost", "tosty", "toście", "grzanka", "grzanki", "grzance", "tościk",
                                     "toast"],
  "bread", 265, 8, 49, 4, ("slice", 25))
I("bulka", "bułka", ["bułka pszenna", "kajzerka", "bułeczka", "bułce", "bułka maślana"],
  "bread", 290, 9.5, 57, 3, ("piece", 50))
I("grahamka", "bułka grahamka", ["grahamka", "bułka pełnoziarnista", "bułka razowa", "bułka orkiszowa",
                                 "bułka żytnia", "bułka wieloziarnista"],
  "bread", 260, 9, 50, 3, ("piece", 70), tags=["fiber"])
I("bagietka", "bagietka", ["bagietka czosnkowa"], "bread", 270, 9, 55, 1.5, ("chunk", 60), [("piece", 250)])
I("bajgiel", "bajgiel", ["bajgel", "bagel"], "bread", 257, 10, 50, 1.6, ("piece", 90))
I("croissant", "croissant", ["rogalik", "rogal", "kruasan", "rogalik maślany"], "bread", 406, 8, 46, 21,
  ("piece", 60))
I("tortilla", "tortilla", ["wrap", "placek tortilli"], "bread", 310, 8.5, 51, 7.5, ("piece", 60))
I("pita", "pita", ["chlebek pita"], "bread", 275, 9, 55, 1.2, ("piece", 60))
I("chalka", "chałka", [], "bread", 300, 8, 55, 5, ("slice", 40))
I("pieczywo-chrupkie", "pieczywo chrupkie", ["wasa", "chleb chrupki", "chlebek chrupki", "pieczywo wasa"],
  "bread", 360, 10, 70, 2, ("slice", 10), [("serving", 20)], tags=["fiber"])
I("wafle-ryzowe", "wafle ryżowe", ["wafel ryżowy", "wafle", "wafelki ryżowe", "wafle kukurydziane"],
  "bread", 387, 8, 81, 3, ("piece", 9), [("serving", 27)], singular=["wafel ryżowy"])

# ---------------------------------------------------------------- dairy
I("mleko", "mleko", ["mleko krowie", "mleczko", "mleko półtłuste", "mleko bez laktozy"],
  "dairy", 50, 3.4, 4.8, 2, ("glass", 250), [("mug", 300), ("tablespoon", 15), ("teaspoon", 5)],
  tags=["calcium"])
# "z owsianym" / "na owsianym" on its own is oat milk (and not a typo of "owsianka").
I("mleko-owsiane", "mleko owsiane", ["napój owsiany", "mleko roślinne", "napój roślinny", "owsianym"],
  "drinks", 45, 0.8, 6.7, 1.5, ("glass", 250), [("tablespoon", 15)])
I("mleko-migdalowe", "mleko migdałowe", ["napój migdałowy"], "drinks", 24, 0.5, 3, 1.1, ("glass", 250),
  [("tablespoon", 15)])
I("mleko-sojowe", "mleko sojowe", ["napój sojowy"], "drinks", 40, 3, 2.5, 1.8, ("glass", 250),
  [("tablespoon", 15)], tags=["protein"])
I("mleko-kokosowe", "mleko kokosowe", ["mleczko kokosowe"], "fats", 197, 2, 2.8, 21, ("tablespoon", 15),
  [("glass", 250), ("can", 400)])
# A spoon of cocoa stirred into it is part of the cup, not a mug of the cocoa drink.
I("jogurt-naturalny", "jogurt naturalny", ["jogurt", "jogurcik", "jogurcie", "jogurt bałkański",
                                           "jogurt z kakao", "jogurt naturalny z kakao"],
  "dairy", 63, 4.3, 6, 2.5, ("package", 150), [("tablespoon", 20), ("glass", 250), ("mug", 150)],
  tags=["calcium"])
I("jogurt-grecki", "jogurt grecki", ["jogurt typu greckiego", "grecki jogurt", "jogurt grecki z kakao"],
  "dairy", 122, 5.5, 4.2, 9.5, ("package", 150), [("tablespoon", 25), ("mug", 150)], tags=["calcium"])
I("jogurt-owocowy", "jogurt owocowy", ["jogurt truskawkowy", "jogurt waniliowy", "jogurt pitny"],
  "dairy", 95, 3.5, 14, 2.5, ("package", 150), [("mug", 150)], tags=["calcium"])
I("kefir", "kefir", [], "dairy", 51, 3.4, 4.7, 2, ("glass", 250), [("package", 400)], tags=["calcium"])
I("maslanka", "maślanka", [], "dairy", 40, 3.4, 4.7, 1, ("glass", 250), [("package", 500)], tags=["calcium"])
# A protein cup ("serek proteinowy") is closest to skyr: about 60 kcal and 11 g of protein per 100 g.
I("skyr", "skyr", ["jogurt skyr", "serek skyr", "skyr z kakao", "serek proteinowy"], "dairy", 63, 11, 4, 0.2,
  ("package", 150), [("tablespoon", 25), ("mug", 150)], tags=["protein", "calcium"])
I("serek-wiejski", "serek wiejski", ["twarożek ziarnisty", "serek ziarnisty", "cottage cheese", "serek cottage",
                                     "ser cottage"],
  "dairy", 97, 11, 2.7, 4.5, ("package", 200), [("tablespoon", 25)], tags=["protein", "calcium"])
I("serek-smietankowy", "serek śmietankowy", ["serek", "serek kanapkowy", "serek naturalny",
                                             "serek do smarowania", "serek kremowy", "ser kremowy"],
  "dairy", 250, 6, 3.5, 23, ("tablespoon", 20), [("package", 150), ("teaspoon", 7)])
# A flavoured serek ("truskawkowy", "czekoladowy") is a dessert cup, not a spoon of cream cheese.
I("serek-homogenizowany", "serek homogenizowany", ["serek waniliowy", "serek owocowy", "homogenizowany",
                                                   "serek danio", "serek truskawkowy", "serek czekoladowy",
                                                   "serek brzoskwiniowy"],
  "dairy", 150, 8, 14, 7, ("package", 150), [("mug", 150)], tags=["calcium"])
# A "kostka" (block) of twaróg, masło, tofu or feta is a piece; "kostka" of chocolate or sugar is one cube.
I("twarog", "twaróg", ["twarożek", "twaróg półtłusty", "ser biały", "biały ser", "gzik"],
  "dairy", 133, 18.7, 3.7, 4.7, ("serving", 100), [("tablespoon", 30), ("package", 250), ("piece", 250)],
  tags=["protein", "calcium"])
I("twarog-chudy", "twaróg chudy", ["chudy twaróg", "twarożek chudy", "chudy twarożek", "ser biały chudy",
                                   "chudy ser biały"],
  "dairy", 99, 19.8, 3.5, 0.5, ("serving", 100), [("tablespoon", 30), ("package", 250), ("piece", 250)],
  tags=["protein", "calcium"])
I("ser-zolty", "ser żółty", ["ser", "żółty ser", "gouda", "ser gouda", "edam", "ser edamski", "ser królewski",
                             "ser salami", "ser tylżycki", "ser morski"],
  "dairy", 356, 25, 2.2, 27.4, ("thinSlice", 15), [("serving", 30), ("chunk", 30)],
  tags=["protein", "calcium"])
I("mozzarella", "mozzarella", ["mozarella", "ser mozzarella", "mozzarella light"], "dairy", 250, 18, 1.5, 19,
  ("piece", 125), [("serving", 60), ("thinSlice", 20)], tags=["protein", "calcium"])
I("feta", "feta", ["ser feta", "ser typu feta", "ser sałatkowy", "fetaki"], "dairy", 264, 14, 4, 21,
  ("serving", 50), [("thinSlice", 20), ("package", 200), ("piece", 200)], tags=["protein", "calcium"])
I("parmezan", "parmezan", ["parmigiano", "grana padano", "ser parmezan"], "dairy", 431, 38, 4, 29,
  ("tablespoon", 7), [("serving", 20)], tags=["protein", "calcium"])
I("burrata", "burrata", [], "dairy", 245, 13, 2, 21, ("piece", 125), [("serving", 60)], tags=["calcium"])
I("halloumi", "halloumi", ["ser halloumi"], "dairy", 320, 21, 2, 25, ("serving", 80), [("thinSlice", 25)],
  tags=["protein", "calcium"])
I("camembert", "camembert", ["brie", "ser pleśniowy", "ser brie", "ser camembert", "ser z pleśnią"],
  "dairy", 300, 20, 0.5, 24, ("chunk", 30), [("package", 120)], tags=["calcium"])
I("smietana", "śmietana", ["śmietanka", "kwaśna śmietana", "śmietana do zup"], "dairy", 184, 2.5, 3.6, 18,
  ("tablespoon", 15), [("teaspoon", 5), ("glass", 230)])
I("maslo", "masło", ["masełko", "masło klarowane", "ghee"], "fats", 735, 0.7, 0.7, 81, ("teaspoon", 5),
  [("tablespoon", 15), ("package", 200), ("piece", 200)])

# ---------------------------------------------------------------- eggs
I("jajko", "jajko", ["jajka", "jajo", "jaja", "jaj", "jajeczko", "jajecznica z jaj", "jajecznica z jajek",
                     "jajecznica z jajka", "omlet z jaj", "omlet z jajek", "omlet z jajka",
                     # "jajecznica 2 jajka", "omlet (3 jaja)": the count is eggs, not plates of jajecznica.
                     "jajecznica jajko", "jajecznica jaj", "omlet jajko", "omlet jaj",
                     "jajecznica na maśle z jajek", "jajecznica na maśle z jaj"],
  "eggs", 140, 12.5, 0.6, 9.7, ("piece", 55), [("serving", 110)], tags=["protein"],
  singular=["jajko", "jajo", "jajeczko"])
I("jajecznica", "jajecznica", ["jajecznica na maśle"], "eggs", 170, 11, 1.5, 13.5, ("serving", 150),
  tags=["protein"])
I("omlet", "omlet", ["omlecik", "frittata", "omlet biszkoptowy"], "eggs", 155, 10.5, 1.5, 12, ("serving", 150),
  tags=["protein"])
I("pasta-jajeczna", "pasta jajeczna", [], "eggs", 210, 10, 1.5, 18.5,
  ("tablespoon", 30), tags=["protein"])

# ---------------------------------------------------------------- meat
# Chicken and turkey breast and pork tenderloin are cooked (as eaten), like the grains; raw meat is its own
# product. Breast: USDA roasted, meat only 165 / 31 / 0 / 3.6; raw 110 / 22.5 / 0 / 2 (Polish labels, USDA).
I("piers-z-kurczaka", "pierś z kurczaka", ["kurczak", "filet z kurczaka", "pierś kurczaka",
                                           "filet z piersi kurczaka", "filet drobiowy", "kurczaczek",
                                           "mięso z kurczaka", "kurczak pieczony", "kurczak gotowany",
                                           "pierś", "polędwiczka z kurczaka"],
  "meat", 165, 31, 0, 3.6, ("serving", 150), [("piece", 150), ("chunk", 100)], tags=["protein"])
I("piers-z-kurczaka-surowa", "pierś z kurczaka surowa", ["surowa pierś z kurczaka", "surowa pierś",
                                                         "surowy kurczak", "kurczak surowy"],
  "meat", 110, 22.5, 0, 2, ("serving", 150), [("piece", 200)], tags=["protein"])
I("udko-kurczaka", "udko z kurczaka", ["udko", "udko kurczaka", "podudzie", "udka z kurczaka",
                                       "pałki z kurczaka", "ćwiartka kurczaka"],
  "meat", 200, 17, 0, 14.5, ("piece", 120), tags=["protein"])
I("kotlet-z-kurczaka", "kotlet z kurczaka", ["kotlet drobiowy", "kurczak panierowany", "panierowany kurczak",
                                             "kurczak w panierce", "pierś z kurczaka w panierce",
                                             "filet z kurczaka w panierce", "kotlet z piersi kurczaka",
                                             "kotlet z piersi", "kotlet z indyka", "kotlet z piersi indyka",
                                             "sznycel z indyka"],
  "meat", 220, 20, 10, 11, ("piece", 150), tags=["protein"])
# Turkey breast: USDA roasted 135-147 kcal, 30 g protein; raw about 105 / 23 / 1.2 (Polish labels).
I("indyk", "pierś z indyka", ["indyk", "filet z indyka", "pierś indyka", "mięso z indyka",
                              "polędwiczka z indyka"],
  "meat", 140, 30, 0, 1.5, ("serving", 150), [("chunk", 100)], tags=["protein"])
I("indyk-surowy", "pierś z indyka surowa", ["surowa pierś z indyka", "surowa pierś indyka", "surowy indyk",
                                            "indyk surowy"],
  "meat", 105, 23, 0, 1.2, ("serving", 150), tags=["protein"])
I("mieso-mielone", "mięso mielone", ["mielone mięso", "mięso", "mięso wieprzowo-wołowe"],
  "meat", 250, 17, 0, 20, ("serving", 100), tags=["protein", "iron"])
I("kotlet-mielony", "kotlet mielony", ["mielony", "kotlety mielone", "klops", "kotlet mielony z indyka"],
  "meat", 260, 15, 8, 19, ("piece", 100), tags=["protein"])
I("schab", "schab", ["schab pieczony"], "meat", 175, 21, 0, 10,
  ("serving", 120), [("chunk", 100), ("thinSlice", 50)], tags=["protein"])
# Pork tenderloin, lean only: USDA roasted 143 / 26.2 / 0 / 3.5, raw 109 / 21 / 0 / 2.2.
I("poledwiczka", "polędwiczka wieprzowa", ["polędwiczka"], "meat", 143, 26, 0, 3.5, ("serving", 120),
  tags=["protein"])
I("poledwiczka-surowa", "polędwiczka wieprzowa surowa", ["surowa polędwiczka", "polędwiczka surowa"],
  "meat", 109, 21, 0, 2.2, ("serving", 150), tags=["protein"])
I("kotlet-schabowy", "kotlet schabowy", ["schabowy", "schabowe", "kotlet", "kotlety", "schaboszczak"],
  "meat", 255, 19, 10, 15.5, ("piece", 150), tags=["protein"])
I("karkowka", "karkówka", ["karczek"], "meat", 240, 17, 0, 19, ("serving", 150), [("thinSlice", 100)],
  tags=["protein"])
# A count means ribs: "3 żeberka". A bare "żeberka" is still the serving.
I("zeberka", "żeberka", ["żeberko"], "meat", 290, 17, 0, 25, ("piece", 60), [("serving", 200)], tags=["protein"],
  singular=["żeberko"])
I("wieprzowina", "wieprzowina", ["mięso wieprzowe", "łopatka wieprzowa", "szynka wieprzowa surowa", "pieczeń", "pieczeń wieprzowa",
                               "pieczeń z karkówki"],
  "meat", 200, 19, 0, 14, ("serving", 150), tags=["protein"])
I("wolowina", "wołowina", ["mięso wołowe", "stek", "befsztyk", "rostbef", "polędwica wołowa", "antrykot"],
  "meat", 190, 21, 0, 12, ("serving", 150), tags=["protein", "iron"])
I("szynka", "szynka", ["wędlina", "szynka gotowana", "szynka wędzona", "szyneczka", "wędlinka",
                       "szynka konserwowa"],
  "meat", 115, 19, 1.5, 3.8, ("thinSlice", 15), [("serving", 30)], tags=["protein"])
I("szynka-parmenska", "szynka parmeńska", ["prosciutto", "szynka dojrzewająca", "szynka serrano", "serrano"],
  "meat", 250, 26, 0.5, 16, ("thinSlice", 12), [("serving", 30)], tags=["protein"])
I("poledwica", "polędwica", ["polędwica sopocka", "polędwica drobiowa", "wędlina drobiowa", "szynka z indyka",
                             "szynka drobiowa", "szynka z kurczaka", "pierś z indyka wędzona"],
  "meat", 100, 19, 2, 2, ("thinSlice", 15), [("serving", 30)], tags=["protein"])
I("kielbasa", "kiełbasa", ["kiełbaska", "kiełbasa śląska", "kiełbasa zwyczajna", "kiełbasa krakowska"],
  "meat", 250, 14, 2, 20.5, ("piece", 100), [("thinSlice", 10)], tags=["protein"])
I("parowki", "parówki", ["parówka", "berlinki", "frankfurterki"], "meat", 250, 11, 3, 22, ("piece", 35),
  [("serving", 70)], singular=["parówka"])
I("kabanosy", "kabanosy", ["kabanos"], "meat", 450, 25, 2, 38, ("piece", 20), [("serving", 40)],
  tags=["protein"], singular=["kabanos"])
I("boczek", "boczek", ["bekon", "boczek wędzony"], "meat", 420, 14, 0, 40.5, ("thinSlice", 15),
  [("serving", 30)])
I("salami", "salami", ["kiełbasa salami", "pepperoni", "chorizo"], "meat", 380, 22, 1.5, 32, ("thinSlice", 8),
  [("serving", 30)], tags=["protein"])
I("pasztet", "pasztet", ["pasztet drobiowy"], "meat", 300, 12, 7, 25, ("thinSlice", 25),
  [("tablespoon", 20)])
I("kaszanka", "kaszanka", ["kiszka"], "meat", 250, 10, 15, 17, ("serving", 100), [("piece", 300)], tags=["iron"])
I("watrobka", "wątróbka", ["wątróbka drobiowa", "wątroba"], "meat", 119, 17, 0.7, 4.8,
  ("serving", 100), tags=["protein", "iron"])

# ---------------------------------------------------------------- fish
I("losos", "łosoś", ["łosoś pieczony", "filet z łososia", "łososik"],
  "fish", 208, 20, 0, 13.4, ("serving", 150), [("chunk", 125)], tags=["protein", "omega3"])
I("losos-wedzony", "łosoś wędzony", ["wędzony łosoś"], "fish", 160, 21, 0, 8.5,
  ("serving", 50), [("thinSlice", 15)], tags=["protein", "omega3"])
I("tunczyk", "tuńczyk", ["tuńczyk w sosie własnym", "tuńczyk w wodzie"],
  "fish", 116, 26, 0, 1, ("can", 120), tags=["protein"])
I("tunczyk-w-oleju", "tuńczyk w oleju", [], "fish", 190, 27, 0, 9, ("can", 120), tags=["protein"])
I("dorsz", "dorsz", ["filet z dorsza"], "fish", 82, 18, 0, 0.7, ("serving", 150), [("chunk", 125)],
  tags=["protein"])
I("ryba", "ryba", ["filet rybny", "mintaj", "morszczuk", "tilapia", "panga", "miruna", "halibut", "pstrąg",
                   "filet z ryby", "ryba gotowana", "ryba pieczona", "filet z mintaja"],
  "fish", 100, 19, 0, 2.5, ("serving", 150), [("chunk", 125)], tags=["protein"])
# A fish patty ("kotlet rybny", "kotlet z łososia") is breaded fish, not a pork chop and a fillet.
I("ryba-panierowana", "ryba w panierce", ["ryba smażona", "smażona ryba", "filet w panierce",
                                          "ryba panierowana", "fish and chips", "dorsz w panierce",
                                          "mintaj w panierce", "filet z dorsza w panierce", "dorsz panierowany",
                                          "kotlet rybny", "kotlet z ryby", "kotlet z łososia", "kotlet z tuńczyka",
                                          "kotlet z dorsza", "kotlet z mintaja"],
  "fish", 200, 13, 14, 10.5, ("serving", 150), tags=["protein"])
I("paluszki-rybne", "paluszki rybne", [], "fish", 220, 12, 20, 10, ("piece", 25), [("serving", 125)],
  tags=["protein"])
I("makrela", "makrela", ["makrela wędzona"], "fish", 220, 20.7, 0, 15.5, ("serving", 100), [("piece", 250)],
  tags=["protein", "omega3"])
I("sledz", "śledź", ["śledzie", "śledzik", "śledzik w oleju", "matiasy", "matias", "śledź w oleju"],
  "fish", 200, 15, 3, 14.5, ("serving", 80), tags=["protein", "omega3"])
I("krewetki", "krewetki", ["krewetka", "owoce morza"], "fish", 99, 24, 0.2, 0.3, ("piece", 10),
  [("serving", 100)], tags=["protein"], singular=["krewetka"])
I("sardynki", "sardynki", ["sardynka", "sardynki w oleju"], "fish", 210, 24, 0, 12.5, ("piece", 25),
  [("can", 90), ("serving", 90)], tags=["protein", "omega3", "calcium"], singular=["sardynka"])
I("ryba-po-grecku", "ryba po grecku", [], "dishes", 120, 10, 7, 6, ("serving", 200), tags=["protein"])

# ---------------------------------------------------------------- legumes
I("tofu", "tofu", ["tofu naturalne", "tofu wędzone", "ser tofu"], "legumes", 125, 12.5, 2, 7.5,
  ("serving", 100), [("piece", 180)], tags=["protein", "iron", "calcium"])
I("ciecierzyca", "ciecierzyca", ["cieciorka", "groch włoski"], "legumes", 164, 8.9,
  27.4, 2.6, ("serving", 100), [("can", 240), ("tablespoon", 20)],
  tags=["protein", "iron", "fiber", "magnesium"])
I("fasola", "fasola", ["fasola czerwona", "fasola biała", "fasola konserwowa"],
  "legumes", 127, 8.7, 22.8, 0.5, ("serving", 100), [("can", 240), ("tablespoon", 20)],
  tags=["protein", "iron", "fiber", "magnesium"])
I("soczewica", "soczewica", ["soczewica czerwona", "soczewica zielona"], "legumes", 116, 9, 20, 0.4,
  ("serving", 150), [("tablespoon", 20)], tags=["protein", "iron", "fiber"])
I("edamame", "edamame", ["fasolka edamame"], "legumes", 121, 11.9, 8.9, 5.2, ("serving", 80),
  [("handful", 40)], tags=["protein", "fiber"])
I("groszek", "groszek", ["groszek zielony", "zielony groszek", "groszek konserwowy"],
  "vegetables", 81, 5.4, 14.5, 0.4, ("serving", 80), [("tablespoon", 20), ("can", 240)], tags=["fiber"])
I("hummus", "hummus", ["humus", "pasta z ciecierzycy"], "legumes", 250, 7, 13, 19, ("serving", 50),
  [("tablespoon", 20)], tags=["fiber"])
I("pasta-warzywna", "pasta warzywna", ["pasta z fasoli", "pasta z soczewicy", "pasta z warzyw"], "legumes",
  180, 5, 12, 12, ("tablespoon", 25), tags=["fiber"])
I("fasolka-szparagowa", "fasolka szparagowa", ["fasolka", "szparagówka"], "vegetables", 31, 1.8, 7, 0.2,
  ("serving", 150), tags=["fiber"])

# ---------------------------------------------------------------- grains, potatoes
I("ryz", "ryż", ["ryż biały", "ryż ugotowany", "ryż jaśminowy", "ryż basmati", "ryż paraboliczny",
                 "ryżyk", "ryż curry"],
  "grains", 130, 2.7, 28, 0.3, ("serving", 150), [("glass", 180), ("tablespoon", 20)])
I("ryz-brazowy", "ryż brązowy", ["brązowy ryż", "ryż pełnoziarnisty", "ryż dziki", "ryż czerwony"],
  "grains", 112, 2.6, 23, 0.9, ("serving", 150), [("glass", 180)], tags=["fiber", "magnesium"])
I("ryz-suchy", "ryż suchy", ["suchy ryż", "ryż przed ugotowaniem", "ryż na sucho"], "grains", 350, 7, 78, 0.6,
  ("serving", 60))
I("makaron", "makaron", ["makaron pszenny", "makaron spaghetti", "penne", "świderki", "kokardki", "tagliatelle",
                         "nitki", "muszelki", "makaron ugotowany"],
  "grains", 158, 5.8, 31, 0.9, ("serving", 200), [("glass", 140)])
I("makaron-pelnoziarnisty", "makaron pełnoziarnisty", ["makaron razowy", "makaron żytni", "makaron orkiszowy"],
  "grains", 149, 6, 30, 1.7, ("serving", 200), tags=["fiber", "magnesium"])
I("makaron-suchy", "makaron suchy", ["suchy makaron", "makaron przed ugotowaniem", "makaron na sucho"], "grains",
  360, 12.5, 72, 1.5, ("serving", 80))
I("makaron-ryzowy", "makaron ryżowy", ["makaron sojowy", "makaron chiński", "makaron udon", "noodle", "noodles"],
  "grains", 108, 1.8, 24, 0.2, ("serving", 150))
I("kasza-gryczana", "kasza gryczana", ["kasza", "gryczana", "gryka", "kasza gryczana prażona"],
  "grains", 92, 3.4, 20, 0.6, ("serving", 150), [("glass", 170)], tags=["magnesium", "iron", "fiber"])
I("kasza-jaglana", "kasza jaglana", ["jaglana", "jaglanka", "proso"], "grains", 119, 3.5, 23.7, 1,
  ("serving", 150), [("glass", 170)], tags=["iron", "magnesium"])
I("kasza-jeczmienna", "kasza jęczmienna", ["pęczak", "kasza pęczak", "kasza perłowa", "jęczmienna",
                                            "kasza perłowa średnia", "kasza mazurska"],
  "grains", 123, 2.3, 28, 0.4, ("serving", 150), [("glass", 170)], tags=["fiber"])
I("bulgur", "kasza bulgur", ["bulgur"], "grains", 83, 3.1, 18.6, 0.2, ("serving", 150), [("glass", 180)],
  tags=["fiber"])
I("kuskus", "kuskus", ["kasza kuskus", "couscous"], "grains", 112, 3.8, 23, 0.2, ("serving", 150),
  [("glass", 160)])
I("komosa-ryzowa", "komosa ryżowa", ["quinoa", "kinoa", "komosa"], "grains", 120, 4.4, 21.3, 1.9,
  ("serving", 150), [("glass", 185)], tags=["protein", "iron", "magnesium"])
I("owsianka", "owsianka", ["owsianka na mleku", "porridge", "owsianka z mlekiem", "owsianeczka",
                           "owsianka z kakao", "owsianka kakaowa", "owsianka czekoladowa",
                           "jaglana owsianka", "owsianka jaglana"], "dishes",
  104, 5.1, 14, 2.8, ("bowl", 300), tags=["fiber"])
I("owsianka-na-wodzie", "owsianka na wodzie", ["owsianka z wodą"], "dishes", 62, 2.2, 11.2, 1.2, ("bowl", 300),
  tags=["fiber"])
I("kasza-manna", "kasza manna", ["manna", "kaszka", "kaszka manna", "kasza manna na mleku", "grysik"], "dishes",
  95, 4, 14, 2.5, ("bowl", 250), tags=["calcium"])
# Dry flakes: a bowl ("miska płatków") is the dry weight in it, 40-60 g as on the packs; a glass or a mug is what
# fits in it.
# No bare "owsiane": "latte na owsianym" is oat milk, not flakes.
I("platki-owsiane", "płatki owsiane", ["płatki", "płatki górskie", "płatki owsiane górskie",
                                       "płatki błyskawiczne", "otręby", "otręby owsiane",
                                       "owsianka z płatków", "owsianka płatki", "owsianych"],
  "grains", 372, 13, 67, 7, ("serving", 50),
  [("tablespoon", 10), ("glass", 90), ("handful", 30), ("bowl", 50), ("mug", 110)],
  tags=["fiber", "magnesium", "iron"])
I("platki-kukurydziane", "płatki kukurydziane", ["corn flakes", "cornflakes", "płatki śniadaniowe",
                                                 "płatki czekoladowe", "cini minis"],
  "grains", 378, 7, 84, 0.9, ("serving", 40), [("glass", 30), ("bowl", 40), ("mug", 35)])
I("musli", "musli", ["muesli", "musli owocowe"], "grains", 360, 9, 66, 6, ("serving", 50),
  [("tablespoon", 10), ("glass", 100), ("bowl", 50), ("mug", 120)], tags=["fiber"])
I("granola", "granola", ["granola orzechowa"], "grains", 450, 10, 62, 18, ("serving", 40),
  [("tablespoon", 10), ("bowl", 50), ("glass", 110), ("mug", 130)], tags=["fiber"])
I("maka", "mąka", ["mąka pszenna", "mąka orkiszowa"], "grains", 350, 10, 74, 1.2, ("tablespoon", 10),
  [("glass", 130)])
I("ziemniaki", "ziemniaki", ["ziemniak", "kartofle", "kartofel", "ziemniaczki", "ziemniaki gotowane",
                             "młode ziemniaki", "ziemniaczek", "ziemniaki z wody", "pyry", "pyrki"],
  "vegetables", 80, 1.9, 18, 0.1, ("piece", 100), [("serving", 200)],
  singular=["ziemniak", "kartofel", "ziemniaczek"])
I("batat", "batat", ["bataty", "słodki ziemniak", "słodkie ziemniaki"], "vegetables", 87, 1.6, 20, 0.1,
  ("piece", 200), [("serving", 150)], tags=["fiber"])
# A count means single fries ("parę frytek"); a bare "frytki" is the serving.
I("frytki", "frytki", ["frytki belgijskie", "frytka"], "dishes", 290, 3.4, 38, 14, ("piece", 3), [("serving", 150)],
  singular=["frytka"])
I("frytki-z-batatow", "frytki z batatów", ["frytki z batata", "frytki batatowe"], "dishes", 190, 2, 28, 8,
  ("serving", 150), tags=["fiber"])
I("puree", "puree ziemniaczane", ["puree", "purée", "tłuczone ziemniaki", "ziemniaki puree", "puree z ziemniaków"],
  "dishes", 113, 1.9, 16.8, 4.2, ("serving", 200))
I("kopytka", "kopytka", ["kopytko", "gnocchi"], "dishes", 165, 4, 32, 2, ("piece", 20), [("serving", 250)],
  singular=["kopytko"])
I("kluski-slaskie", "kluski śląskie", ["kluski", "kluseczki", "kluski ziemniaczane"],
  "dishes", 140, 2.5, 30, 1, ("piece", 25), [("serving", 250)])

# ---------------------------------------------------------------- dishes
I("pierogi-ruskie", "pierogi ruskie", ["pierogi", "ruskie", "pieróg ruski", "pierożki", "pieróg"], "dishes",
  200, 6, 30, 6, ("piece", 45), [("serving", 270)], singular=["pieróg ruski", "pieróg"])
I("pierogi-z-miesem", "pierogi z mięsem", ["pieróg z mięsem", "pierożki z mięsem"], "dishes", 225, 10, 28, 8,
  ("piece", 45), [("serving", 270)], tags=["protein"], singular=["pieróg z mięsem"])
I("pierogi-z-serem", "pierogi z serem", ["pierogi z twarogiem", "pierogi na słodko"], "dishes", 210, 9, 30, 6,
  ("piece", 45), [("serving", 270)])
I("pierogi-z-kapusta", "pierogi z kapustą i grzybami", ["pierogi z kapustą", "pierogi z grzybami",
                                                       "pierogi z kapustą i pieczarkami"],
  "dishes", 180, 5, 30, 4.5, ("piece", 45), [("serving", 270)])
I("pierogi-z-owocami", "pierogi z owocami", ["pierogi z jagodami", "pierogi z truskawkami",
                                             "pierogi z borówkami", "pierogi z wiśniami"],
  "dishes", 190, 5, 37, 2.5, ("piece", 45), [("serving", 270)])
I("leniwe", "kluski leniwe", ["leniwe", "pierogi leniwe", "leniwe pierogi"], "dishes", 200, 9, 28, 6,
  ("serving", 250))
I("uszka", "uszka", ["uszko"], "dishes", 210, 5, 33, 6.5, ("piece", 8), [("serving", 80)], singular=["uszko"])
I("nalesniki", "naleśniki", ["naleśnik", "naleśniczki", "crepes"], "dishes", 200, 7, 27, 7, ("piece", 60),
  [("serving", 120)], singular=["naleśnik"])
# "naleśniki ruskie", "krokiety ruskie": filled like pierogi ruskie, not a plate of pierogi besides; a filled
# naleśnik counts as one of these (naleśniki z serem), not as a plain one of 60 g.
I("nalesniki-z-serem", "naleśniki z serem", ["naleśniki z twarogiem", "naleśnik z serem", "naleśnik z twarogiem",
                                             "naleśniki z serem na słodko", "naleśniki ruskie", "naleśnik ruski"],
  "dishes", 200, 10, 25, 6.5, ("piece", 100), [("serving", 200)], tags=["protein"],
  singular=["naleśnik z serem", "naleśnik z twarogiem", "naleśnik ruski"])
I("placki-ziemniaczane", "placki ziemniaczane", ["placki", "placek ziemniaczany", "placuszki ziemniaczane"],
  "dishes", 210, 4, 25, 10, ("piece", 60), [("serving", 180)], singular=["placek ziemniaczany"])
I("placuszki", "placuszki", ["placuszki owsiane", "pancakes", "racuchy", "racuszki", "placuszki bananowe",
                             "placki owsiane"],
  "dishes", 220, 7, 32, 7, ("piece", 40), [("serving", 160)])
I("golabki", "gołąbki", ["gołąbek"], "dishes", 110, 6, 9, 5.5, ("piece", 180), [("serving", 360)],
  singular=["gołąbek"])
I("bigos", "bigos", [], "dishes", 120, 6, 6, 8, ("serving", 300))
I("gulasz", "gulasz", ["gulasz wołowy", "gulasz wieprzowy", "gulasz z indyka", "strogonow"], "dishes",
  140, 12, 5, 8, ("serving", 250), tags=["protein"])
# Named pizzas stay one pizza: "pizza salami" is not a pizza plus salami.
I("pizza", "pizza", ["margherita", "pizza margherita", "pizza pepperoni", "pizza salami"], "dishes",
  250, 11, 30, 9.5, ("piece", 400), [("chunk", 110)])
I("zapiekanka", "zapiekanka", ["zapiekanka makaronowa", "zapiekanka z pieczarkami"], "dishes",
  230, 9, 30, 8.5, ("piece", 250))
I("hamburger", "hamburger", ["burger", "cheeseburger", "hamburger wołowy"], "dishes", 250, 13, 24, 11,
  ("piece", 200))
I("kebab", "kebab", ["kebab w bułce", "kebab w picie", "kebab w tortilli", "döner", "doner",
                     "kebab z kurczakiem", "kebab z kurczaka", "kebab z baraniną"], "dishes",
  215, 11, 20, 10, ("piece", 400))
I("hot-dog", "hot dog", ["hotdog"], "dishes", 260, 10, 25, 13, ("piece", 120))
# The fish, shrimp or vegetable named after "z" is inside the rolls: "sushi z łososiem 8 sztuk" is 8 rolls.
I("sushi", "sushi", ["nigiri", "futomaki", "california roll", "sushi maki", "sushi z łososiem", "sushi z łososia",
                     "sushi z tuńczykiem", "sushi z krewetką", "sushi z krewetkami", "sushi z ogórkiem",
                     "sushi z awokado", "sushi z węgorzem"], "dishes", 150, 6, 28, 1.8,
  ("piece", 25), [("chunk", 25), ("serving", 200)])
I("lasagne", "lasagne", ["lazania", "lasagna"], "dishes", 160, 9, 14, 7.5, ("serving", 300), [("chunk", 250)])
I("spaghetti-bolognese", "spaghetti bolognese", ["spaghetti", "spagetti", "bolognese", "spaghetti bolońskie",
                                                 "makaron z sosem bolońskim", "spaghetti z sosem bolońskim",
                                                 "makaron po bolońsku", "makaron bolognese"],
  "dishes", 150, 7, 18, 5, ("serving", 350))
I("makaron-carbonara", "spaghetti carbonara", ["carbonara", "makaron carbonara"], "dishes", 220, 9, 22, 10.5,
  ("serving", 300))
I("risotto", "risotto", ["risotto z grzybami"], "dishes", 140, 4, 20, 4.5, ("serving", 300))
I("leczo", "leczo", [], "dishes", 75, 3, 6, 4.5, ("serving", 300))
I("fasolka-po-bretonsku", "fasolka po bretońsku", ["fasola po bretońsku"], "dishes", 120, 6.5, 13, 4.5,
  ("serving", 300), tags=["protein", "fiber"])
I("chili-con-carne", "chili con carne", [], "dishes", 110, 8.5, 9, 4.5, ("serving", 300), tags=["protein"])
I("krokiety", "krokiety", ["krokiet", "pasztecik", "krokiety ruskie", "krokiet ruski"], "dishes", 220, 8, 22, 11,
  ("piece", 100), [("serving", 200)], singular=["krokiet", "pasztecik", "krokiet ruski"])
# Only patties whose "z …" is no usual side: "kotlet z kaszą" stays a chop with kasza.
I("kotlet-warzywny", "kotlet warzywny", ["kotlet sojowy", "kotlet wegetariański", "kotlet wege",
                                         "kotlet z ciecierzycy", "kotlet z soczewicy", "kotlet z kalafiora",
                                         "kotlet z kaszy jaglanej", "kotlet jaglany"],
  "dishes", 200, 10, 18, 10, ("piece", 100))
I("ser-smazony", "ser smażony", ["smażony ser", "ser panierowany"], "dishes", 330, 17, 14, 23, ("piece", 120),
  tags=["calcium"])
I("placek-po-wegiersku", "placek po węgiersku", [], "dishes", 165, 7, 15, 8.5, ("serving", 450))
I("papryka-faszerowana", "papryka faszerowana", ["faszerowana papryka"], "dishes", 110, 6, 9, 5.5,
  ("piece", 250))
I("salatka", "sałatka", ["sałatka z warzyw", "sałatka zielona", "sałateczka", "sałatka mieszana"],
  "dishes", 74, 1.2, 4, 5.8, ("serving", 200), tags=["fiber"])
I("salatka-grecka", "sałatka grecka", [], "dishes", 113, 3.5, 4.5, 9, ("serving", 250))
I("salatka-cezar", "sałatka cezar", ["cezar", "caesar", "sałatka caesar"], "dishes", 150, 9, 7, 9.5,
  ("serving", 300), tags=["protein"])
I("salatka-jarzynowa", "sałatka jarzynowa", ["sałatka warzywna", "sałatka ziemniaczana"], "dishes",
  160, 2.5, 9, 12.5, ("serving", 150))
I("surowka", "surówka", ["surówka z marchewki", "surówka z marchwi", "surówka z kapusty", "surówka z buraków",
                         "surówka z selera", "surówka z kiszonej kapusty", "surówka z kapusty kiszonej",
                         "coleslaw"],
  "vegetables", 55, 1, 7, 2.5, ("serving", 120), tags=["fiber"])
I("mizeria", "mizeria", ["ogórki ze śmietaną", "ogórek ze śmietaną"], "vegetables", 50, 1, 3.5, 3.6,
  ("serving", 150))

# ---------------------------------------------------------------- soups (as served)
I("zupa-pomidorowa", "zupa pomidorowa", ["pomidorowa", "pomidorówka", "zupa pomidorowa z ryżem",
                                         "zupa pomidorowa z makaronem", "pomidorowa z ryżem",
                                         "pomidorowa z makaronem", "krem pomidorowy", "krem z pomidorów", "zupa krem z pomidorów"],
  "dishes", 65, 2, 10.5, 1.6, ("serving", 350), [("bowl", 350)])
I("rosol", "rosół", ["rosół z makaronem", "rosołek", "bulion", "rosół z kurczaka", "rosół z kluskami",
                     "rosół z kurczaka z makaronem"],
  "dishes", 43, 2.5, 5, 1.5, ("serving", 350), [("bowl", 350)])
I("zurek", "żurek", ["żur", "barszcz biały", "żurek z kiełbasą"],
  "dishes", 75, 3, 6, 4.3, ("serving", 350), [("bowl", 350)])
# Soup in a bread bowl: about 350 g of żurek and 150 g of the bread eaten.
I("zurek-w-chlebie", "żurek w chlebie", ["żur w chlebie"], "dishes", 125, 4.5, 19, 3.8, ("serving", 500))
I("barszcz", "barszcz czerwony", ["barszcz", "barszczyk", "barszcz ukraiński"], "dishes", 26, 0.8, 5, 0.3,
  ("serving", 300), [("bowl", 300)])
I("zupa-ogorkowa", "zupa ogórkowa", ["ogórkowa", "ogórkówka"], "dishes", 50, 1.5, 6.5, 2, ("serving", 350),
  [("bowl", 350)])
I("zupa-jarzynowa", "zupa jarzynowa", ["jarzynowa", "zupa warzywna", "warzywna", "zupa"],
  "dishes", 40, 1.3, 6, 1.2, ("serving", 350), [("bowl", 350)], tags=["fiber"])
I("zupa-krem", "zupa krem", ["krem z dyni", "zupa krem z dyni", "zupa dyniowa", "dyniowa", "krem z brokułów",
                             "krem z brokuła", "krem z cukinii", "krem z marchewki", "krem z kalafiora",
                             "krem z groszku", "krem z pieczarek", "krem ziemniaczany", "krem z batatów",
                             "zupa krem z brokułów"],
  "dishes", 55, 1.5, 6.5, 2.5, ("serving", 350), [("bowl", 350)], tags=["fiber"])
I("kapusniak", "kapuśniak", ["zupa z kapusty", "zupa kapuściana"], "dishes", 45, 2, 5, 2, ("serving", 350),
  [("bowl", 350)])
I("grochowka", "grochówka", ["zupa grochowa", "grochowa", "zupa fasolowa", "fasolowa"], "dishes",
  90, 5.5, 10, 3, ("serving", 350), [("bowl", 350)], tags=["protein", "fiber"])
I("krupnik", "krupnik", ["zupa jęczmienna"], "dishes", 50, 2, 7.5, 1.4, ("serving", 350), [("bowl", 350)])
I("zupa-grzybowa", "zupa grzybowa", ["grzybowa", "zupa z grzybów", "zupa pieczarkowa", "pieczarkowa"],
  "dishes", 45, 1.5, 5, 2, ("serving", 350), [("bowl", 350)])
I("zupa-soczewicowa", "zupa z soczewicy", ["zupa soczewicowa", "soczewicowa", "dahl"], "dishes",
  80, 4.5, 11, 2, ("serving", 350), [("bowl", 350)], tags=["protein", "iron", "fiber"])
I("chlodnik", "chłodnik", ["chłodnik litewski"], "dishes", 60, 3, 5, 3, ("serving", 350), [("bowl", 350)])

# ---------------------------------------------------------------- vegetables
I("salata", "sałata", ["sałata lodowa", "sałata masłowa", "mix sałat", "sałata rzymska", "sałacie",
                       "liście sałaty", "roszponka", "mieszanka sałat"],
  "vegetables", 15, 1.4, 2.9, 0.2, ("handful", 30), [("serving", 50)])
I("pomidor", "pomidor", [], "vegetables", 18, 0.9, 3.9, 0.2, ("piece", 130),
  [("thinSlice", 20)])
I("pomidorki-koktajlowe", "pomidorki koktajlowe", ["pomidorki", "pomidorki cherry", "pomidorek koktajlowy",
                                                   "pomidorki daktylowe"],
  "vegetables", 18, 0.9, 3.9, 0.2, ("piece", 15), [("handful", 80), ("serving", 100)],
  singular=["pomidorek koktajlowy"])
I("ogorek", "ogórek", ["ogórek zielony", "ogórek świeży", "ogóreczek", "ogórek szklarniowy"],
  "vegetables", 15, 0.7, 3.6, 0.1, ("piece", 150), [("thinSlice", 10)])
I("ogorek-kiszony", "ogórek kiszony", ["ogórki kiszone", "kiszony ogórek", "kiszone ogórki", "ogórek kwaszony",
                                       "ogórki kwaszone", "ogórek konserwowy", "ogórki konserwowe", "korniszony"],
  "vegetables", 12, 1, 2, 0.1, ("piece", 70))
I("papryka", "papryka", ["papryka czerwona", "papryka żółta", "papryka zielona", "papryczka"], "vegetables",
  31, 1, 6, 0.3, ("piece", 150))
I("brokul", "brokuł", ["brokuły", "brokułki"], "vegetables", 34, 2.8, 6.6, 0.4, ("serving", 150),
  [("piece", 350)], tags=["fiber", "calcium"])
I("kalafior", "kalafior", [], "vegetables", 25, 1.9, 5, 0.3, ("serving", 150), [("piece", 600)], tags=["fiber"])
I("szpinak", "szpinak", ["baby szpinak", "liście szpinaku"], "vegetables", 23, 2.9, 3.6, 0.4, ("handful", 30),
  [("serving", 100)], tags=["iron", "magnesium"])
I("jarmuz", "jarmuż", [], "vegetables", 45, 3.5, 7, 0.9, ("handful", 30), [("serving", 100)],
  tags=["iron", "calcium", "fiber"])
I("rukola", "rukola", ["rokietta"], "vegetables", 25, 2.6, 3.7, 0.7, ("handful", 20), [("serving", 50)])
I("marchew", "marchew", ["marchewka", "marchewka z groszkiem", "marcheweczka"],
  "vegetables", 41, 0.9, 9.6, 0.2, ("piece", 80), tags=["fiber"])
I("rzodkiewka", "rzodkiewka", [], "vegetables", 16, 0.7, 3.4, 0.1, ("piece", 15), [("serving", 50)])
I("cebula", "cebula", ["cebulka", "cebula czerwona", "dymka"], "vegetables", 40, 1.1, 9.3, 0.1, ("piece", 100),
  [("serving", 50)])
# "2 cząstki czosnku" are cloves, not 15 g slices.
I("czosnek", "czosnek", ["czosnek niedźwiedzi"], "vegetables", 149, 6.4, 33, 0.5, ("clove", 5), [("thinSlice", 5)])
I("cukinia", "cukinia", [], "vegetables", 17, 1.2, 3.1, 0.3, ("serving", 150), [("piece", 250)])
I("baklazan", "bakłażan", ["oberżyna"], "vegetables", 25, 1, 6, 0.2, ("serving", 150), [("piece", 300)],
  tags=["fiber"])
I("kapusta", "kapusta", ["kapusta biała", "kapusta pekińska", "kapusta kiszona", "kapusta czerwona",
                         "kapusta modra", "kapustka", "kapusta zasmażana"],
  "vegetables", 25, 1.3, 5.8, 0.1, ("serving", 100), tags=["fiber"])
I("buraki", "buraki", ["burak", "buraczki", "ćwikła", "buraczek"], "vegetables", 43, 1.6, 9.6, 0.2,
  ("serving", 100), [("piece", 150)], tags=["fiber", "iron"])
I("dynia", "dynia", ["dynia hokkaido"], "vegetables", 26, 1, 6.5, 0.1, ("serving", 150))
I("kukurydza", "kukurydza", ["kukurydza konserwowa", "kolba kukurydzy"], "vegetables", 86, 3, 17, 1.2,
  ("serving", 80), [("tablespoon", 20), ("can", 280), ("piece", 150)], tags=["fiber"])
I("pieczarki", "pieczarki", ["pieczarka", "grzyby", "grzybki", "boczniaki", "kurki", "grzyb"], "vegetables",
  22, 3.1, 3.3, 0.3, ("piece", 20), [("serving", 100)], singular=["pieczarka"])
I("seler", "seler", ["seler naciowy", "seler korzeniowy"], "vegetables", 20, 0.8, 4, 0.2,
  ("serving", 50))
I("por", "por", [], "vegetables", 61, 1.5, 14, 0.3, ("piece", 150), tags=["fiber"])
I("szczypiorek", "szczypiorek", ["szczypior"], "vegetables", 30, 3.3, 4.4, 0.7, ("tablespoon", 5))
I("natka-pietruszki", "natka pietruszki", ["natka", "pietruszka", "zielona pietruszka"],
  "vegetables", 36, 3, 6.3, 0.8, ("tablespoon", 5), tags=["iron"])
I("koperek", "koperek", ["koper"], "vegetables", 43, 3.5, 7, 1.1, ("tablespoon", 5))
I("bazylia", "bazylia", ["świeża bazylia", "listki bazylii"], "vegetables", 23, 3.2, 2.7, 0.6, ("tablespoon", 3))
I("kielki", "kiełki", ["kiełki rzodkiewki", "kiełki fasoli", "rzeżucha"], "vegetables", 30, 3, 6, 0.2, ("handful", 25))
I("awokado", "awokado", ["avocado", "pasta z awokado", "guacamole"], "fruit", 160, 2, 8.5, 14.7, ("piece", 140),
  [("serving", 70)], tags=["magnesium", "fiber"])
I("warzywa", "warzywa", ["warzywka", "mieszanka warzyw", "bukiet warzyw", "warzywa gotowane",
                         "warzywa na patelnię", "mrożone warzywa", "warzywa z wody", "warzywa mrożone",
                         "warzywa pieczone", "grillowane warzywa", "warzywa grillowane", "mix warzyw",
                         "ratatouille", "warzywa na parze"],
  "vegetables", 35, 1.8, 6.5, 0.3, ("serving", 150), tags=["fiber"])
I("oliwki", "oliwki", ["oliwka", "oliwkami", "oliwki zielone", "oliwki czarne"], "fats", 145, 1, 3.8, 15,
  ("piece", 4), [("serving", 30), ("handful", 30), ("bowl", 80)], singular=["oliwka"])

# ---------------------------------------------------------------- fruit
I("banan", "banan", [], "fruit", 97, 1.1, 22.8, 0.3, ("piece", 120), tags=["magnesium"])
I("jablko", "jabłko", ["jabłuszko"], "fruit", 52, 0.3, 13.8, 0.2, ("piece", 180), tags=["fiber"])
I("gruszka", "gruszka", [], "fruit", 57, 0.4, 15, 0.1, ("piece", 170), tags=["fiber"])
I("pomarancza", "pomarańcza", [], "fruit", 47, 0.9, 11.8, 0.1, ("piece", 150))
I("mandarynka", "mandarynka", ["klementynka"], "fruit", 53, 0.8, 13.3, 0.3, ("piece", 75))
I("kiwi", "kiwi", [], "fruit", 61, 1.1, 14.7, 0.5, ("piece", 75), tags=["fiber"])
I("truskawki", "truskawki", ["truskawka"], "fruit", 32, 0.7, 7.7, 0.3, ("piece", 15),
  [("handful", 80), ("serving", 150), ("glass", 150), ("bowl", 250)], tags=["fiber"], singular=["truskawka"])
I("maliny", "maliny", ["malina", "porzeczki", "porzeczka", "agrest"], "fruit", 52, 1.2, 12, 0.7, ("piece", 4), [("handful", 60), ("serving", 100), ("glass", 125)],
  tags=["fiber"], singular=["malina", "porzeczka"])
# A count means berries ("kilka borówek"); a bare "borówki" is the serving.
I("borowki", "borówki", ["borówka", "borówki amerykańskie", "jagody", "jagoda", "owoce leśne"], "fruit",
  57, 0.7, 14.5, 0.3, ("piece", 1.5), [("handful", 50), ("serving", 100), ("glass", 150), ("bowl", 250)],
  tags=["fiber"], singular=["borówka", "jagoda"])
I("winogrona", "winogrona", ["winogrono", "winogronka"], "fruit", 69, 0.7, 18, 0.2, ("piece", 5),
  [("handful", 80), ("serving", 150)], singular=["winogrono"])
I("arbuz", "arbuz", [], "fruit", 30, 0.6, 7.6, 0.2, ("chunk", 250), [("serving", 250), ("thinSlice", 300)])
I("melon", "melon", [], "fruit", 34, 0.8, 8.2, 0.2, ("chunk", 200),
  [("serving", 200), ("thinSlice", 150), ("piece", 1000)])
I("granat", "granat", ["pestki granatu"], "fruit", 83, 1.7, 18.7, 1.2, ("serving", 80),
  [("handful", 40), ("piece", 170)])
I("brzoskwinia", "brzoskwinia", ["nektarynka"], "fruit", 39, 0.9, 9.5, 0.3, ("piece", 150))
I("sliwki", "śliwki", ["śliwka"], "fruit", 46, 0.7, 11.4, 0.3, ("piece", 40), [("serving", 150)],
  singular=["śliwka"])
I("czeresnie", "czereśnie", ["czereśnia", "wiśnie", "wiśnia"], "fruit", 63, 1.1, 16, 0.2, ("piece", 8),
  [("handful", 80), ("serving", 150)], singular=["czereśnia", "wiśnia"])
I("morele", "morele", ["morela"], "fruit", 48, 1.4, 11, 0.4, ("piece", 40), [("serving", 150)], singular=["morela"])
I("mango", "mango", [], "fruit", 60, 0.8, 15, 0.4, ("piece", 200), [("serving", 100)])
I("ananas", "ananas", [], "fruit", 50, 0.5, 13, 0.1, ("serving", 150), [("thinSlice", 50), ("piece", 900)])
I("cytryna", "cytryna", ["limonka"], "fruit", 29, 1.1, 6.5, 0.3, ("piece", 100), [("serving", 10), ("thinSlice", 10)])
I("sok-z-cytryny", "sok z cytryny", ["sok z limonki", "sok cytrynowy"], "fruit",
  22, 0.4, 6.9, 0.2, ("piece", 40), [("tablespoon", 15), ("teaspoon", 5)])
I("daktyle", "daktyle", ["daktyl"], "fruit", 282, 2.5, 75, 0.4, ("piece", 8),
  [("serving", 30), ("bowl", 50), ("glass", 125), ("mug", 150)], tags=["fiber", "magnesium"], singular=["daktyl"])
I("rodzynki", "rodzynki", ["rodzynka"], "fruit", 299, 3.1, 79, 0.5, ("piece", 0.5),
  [("handful", 30), ("serving", 30), ("tablespoon", 12), ("bowl", 50), ("glass", 125), ("mug", 150)],
  singular=["rodzynka"])
# A count means pieces (a prune or an apricot is about 8 g); a bare mention is a handful-sized serving.
I("suszone-owoce", "suszone owoce", ["bakalie", "suszone morele", "suszone śliwki", "żurawina suszona",
                                     "żurawina", "suszona żurawina", "figi suszone", "figi"],
  "fruit", 280, 2.5, 66, 0.6, ("piece", 8),
  [("handful", 30), ("serving", 30), ("bowl", 50), ("glass", 125), ("mug", 150)], tags=["fiber"])
I("owoce", "owoce", ["owoc", "sałatka owocowa", "mrożone owoce", "owoce mrożone", "owocki"], "fruit",
  50, 0.7, 12, 0.3, ("serving", 150), tags=["fiber"])

# ---------------------------------------------------------------- nuts, seeds
# A snack bowl of nuts ("miseczka orzechów") is about 50 g, not the 350 g of a bowl of soup; a glass or a mug of
# nuts, seeds or dried fruit is what fits in it (about 125 g and 150 g), not the 250 g or 300 g of a drink.
I("orzechy", "orzechy", ["orzech", "mieszanka orzechów", "mix orzechów", "orzeszki mix", "orzechy mieszane"],
  "nuts", 610, 18, 18, 54, ("piece", 3),
  [("handful", 30), ("serving", 30), ("tablespoon", 10), ("bowl", 50), ("glass", 125), ("mug", 150)],
  tags=["magnesium"], singular=["orzech"])
I("orzechy-wloskie", "orzechy włoskie", ["orzech włoski"], "nuts", 654, 15.2, 13.7, 65.2, ("piece", 5),
  [("handful", 30), ("serving", 30), ("bowl", 50), ("glass", 100), ("mug", 120)], tags=["omega3", "magnesium"],
  singular=["orzech włoski"])
I("orzechy-laskowe", "orzechy laskowe", ["orzech laskowy", "laskowe"], "nuts", 628, 15, 16.7, 60.8,
  ("piece", 1.5), [("handful", 30), ("serving", 30), ("bowl", 50), ("glass", 125), ("mug", 150)], tags=["magnesium"],
  singular=["orzech laskowy"])
I("nerkowce", "orzechy nerkowca", ["nerkowce", "nerkowiec", "orzech nerkowca"], "nuts", 553, 18, 30, 44,
  ("piece", 1.6), [("handful", 30), ("serving", 30), ("bowl", 50), ("glass", 125), ("mug", 150)],
  tags=["magnesium", "iron"],
  singular=["nerkowiec", "orzech nerkowca"])
I("orzeszki-ziemne", "orzeszki ziemne", ["orzeszki", "orzeszki arachidowe", "fistaszki", "orzeszki solone"],
  "nuts", 585, 24, 21, 50, ("piece", 1),
  [("handful", 30), ("serving", 30), ("tablespoon", 10), ("bowl", 50), ("glass", 125), ("mug", 150)],
  tags=["protein", "magnesium"])
I("migdaly", "migdały", ["płatki migdałowe"], "nuts", 579, 21, 21.6, 49.9, ("piece", 1.2),
  [("handful", 30), ("serving", 30), ("tablespoon", 9), ("bowl", 50), ("glass", 125), ("mug", 150)],
  tags=["magnesium", "protein", "calcium"])
I("pestki-dyni", "pestki dyni", ["pestki z dyni", "pestki dyniowe", "nasiona dyni", "pestki"], "nuts", 559, 30, 10.7, 49,
  ("tablespoon", 10), [("handful", 30), ("bowl", 50), ("glass", 125), ("mug", 150)],
  tags=["protein", "iron", "magnesium"])
I("slonecznik", "słonecznik", ["pestki słonecznika", "ziarna słonecznika", "nasiona słonecznika"], "nuts",
  584, 20.8, 20, 51.5, ("tablespoon", 10), [("handful", 30), ("bowl", 50), ("glass", 125), ("mug", 150)],
  tags=["magnesium"])
I("siemie-lniane", "siemię lniane", ["siemię", "siemienia", "siemieniem", "len mielony", "nasiona lnu",
                                     "siemię lniane mielone"],
  "nuts", 534, 18.3, 28.9, 42.2, ("tablespoon", 10), tags=["omega3", "fiber", "magnesium"])
I("chia", "nasiona chia", ["chia", "nasionka chia"], "nuts", 486, 16.5, 42, 30.7, ("tablespoon", 12),
  tags=["omega3", "fiber", "calcium"])
I("pudding-chia", "pudding chia", ["chia pudding", "budyń chia"], "dishes", 95, 4.5, 8, 5, ("serving", 200),
  tags=["fiber", "omega3"])
I("sezam", "sezam", ["ziarna sezamu", "nasiona sezamu"], "nuts", 573, 17.7, 23.5, 49.7, ("tablespoon", 9),
  tags=["calcium", "iron", "magnesium"])
I("tahini", "tahini", ["pasta tahini", "pasta sezamowa"], "nuts", 595, 17, 21, 53.8, ("tablespoon", 15),
  tags=["calcium", "iron", "magnesium"])
I("maslo-orzechowe", "masło orzechowe", ["masło z orzechów ziemnych", "masło orzechowe kremowe",
                                         "masło z orzeszków", "krem orzechowy", "masło migdałowe"],
  "nuts", 588, 25, 20, 50, ("tablespoon", 16), [("teaspoon", 6)], tags=["protein", "magnesium"])
# "Nutela" is the usual misspelling: written with a capital after another word ("kanapka z Nutelą") it gets
# no typo guess, like a name.
I("krem-czekoladowy", "krem czekoladowy", ["nutella", "nutela", "krem czekoladowo-orzechowy",
                                           "krem orzechowo-czekoladowy"],
  "sweets", 539, 6.3, 57.5, 30.9, ("tablespoon", 15), [("teaspoon", 5)])

# ---------------------------------------------------------------- fats, sauces, condiments
I("oliwa", "oliwa z oliwek", ["oliwa", "oliwa extra virgin"], "fats", 884, 0, 0, 100, ("tablespoon", 12),
  [("teaspoon", 4)])
I("olej", "olej rzepakowy", ["olej", "olej słonecznikowy", "olej kokosowy", "olej lniany", "olej sezamowy",
                             "olej roślinny", "olej z pestek winogron"],
  "fats", 884, 0, 0, 100, ("tablespoon", 12), [("teaspoon", 4)])
I("majonez", "majonez", ["majonez light"], "fats", 690, 1, 2.6, 75, ("tablespoon", 15), [("teaspoon", 5)])
I("ketchup", "ketchup", ["keczup"], "other", 100, 1.5, 23, 0.2, ("tablespoon", 15), [("teaspoon", 5)])
I("musztarda", "musztarda", ["musztarda francuska", "musztarda sarepska", "musztarda miodowa"], "other",
  70, 4.4, 5.8, 3.4, ("teaspoon", 5), [("tablespoon", 15)])
I("chrzan", "chrzan", [], "other", 70, 1.5, 11, 2, ("teaspoon", 5), [("tablespoon", 15)])
I("sos-sojowy", "sos sojowy", ["sos sojowy jasny", "sos sojowy ciemny", "tamari"], "other", 53, 8, 4.9, 0.6,
  ("tablespoon", 15), [("teaspoon", 5)])
I("sos-pomidorowy", "sos pomidorowy", ["passata", "przecier pomidorowy", "koncentrat pomidorowy", "pomidory krojone"],
  "other", 55, 1.5, 7, 2.3, ("serving", 120), [("tablespoon", 20)])
I("sos", "sos", ["sosik", "sos pieczeniowy"], "other", 90, 1.5, 6, 6.5, ("serving", 60), [("tablespoon", 20)])
I("pesto", "pesto", ["pesto bazyliowe", "pesto genovese", "pesto z bazylii"], "fats", 450, 5, 5, 45.5,
  ("tablespoon", 15), [("serving", 40)])
I("sos-czosnkowy", "sos czosnkowy", ["dip czosnkowy"], "other",
  300, 2, 6, 30, ("tablespoon", 20))
I("tzatziki", "tzatziki", ["sos tzatziki", "sos jogurtowy", "dip jogurtowy"], "other", 100, 4, 4, 7.5,
  ("tablespoon", 20), [("serving", 50)])
I("dressing", "sos do sałatek", ["dressing", "winegret", "vinegret", "sos vinaigrette", "sos winegret"], "fats",
  400, 0.5, 8, 41, ("tablespoon", 15))
I("sol", "sól", ["sól morska", "sól himalajska"], "other", 0, 0, 0, 0, ("teaspoon", 1))
I("pieprz", "pieprz", ["przyprawy", "zioła prowansalskie", "oregano", "chili w proszku", "kurkuma", "imbir",
                       "bazylia suszona"],
  "other", 0, 0, 0, 0, ("teaspoon", 1))
I("cynamon", "cynamon", [], "other", 247, 4, 55, 1.2, ("teaspoon", 3))
# Cocoa powder (the drink is "kakao"): Polish labels about 330-350 kcal, carbs counted with the fibre.
I("kakao-w-proszku", "kakao w proszku", ["kakao naturalne", "kakao gorzkie", "kakao extra ciemne"], "other",
  330, 20, 45, 11, ("teaspoon", 4), [("tablespoon", 8)], tags=["magnesium", "iron", "fiber"])
I("ocet", "ocet", ["ocet balsamiczny", "ocet jabłkowy", "ocet ryżowy"], "other", 18, 0, 1, 0, ("tablespoon", 15),
  [("teaspoon", 5)])

# ---------------------------------------------------------------- sweets
I("miod", "miód", ["miodek", "miodzie"], "sweets", 304, 0.3, 82, 0, ("teaspoon", 8), [("tablespoon", 20)])
I("dzem", "dżem", ["konfitura", "powidła", "marmolada", "dżem niskosłodzony", "frużelina"], "sweets",
  200, 0.4, 49, 0.1, ("teaspoon", 10), [("tablespoon", 20)])
I("cukier", "cukier", ["cukier trzcinowy", "cukier brązowy", "cukier puder"], "sweets", 400, 0, 100, 0,
  ("teaspoon", 5), [("tablespoon", 12), ("piece", 4)])
I("syrop-klonowy", "syrop klonowy", ["syrop z agawy", "syrop daktylowy", "syrop"], "sweets", 260, 0, 67, 0.1,
  ("teaspoon", 7), [("tablespoon", 20)])
# A piece of chocolate is one cube ("kostka czekolady"), 4-6 g in a 100 g bar.
I("czekolada", "czekolada", ["czekolada mleczna", "czekoladka", "czekolada biała", "czekoladzie"], "sweets",
  535, 7.6, 59, 30, ("chunk", 10), [("serving", 25), ("package", 100), ("piece", 5)])
I("czekolada-gorzka", "czekolada gorzka", ["gorzka czekolada", "czekolada deserowa"], "sweets", 598, 7.8, 45.9,
  42.6, ("chunk", 10), [("serving", 25), ("package", 100), ("piece", 5)], tags=["magnesium", "iron"])
I("ciastko", "ciastko", ["ciasteczko", "herbatnik", "ciastko owsiane", "markiza", "biszkopt", "biszkopty",
                         "pierniczek", "pierniki", "piernik"],
  "sweets", 480, 6, 65, 22, ("piece", 15), [("serving", 30)],
  singular=["ciastko", "ciasteczko", "herbatnik", "ciastko owsiane", "markiza", "biszkopt", "pierniczek", "piernik"])
I("ciasto", "ciasto", ["placek", "ciasto drożdżowe", "ciasto czekoladowe", "ciacho", "ciasto domowe", "babka",
                       "murzynek", "keks", "tort", "makowiec"],
  "sweets", 350, 5.5, 50, 14, ("chunk", 90), [("serving", 90)])
# A portion of cake is one piece: "porcja sernika" = "kawałek sernika" = "sernik".
I("sernik", "sernik", ["sernik na zimno", "serniczek"], "sweets", 300, 8, 28, 17.5, ("chunk", 100),
  [("serving", 100)], tags=["calcium"])
I("szarlotka", "szarlotka", ["jabłecznik"], "sweets", 260, 3.5, 38, 10.5, ("chunk", 100), [("serving", 100)])
I("brownie", "brownie", [], "sweets", 420, 5, 55, 20.5, ("chunk", 60), [("serving", 60)])
I("tiramisu", "tiramisu", [], "sweets", 280, 5.5, 28, 16, ("serving", 120), [("chunk", 120)])
I("kremowka", "kremówka", ["napoleonka"], "sweets", 300, 4, 30, 18, ("piece", 130))
I("rurki-z-kremem", "rurki z kremem", [], "sweets", 400, 5, 40, 24, ("piece", 45))
I("drozdzowka", "drożdżówka", ["bułka słodka", "słodka bułka", "jagodzianka", "cynamonka", "bułka z budyniem",
                               "rogal z nadzieniem", "drożdżówka z budyniem", "drożdżówka z serem",
                               "drożdżówka z kruszonką"],
  "sweets", 330, 7.5, 52, 10.5, ("piece", 90))
I("paczek", "pączek", ["pączuś", "donut", "oponka"], "sweets", 395, 6, 50, 19, ("piece", 70))
I("muffin", "muffin", ["muffinka", "babeczka"], "sweets", 380, 5.5, 50, 17.5, ("piece", 80))
I("gofr", "gofr", ["gofry", "gofer"], "sweets", 300, 7, 38, 13, ("piece", 80))
# A bowl or a mug of ice cream is about 150 g, not the 350 g of a bowl of soup or the 300 g of a drink.
I("lody", "lody", ["lody waniliowe", "lody czekoladowe", "lody śmietankowe", "sorbet", "loda", "lodzik", "lody w waflu",
                   "lody w rożku"],
  "sweets", 207, 3.5, 23.6, 11, ("serving", 100), [("piece", 60), ("bowl", 150), ("mug", 150)])
I("baton", "baton", ["batonik", "batonik czekoladowy", "snickers", "snikers", "twix", "mars", "kitkat",
                     "prince polo"],
  "sweets", 480, 6, 60, 23.5, ("piece", 50))
I("baton-proteinowy", "baton proteinowy", ["batonik proteinowy", "baton białkowy", "batonik białkowy"],
  "sweets", 370, 30, 35, 12, ("piece", 55), tags=["protein"])
I("baton-zbozowy", "baton zbożowy", ["batonik zbożowy", "baton musli", "batonik musli", "baton owsiany",
                                    "batonik owsiany"],
  "sweets", 410, 6, 66, 14, ("piece", 25))
I("wafelek", "wafelek", ["wafelki", "wafelek czekoladowy"], "sweets", 520, 6, 60, 28, ("piece", 30))
I("budyn", "budyń", ["budyń waniliowy", "budyń czekoladowy", "pudding", "budyń na mleku"], "sweets",
  95, 3.2, 16, 2, ("serving", 150))
I("kisiel", "kisiel", [], "sweets", 70, 0, 17.5, 0, ("serving", 200))
I("galaretka", "galaretka", ["galaretka owocowa"], "sweets", 66, 1.5, 15, 0, ("serving", 150))
I("chalwa", "chałwa", [], "sweets", 516, 12, 60, 25, ("chunk", 30))
# A snack bowl of gummies or sweets is about 60 g, a mug of them 150 g.
I("zelki", "żelki", ["żelek", "żelka", "misie żelki"], "sweets", 343, 6.9, 77, 0.2, ("piece", 3),
  [("handful", 30), ("serving", 30), ("package", 100), ("bowl", 60), ("mug", 150)], singular=["żelek", "żelka"])
I("cukierki", "cukierki", ["cukierek", "krówki", "krówka", "landrynki", "lizak"], "sweets", 400, 1, 90, 4,
  ("piece", 8), [("bowl", 60), ("mug", 150)])
I("ptasie-mleczko", "ptasie mleczko", [], "sweets", 440, 3.5, 60, 21, ("piece", 11), [("package", 380)])
# Snacks: a count means single chips or sticks ("parę chipsów"); a snack bowl is 40-60 g, and a mug (300 ml)
# holds 12-50 g of them.
I("chipsy", "chipsy", ["czipsy", "chipsy ziemniaczane", "chrupki", "nachos", "tortilla chips"], "sweets",
  536, 6.6, 53, 34, ("piece", 2), [("handful", 25), ("serving", 50), ("package", 140), ("bowl", 60), ("mug", 30)])
I("paluszki", "paluszki", ["paluszki słone", "precelki", "krakersy", "krakers"], "sweets", 380, 11, 75, 4,
  ("piece", 2), [("handful", 25), ("serving", 30), ("package", 70), ("bowl", 50), ("mug", 50)],
  singular=["krakers"])
I("popcorn", "popcorn", ["popkorn"], "sweets", 450, 8, 58, 21, ("serving", 30),
  [("package", 90), ("bowl", 40), ("mug", 12)], tags=["fiber"])
I("precel", "precel", ["obwarzanek", "precel krakowski"], "bread", 340, 10, 68, 3.5, ("piece", 90))

# ---------------------------------------------------------------- drinks
I("kawa", "kawa", ["kawa czarna", "czarna kawa", "espresso", "americano", "kawa rozpuszczalna", "kawa parzona",
                   "kawa mrożona", "kawusia"],
  "drinks", 2, 0.1, 0.3, 0, ("mug", 250), [("glass", 250)])
# Milk drinks already contain their milk: "latte na owsianym", "cappuccino z mlekiem sojowym" and
# "kawa z napojem owsianym" are one drink each, not a drink plus a glass of milk (the longest alias wins
# and the kind of milk is ignored).
I("kawa-z-mlekiem", "kawa z mlekiem", ["kawa z mleczkiem", "biała kawa", "kawa biała", "kawa na mleku",
                                       "kawa ze śmietanką", "kawa na owsianym", "kawa z owsianym",
                                       "kawa z napojem owsianym", "kawa z pianką", "americano z mlekiem",
                                       "espresso z mlekiem", "kawa czarna z mlekiem",
                                       "kawa rozpuszczalna z mlekiem"],
  "drinks", 11, 0.7, 1.1, 0.4, ("mug", 250), [("glass", 250)])
I("latte", "latte", ["kawa latte", "latte macchiato", "caffe latte", "kawa mleczna", "latte na mleku",
                     "latte z mlekiem", "latte na owsianym", "latte z owsianym"],
  "drinks", 42, 2.8, 4.1, 1.6, ("mug", 300), tags=["calcium"])
I("cappuccino", "cappuccino", ["kapuczino", "kawa cappuccino", "flat white", "cappuccino na mleku",
                               "cappuccino z mlekiem",
                               "cappuccino na owsianym", "cappuccino z owsianym", "flat white na mleku",
                               "flat white z mlekiem", "flat white na owsianym"],
  "drinks", 33, 2.2, 3.2, 1.3, ("mug", 200))
# Blended iced coffee with milk and syrup, as cafés sell it (often under cream); not a cappuccino.
I("frappe", "frappe", ["frappuccino", "frapuccino", "kawa frappe", "frappe kawowe"],
  "drinks", 65, 1.8, 10, 2.2, ("mug", 350), [("glass", 300)])
I("herbata", "herbata", ["herbata czarna", "herbata zielona", "zielona herbata", "czarna herbata", "herbatka",
                         "napar", "herbata owocowa", "herbata ziołowa", "melisa", "rumianek",
                         "herbata miętowa", "yerba", "yerba mate", "earl grey"],
  "drinks", 1, 0, 0.2, 0, ("mug", 250), [("glass", 250)])
# Tea with a splash of milk, about 40 ml in a mug.
I("herbata-z-mlekiem", "herbata z mlekiem", ["herbata z mleczkiem"], "drinks", 8, 0.5, 0.7, 0.3, ("mug", 250),
  [("glass", 250)])
I("woda", "woda", ["woda mineralna", "woda gazowana", "woda niegazowana", "wodzie", "woda z cytryną",
                   "woda źródlana"],
  "drinks", 0, 0, 0, 0, ("glass", 250), [("can", 500), ("mug", 300)])
# "sok z 4 pomarańczy" is the juice of the fruit (80 ml each in the parser), not four glasses.
I("sok", "sok pomarańczowy", ["sok", "sok jabłkowy", "sok owocowy", "sok z pomarańczy", "sok multiwitamina",
                              "sok grejpfrutowy", "sok wyciskany", "fresh", "sok wiśniowy", "sok z jabłek"],
  "drinks", 45, 0.7, 10.4, 0.2, ("glass", 250), [("can", 300)])
I("sok-pomidorowy", "sok pomidorowy", ["sok warzywny", "sok z pomidorów", "sok marchwiowy", "sok z marchwi"],
  "drinks", 20, 0.8, 4, 0.1, ("glass", 250), [("can", 300)])
# The fruit is cooked into the drink: "kompot z truskawek" is one glass of kompot.
I("kompot", "kompot", ["kompot z truskawek", "kompot z jabłek", "kompot z wiśni", "kompot ze śliwek",
                       "kompot z rabarbaru", "kompot z czereśni", "kompot z porzeczek", "kompot owocowy"],
  "drinks", 45, 0.2, 11, 0, ("glass", 250))
I("cola", "cola", ["coca cola", "pepsi", "napój gazowany", "oranżada", "lemoniada", "fanta", "sprite"],
  "drinks", 42, 0, 10.6, 0, ("glass", 250), [("can", 330)])
# "bez" outside a name drops the rest ("kawa bez cukru"), so sugar-free drinks need their own names.
I("cola-zero", "cola zero", ["coca cola zero", "pepsi max", "cola light", "napój zero", "napój bez cukru",
                             "pepsi zero", "cola bez cukru", "coca cola bez cukru", "pepsi bez cukru",
                             "fanta zero", "sprite zero", "lemoniada bez cukru", "oranżada zero"],
  "drinks", 0, 0, 0, 0, ("glass", 250), [("can", 330)])
I("energetyk", "energetyk", ["napój energetyczny", "red bull", "monster"], "drinks", 45, 0, 11, 0, ("can", 250))
I("energetyk-zero", "energetyk zero", ["monster zero", "monster ultra", "red bull zero", "red bull bez cukru",
                                       "red bull sugarfree", "red bull sugar free", "energetyk bez cukru",
                                       "napój energetyczny bez cukru"],
  "drinks", 3, 0, 0.8, 0, ("can", 250))
I("kakao", "kakao", ["kakao na mleku", "gorąca czekolada", "czekolada na gorąco", "napój kakaowy",
                     "kakao z mlekiem"], "drinks",
  75, 3.4, 11, 2, ("mug", 250), tags=["calcium"])
I("piwo", "piwo", ["piwko", "browar", "piwo jasne", "lager"], "drinks", 43, 0.5, 3.6, 0, ("can", 500),
  [("mug", 500), ("glass", 300)])
I("piwo-bezalkoholowe", "piwo bezalkoholowe", ["piwo bez alkoholu", "bezalkoholowe", "piwo zero"], "drinks",
  25, 0.3, 5.5, 0, ("can", 500), [("mug", 500), ("glass", 300)])
I("wino", "wino", ["winko", "wino czerwone", "wino białe", "czerwone wino", "białe wino", "wino różowe",
                   "prosecco", "szampan", "grzaniec", "grzane wino"],
  "drinks", 83, 0.1, 2.6, 0, ("glass", 150), [("can", 750)])
# Ice in a drink ("woda z lodem"), not ice cream.
I("lod", "lód", ["lodem", "lodu"], "drinks", 0, 0, 0, 0, ("piece", 10))

# ---------------------------------------------------------------- added in the integration pass
I("bialko-jaja", "białko jaja", ["białka jaj", "białko jajka", "białka jajek", "białko z jajka"], "eggs",
  52, 11, 0.7, 0.2, ("piece", 33), tags=["protein"])
I("zoltko", "żółtko", ["żółtko jaja"], "eggs", 322, 16, 3.6, 26.5, ("piece", 17))
I("mascarpone", "mascarpone", ["ser mascarpone", "serek mascarpone"], "dairy", 435, 4.5, 4, 44,
  ("tablespoon", 20))
I("ricotta", "ricotta", ["ser ricotta", "serek ricotta"], "dairy", 174, 11, 3, 13, ("tablespoon", 25),
  [("serving", 50)], tags=["protein", "calcium"])
# "proteina" is the powder. The bare "protein" on labels of milk, yoghurt and pudding ("mleko protein 500 ml") is
# no alias, and the parser keeps it from reading as a form of "proteina" (a false friend).
I("odzywka-bialkowa", "odżywka białkowa", ["odżywka", "proteina", "białko serwatkowe", "szejk białkowy",
                                          "shake białkowy", "koktajl białkowy", "wpc", "koktajl proteinowy",
                                          "shake proteinowy", "szejk proteinowy"],
  "other", 380, 75, 8, 5.5, ("serving", 30), tags=["protein"])
I("slodzik", "słodzik", ["erytrytol", "stewia", "ksylitol"], "sweets", 0, 0, 0, 0, ("teaspoon", 4))
I("wiorki-kokosowe", "wiórki kokosowe", ["wiórki", "kokos"], "nuts", 660, 6.9, 24, 64.5, ("tablespoon", 6))
I("szparagi", "szparagi", ["szparag"], "vegetables", 20, 2.2, 3.9, 0.1, ("serving", 150), tags=["fiber"])
I("grejpfrut", "grejpfrut", ["grejfrut", "pomelo"], "fruit", 42, 0.8, 10.7, 0.1, ("piece", 250))
I("falafel", "falafel", [], "legumes", 333, 13, 32, 18, ("piece", 17), [("serving", 100)],
  tags=["protein", "fiber"])
I("burrito", "burrito", ["quesadilla", "enchilada"], "dishes", 200, 9, 25, 7, ("piece", 300))
I("pad-thai", "pad thai", ["padthai", "makaron pad thai"], "dishes", 170, 8, 22, 6, ("serving", 350))
I("curry", "curry", ["curry z kurczakiem", "kurczak curry", "tikka masala", "kurczak tikka masala"], "dishes",
  120, 9, 6, 6.5, ("serving", 300), tags=["protein"])
I("ramen", "ramen", ["zupa ramen", "pho", "zupa pho", "zupka chińska", "chińska zupka", "zupka instant"],
  "dishes", 90, 4.5, 12, 2.8, ("serving", 450))
I("tortellini", "tortellini", ["ravioli"], "dishes", 180, 8, 26, 5, ("serving", 200))
I("kaczka", "kaczka", ["pierś z kaczki", "kaczka pieczona", "surowa pierś z kaczki"], "meat", 230, 19, 0, 17,
  ("serving", 150), tags=["protein", "iron"])
I("wodka", "wódka", ["wódki", "wódeczka", "gin", "whisky", "rum", "nalewka", "tequila"], "drinks",
  231, 0, 0, 0, ("glass", 50))
I("drink", "drink", ["drinki", "aperol", "mojito", "koktajl alkoholowy", "spritz", "cydr"],
  "drinks", 110, 0, 12, 0, ("glass", 200))

I("nuggetsy", "nuggetsy", ["nuggets", "stripsy", "kurczak nuggets", "nuggetsy z kurczaka", "stripsy z kurczaka"],
  "meat", 270, 15, 17, 16, ("piece", 18), [("serving", 108)], tags=["protein"])
I("skrzydelka", "skrzydełka", ["skrzydełko", "skrzydełka z kurczaka", "skrzydełka kurczaka"], "meat", 245, 23, 0, 17,
  ("piece", 35), [("serving", 175)], tags=["protein"], singular=["skrzydełko"])
I("pulpety", "pulpety", ["klopsiki", "pulpeciki", "klopsik", "pulpet", "kulki mięsne"], "meat", 220, 14, 8, 15,
  ("piece", 40), [("serving", 160)], tags=["protein"], singular=["pulpet", "klopsik"])
I("tacos", "tacos", ["taco"], "dishes", 210, 9, 20, 10, ("piece", 100))
I("pasta-z-tunczyka", "pasta z tuńczyka", ["pasta tuńczykowa"], "fish", 200, 15, 2, 15, ("tablespoon", 30),
  tags=["protein"])
I("bulka-tarta", "bułka tarta", ["panierka", "tarta bułka"], "grains", 350, 11, 72, 2, ("tablespoon", 10))
I("napoj-izotoniczny", "napój izotoniczny", ["izotonik", "napój sportowy"], "drinks", 26, 0, 6.5, 0, ("glass", 250),
  [("can", 500)])
I("mieta", "mięta", ["listki mięty", "świeża mięta"], "vegetables", 44, 3.8, 8, 0.9, ("tablespoon", 2))
I("pianki", "pianki", ["pianka", "marshmallow", "marshmallows"], "sweets", 318, 1.8, 81, 0.2, ("piece", 6),
  [("handful", 20), ("serving", 20)], singular=["pianka"])
I("kasza-gryczana-sucha", "kasza gryczana sucha", ["sucha kasza gryczana", "sucha kasza", "kasza sucha",
                                                    "kasza przed ugotowaniem", "kasza na sucho",
                                                    "kasza gryczana na sucho"],
  "grains", 343, 13, 72, 3.4, ("serving", 60), tags=["magnesium", "iron", "fiber"])
# Raspberry syrup ("sok z malin" in Polish homes); a glass of the diluted drink holds about 40 g of it.
I("syrop-malinowy", "sok malinowy", ["syrop malinowy", "sok z malin", "syrop owocowy"], "sweets",
  250, 0, 62, 0, ("tablespoon", 15), [("teaspoon", 5), ("glass", 40)])
I("mak", "mak", ["makiem", "maku", "mak niebieski"], "nuts", 525, 18, 28, 42, ("teaspoon", 3), [("tablespoon", 9)],
  tags=["calcium", "magnesium"])
I("proszek-do-pieczenia", "proszek do pieczenia", ["soda oczyszczona", "soda do pieczenia"], "other", 53, 0, 13, 0,
  ("teaspoon", 4))
I("drozdze", "drożdże", ["drożdży"], "other", 93, 12, 8, 1.5, ("serving", 25))
