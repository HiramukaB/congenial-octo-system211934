import Foundation
import Testing
@testable import AboutHerCore

/// One product a phrase should turn into.
struct MealExpectation: Sendable {
    let foodID: String
    let amount: Double
    let unit: PortionUnit?
    let grams: Double
    let isGuess: Bool
}

/// A phrase she might type and what the parser should make of it.
struct MealPhrase: Sendable, CustomTestStringConvertible {
    let text: String
    let items: [MealExpectation]
    let unknown: [String]

    var testDescription: String { text }
}

struct CleanedNameCase: Sendable, CustomTestStringConvertible {
    let fragment: String
    let name: String

    var testDescription: String { fragment }
}

private func parsedAs(_ foodID: String, _ amount: Double, _ unit: PortionUnit?, _ grams: Double,
                      guess: Bool = false) -> MealExpectation {
    MealExpectation(foodID: foodID, amount: amount, unit: unit, grams: grams, isGuess: guess)
}

private func typed(_ text: String, _ items: [MealExpectation], unknown: [String] = []) -> MealPhrase {
    MealPhrase(text: text, items: items, unknown: unknown)
}

/// Checks the products, amounts, units, grams and leftovers of one phrase.
private func expectParse(_ expected: MealPhrase, with parser: MealParser) {
    let meal = parser.parse(expected.text)
    #expect(meal.items.map(\.foodID) == expected.items.map(\.foodID), "\(expected.text)")
    #expect(meal.unknown == expected.unknown, "\(expected.text)")
    for (got, want) in zip(meal.items, expected.items) {
        #expect(abs(got.amount - want.amount) < 1e-9, "\(expected.text): amount \(got.amount)")
        #expect(got.unit == want.unit, "\(expected.text): unit")
        #expect(abs(got.grams - want.grams) < 1e-9, "\(expected.text): grams \(got.grams)")
        #expect(got.isGuess == want.isGuess, "\(expected.text): guess")
    }
    #expect(meal.totals == meal.items.map(\.macros).sum())
}

/// A small catalog with generic values per 100 g, built in code so these tests don't depend on
/// the bundled FoodDB.json. Some inflected forms are left out on purpose (jajek, czosnku, ogórków,
/// cukru), so the parser's own Polish endings are what recognises them.
enum MealFixture {
    static let items: [FoodItem] = [
        food("jajko", "jajko", ["jajka", "jajo"], .eggs, 140, 12.5, 0.6, 9.7, .piece, 55, tags: [.protein]),
        food("chleb", "chleb", ["chleb pszenny", "pieczywo"], .bread, 250, 8.5, 48, 2, .slice, 35),
        food("chleb-zytni", "chleb żytni", ["chleb razowy", "razowiec"], .bread, 225, 6, 43, 1.5, .slice, 40,
             tags: [.fiber, .magnesium]),
        food("bulka", "bułka", ["bułka pszenna", "kajzerka"], .bread, 280, 9, 56, 2, .piece, 60),
        food("maslo", "masło", ["masełko"], .fats, 735, 0.7, 0.7, 81, .teaspoon, 5, portions: [(.tablespoon, 15)]),
        food("maslo-orzechowe", "masło orzechowe", ["masło z orzechów ziemnych"], .nuts, 600, 25, 16, 50,
             .tablespoon, 16, portions: [(.teaspoon, 6)], tags: [.protein, .magnesium]),
        food("oliwa", "oliwa z oliwek", ["oliwa"], .fats, 884, 0, 0, 100, .tablespoon, 12, portions: [(.teaspoon, 4)]),
        food("olej", "olej rzepakowy", ["olej"], .fats, 884, 0, 0, 100, .tablespoon, 12, portions: [(.teaspoon, 4)]),
        food("mleko", "mleko", ["mleko krowie"], .dairy, 50, 3.3, 4.8, 2, .glass, 250,
             portions: [(.mug, 300)], tags: [.calcium]),
        food("mleko-bez-laktozy", "mleko bez laktozy", [], .dairy, 47, 3.3, 4.7, 1.5, .glass, 250, tags: [.calcium]),
        food("kawa", "kawa", ["kawa czarna", "espresso"], .drinks, 2, 0.1, 0.3, 0, .mug, 250,
             portions: [(.glass, 250)]),
        food("kawa-z-mlekiem", "kawa z mlekiem", ["latte", "kawa latte"], .drinks, 35, 2, 3, 1.6, .mug, 300,
             tags: [.calcium]),
        food("herbata", "herbata", ["herbata czarna"], .drinks, 1, 0, 0.2, 0, .mug, 250),
        food("banan", "banan", [], .fruit, 97, 1.1, 22.8, 0.3, .piece, 120, tags: [.magnesium]),
        food("jablko", "jabłko", [], .fruit, 52, 0.3, 13.8, 0.2, .piece, 180, tags: [.fiber]),
        food("awokado", "awokado", [], .fruit, 160, 2, 8.5, 14.7, .piece, 140, tags: [.magnesium, .fiber]),
        food("losos", "łosoś", ["łosoś pieczony"], .fish, 208, 20, 0, 13.4, .serving, 150, tags: [.protein, .omega3]),
        food("ryz", "ryż", ["ryż biały"], .grains, 130, 2.7, 28, 0.3, .serving, 150, portions: [(.glass, 180)]),
        food("ziemniaki", "ziemniaki", ["kartofle"], .vegetables, 77, 2, 17, 0.1, .piece, 100,
             portions: [(.serving, 200)]),
        food("ser-zolty", "ser żółty", ["ser", "gouda"], .dairy, 356, 25, 2.2, 27.4, .thinSlice, 15,
             tags: [.protein, .calcium]),
        food("serek-wiejski", "serek wiejski", ["serek"], .dairy, 97, 11, 2.7, 4.5, .package, 200,
             tags: [.protein, .calcium]),
        food("twarog", "twaróg", ["twaróg półtłusty"], .dairy, 133, 18.7, 3.5, 4.7, .serving, 100,
             portions: [(.tablespoon, 30)], tags: [.protein, .calcium]),
        food("jogurt", "jogurt naturalny", ["jogurt"], .dairy, 61, 4.3, 6.2, 2, .package, 150,
             portions: [(.tablespoon, 20)], tags: [.calcium]),
        food("jogurt-grecki", "jogurt grecki", ["jogurt typu greckiego"], .dairy, 122, 5.5, 4.2, 9.5, .package, 150,
             portions: [(.tablespoon, 25)], tags: [.calcium]),
        food("piers-z-kurczaka", "pierś z kurczaka", ["filet z kurczaka", "kurczak"], .meat, 110, 23, 0, 1.5,
             .serving, 150, tags: [.protein]),
        food("indyk", "pierś z indyka", ["indyk", "filet z indyka"], .meat, 84, 19.2, 0, 0.7, .serving, 150,
             tags: [.protein]),
        food("szynka", "szynka", ["szynka wieprzowa", "wędlina"], .meat, 110, 18, 1.5, 3.5, .thinSlice, 15,
             tags: [.protein]),
        food("czosnek", "czosnek", [], .vegetables, 149, 6.4, 33, 0.5, .clove, 5),
        food("pomidor", "pomidor", [], .vegetables, 18, 0.9, 3.9, 0.2, .piece, 150),
        food("zupa-pomidorowa", "zupa pomidorowa", ["pomidorowa", "pomidorówka"], .dishes, 50, 1.5, 7, 1.8,
             .serving, 300, portions: [(.bowl, 350)]),
        food("zupa-jarzynowa", "zupa jarzynowa", ["zupa", "jarzynowa"], .dishes, 40, 1.2, 6, 1.2, .serving, 300,
             portions: [(.bowl, 350)], tags: [.fiber]),
        food("ciasto", "ciasto", ["placek", "ciasto drożdżowe"], .sweets, 330, 6, 50, 12, .chunk, 80),
        food("por", "por", [], .vegetables, 61, 1.5, 14, 0.3, .piece, 150, tags: [.fiber]),
        food("kasza-gryczana", "kasza gryczana", ["kasza", "gryczana"], .grains, 92, 3.4, 20, 0.6, .serving, 150,
             portions: [(.glass, 170)], tags: [.magnesium, .iron, .fiber]),
        food("kasza-jaglana", "kasza jaglana", ["jaglana"], .grains, 119, 3.5, 23.7, 1, .serving, 150,
             portions: [(.glass, 170)], tags: [.iron, .magnesium]),
        food("fasola", "fasola", ["fasola biała", "fasola czerwona"], .legumes, 127, 8.7, 22.8, 0.5, .serving, 150,
             portions: [(.can, 240)], tags: [.protein, .iron, .fiber]),
        food("platki-owsiane", "płatki owsiane", ["owsiane"], .grains, 370, 13.5, 58.7, 7, .serving, 50,
             portions: [(.tablespoon, 10), (.glass, 90)], tags: [.fiber, .magnesium, .iron]),
        food("owsianka", "owsianka", ["owsianka na mleku"], .dishes, 110, 4, 17, 3, .bowl, 300, tags: [.fiber]),
        food("borowki", "borówki", ["borówka", "jagody", "borówki amerykańskie"], .fruit, 57, 0.7, 14.5, 0.3,
             .handful, 40, portions: [(.glass, 150)], tags: [.fiber]),
        food("migdaly", "migdały", [], .nuts, 579, 21, 21.6, 49.9, .handful, 30,
             portions: [(.piece, 1.2)], tags: [.magnesium, .protein]),
        food("orzechy-wloskie", "orzechy włoskie", ["orzechy", "orzech włoski"], .nuts, 654, 15.2, 13.7, 65.2,
             .handful, 30, tags: [.omega3, .magnesium]),
        food("miod", "miód", [], .sweets, 304, 0.3, 82, 0, .teaspoon, 8, portions: [(.tablespoon, 20)]),
        food("cukier", "cukier", [], .sweets, 400, 0, 100, 0, .teaspoon, 5, portions: [(.tablespoon, 12)]),
        food("woda", "woda", ["woda mineralna"], .drinks, 0, 0, 0, 0, .glass, 250),
        food("mieso-mielone", "mięso mielone", ["mięso", "mielone"], .meat, 250, 17, 0, 20, .serving, 100,
             tags: [.protein, .iron]),
        food("salata", "sałata", ["sałata masłowa"], .vegetables, 15, 1.4, 2.9, 0.2, .handful, 30),
        food("ogorek", "ogórek", [], .vegetables, 15, 0.7, 3.6, 0.1, .piece, 120),
        food("marchew", "marchew", ["marchewka"], .vegetables, 41, 0.9, 9.6, 0.2, .piece, 80, tags: [.fiber]),
        food("sok-pomaranczowy", "sok pomarańczowy", ["sok"], .drinks, 45, 0.7, 10.4, 0.2, .glass, 250),
        food("tunczyk", "tuńczyk", ["tuńczyk w sosie własnym"], .fish, 116, 26, 0, 1, .can, 120,
             tags: [.protein, .omega3]),
        food("paczek", "pączek", [], .sweets, 414, 6, 46, 23, .piece, 70),
    ]

    private static func food(_ id: String, _ name: String, _ aliases: [String], _ category: FoodCategory,
                             _ kcal: Double, _ protein: Double, _ carbs: Double, _ fat: Double,
                             _ unit: PortionUnit, _ grams: Double,
                             portions: [(PortionUnit, Double)] = [], tags: [NutrientTag] = []) -> FoodItem {
        FoodItem(id: id, name: name, aliases: aliases, category: category,
                 per100: Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat),
                 portions: portions.map { Portion(unit: $0.0, grams: $0.1) },
                 defaultPortion: Portion(unit: unit, grams: grams), tags: tags)
    }
}

enum MealPhrases {
    /// Phrases the web parser got wrong.
    static let webRegressions: [MealPhrase] = [
        typed("trzy jajka, łyżeczka masła, kromka chleba żytniego", [
              parsedAs("jajko", 3, .piece, 165),
              parsedAs("maslo", 1, .teaspoon, 5),
              parsedAs("chleb-zytni", 1, .slice, 40)
             ]),
        typed("0,5 banana", [parsedAs("banan", 0.5, .piece, 60)]),
        typed("1,5 bułki", [parsedAs("bulka", 1.5, .piece, 90)]),
        typed("150 gramów łososia", [parsedAs("losos", 150, nil, 150)]),
        typed("100gr ryżu", [parsedAs("ryz", 100, nil, 100)]),
        typed("1 kg ziemniaków", [parsedAs("ziemniaki", 1000, nil, 1000)]),
        typed("10 dag sera", [parsedAs("ser-zolty", 100, nil, 100)]),
        typed("2 x 50g sera", [parsedAs("ser-zolty", 100, nil, 100)]),
        typed("pół awokado", [parsedAs("awokado", 0.5, .piece, 70)]),
        typed("1/2 awokado", [parsedAs("awokado", 0.5, .piece, 70)]),
        typed("½ awokado", [parsedAs("awokado", 0.5, .piece, 70)]),
        typed("pięć kromek chleba", [parsedAs("chleb", 5, .slice, 175)]),
        typed("pierś z kurczaka", [parsedAs("piers-z-kurczaka", 1, .serving, 150)]),
        typed("kawałek ciasta", [parsedAs("ciasto", 1, .chunk, 80)]),
        typed("porcja zupy", [parsedAs("zupa-jarzynowa", 1, .serving, 300)]),
        typed("deser", [], unknown: ["deser"]),
        typed("zupa pomidorowa", [parsedAs("zupa-pomidorowa", 1, .serving, 300)]),
        typed("jogurtu greckiego", [parsedAs("jogurt-grecki", 1, .package, 150)]),
        typed("łyżka oliwy", [parsedAs("oliwa", 1, .tablespoon, 12)]),
        typed("ząbek czosnku", [parsedAs("czosnek", 1, .clove, 5)]),
        typed("masła", [parsedAs("maslo", 1, .teaspoon, 5)]),
        typed("oliwy", [parsedAs("oliwa", 1, .tablespoon, 12)]),
        typed("mleka", [parsedAs("mleko", 1, .glass, 250)]),
        typed("mlekiem", [parsedAs("mleko", 1, .glass, 250)]),
        typed("jajek", [parsedAs("jajko", 1, .piece, 55)]),
        typed("bułki", [parsedAs("bulka", 1, .piece, 60)]),
        typed("jabłka", [parsedAs("jablko", 1, .piece, 180)]),
        typed("ziemniaków", [parsedAs("ziemniaki", 1, .serving, 200)]),
        typed("migdałów", [parsedAs("migdaly", 1, .handful, 30)]),
        typed("borówkami", [parsedAs("borowki", 1, .handful, 40)]),
        typed("kaszy gryczanej", [parsedAs("kasza-gryczana", 1, .serving, 150)]),
        typed("fasoli", [parsedAs("fasola", 1, .serving, 150)]),
        typed("płatków owsianych", [parsedAs("platki-owsiane", 1, .serving, 50)]),
        typed("kawa z mlekiem", [parsedAs("kawa-z-mlekiem", 1, .mug, 300)]),
    ]

    /// Splitting into fragments.
    static let segmentation: [MealPhrase] = [
        typed("dwa jajka i kawa", [parsedAs("jajko", 2, .piece, 110), parsedAs("kawa", 1, .mug, 250)]),
        typed("jajko\nbanan", [parsedAs("jajko", 1, .piece, 55), parsedAs("banan", 1, .piece, 120)]),
        typed("jajko; banan", [parsedAs("jajko", 1, .piece, 55), parsedAs("banan", 1, .piece, 120)]),
        typed("jajko + banan", [parsedAs("jajko", 1, .piece, 55), parsedAs("banan", 1, .piece, 120)]),
        typed("jajko plus banan", [parsedAs("jajko", 1, .piece, 55), parsedAs("banan", 1, .piece, 120)]),
        typed("jajko oraz banan", [parsedAs("jajko", 1, .piece, 55), parsedAs("banan", 1, .piece, 120)]),
        typed("chleb z masłem", [parsedAs("chleb", 1, .slice, 35), parsedAs("maslo", 1, .teaspoon, 5)]),
        typed("oliwa z oliwek", [parsedAs("oliwa", 1, .tablespoon, 12)]),
        typed("2 łyżki oliwy z oliwek", [parsedAs("oliwa", 2, .tablespoon, 24)]),
        typed("filet z kurczaka", [parsedAs("piers-z-kurczaka", 1, .serving, 150)]),
        typed("100 g piersi z kurczaka", [parsedAs("piers-z-kurczaka", 100, nil, 100)]),
        typed("kurczak z ryżem", [parsedAs("piers-z-kurczaka", 1, .serving, 150), parsedAs("ryz", 1, .serving, 150)]),
        typed("owsianka z borówkami", [parsedAs("owsianka", 1, .bowl, 300), parsedAs("borowki", 1, .handful, 40)]),
        typed("herbata z miodem", [parsedAs("herbata", 1, .mug, 250), parsedAs("miod", 1, .teaspoon, 8)]),
        typed("jogurt grecki z borówkami", [
              parsedAs("jogurt-grecki", 1, .package, 150),
              parsedAs("borowki", 1, .handful, 40)
             ]),
        typed("dwie kromki chleba żytniego z masłem", [
              parsedAs("chleb-zytni", 2, .slice, 80),
              parsedAs("maslo", 1, .teaspoon, 5)
             ]),
        typed("szklanka płatków owsianych z mlekiem", [
              parsedAs("platki-owsiane", 1, .glass, 90),
              parsedAs("mleko", 1, .glass, 250)
             ]),
        typed("zjadłam 2 jajka, kawa z mlekiem i pół banana", [
              parsedAs("jajko", 2, .piece, 110),
              parsedAs("kawa-z-mlekiem", 1, .mug, 300),
              parsedAs("banan", 0.5, .piece, 60)
             ]),
        typed("50g płatków owsianych, szklanka mleka, garść borówek", [
              parsedAs("platki-owsiane", 50, nil, 50),
              parsedAs("mleko", 1, .glass, 250),
              parsedAs("borowki", 1, .handful, 40)
             ]),
        typed("ząbek czosnku i kawałek ciasta", [parsedAs("czosnek", 1, .clove, 5), parsedAs("ciasto", 1, .chunk, 80)]),
        typed("2 ząbki czosnku", [parsedAs("czosnek", 2, .clove, 10)]),
        typed("zupa z ziemniakami", [
              parsedAs("zupa-jarzynowa", 1, .serving, 300),
              parsedAs("ziemniaki", 1, .serving, 200)
             ]),
        typed("złota kasza", [parsedAs("kasza-gryczana", 1, .serving, 150)]),
    ]

    /// Unknown dishes stay whole, in her letters.
    static let unknownDishes: [MealPhrase] = [
        typed("pierogi z mięsem", [], unknown: ["pierogi z mięsem"]),
        typed("2 pierogi z mięsem", [], unknown: ["pierogi z mięsem"]),
        typed("6 pierogów", [], unknown: ["pierogów"]),
        typed("kanapka z szynką", [], unknown: ["kanapka z szynką"]),
        typed("Kanapka z serem i pomidorem", [parsedAs("pomidor", 1, .piece, 150)], unknown: ["Kanapka z serem"]),
        typed("jajecznica z trzech jajek", [parsedAs("jajko", 3, .piece, 165)], unknown: ["jajecznica"]),
        typed("pierogi z 2 jajkami", [parsedAs("jajko", 2, .piece, 110)], unknown: ["pierogi"]),
        typed("kanapka z plasterkiem szynki", [parsedAs("szynka", 1, .thinSlice, 15)], unknown: ["kanapka"]),
        typed("jajko, 2", [parsedAs("jajko", 1, .piece, 55)]),
    ]

    /// Amounts.
    static let amounts: [MealPhrase] = [
        typed("2 jajka", [parsedAs("jajko", 2, .piece, 110)]),
        typed("Trzy JAJKA", [parsedAs("jajko", 3, .piece, 165)]),
        typed("półtorej bułki", [parsedAs("bulka", 1.5, .piece, 90)]),
        typed("ćwierć awokado", [parsedAs("awokado", 0.25, .piece, 35)]),
        typed("¼ awokado", [parsedAs("awokado", 0.25, .piece, 35)]),
        typed("¾ szklanki mleka", [parsedAs("mleko", 0.75, .glass, 187.5)]),
        typed("1 1/2 banana", [parsedAs("banan", 1.5, .piece, 180)]),
        typed("1½ banana", [parsedAs("banan", 1.5, .piece, 180)]),
        typed("dwa i pół jajka", [parsedAs("jajko", 2.5, .piece, 137.5)]),
        typed("parę ziemniaków", [parsedAs("ziemniaki", 2, .piece, 200)]),
        typed("kilka ziemniaków", [parsedAs("ziemniaki", 3, .piece, 300)]),
        typed("pięć bułek", [parsedAs("bulka", 5, .piece, 300)]),
        typed("5 jabłek", [parsedAs("jablko", 5, .piece, 900)]),
        typed("3 banany", [parsedAs("banan", 3, .piece, 360)]),
        typed("banany 3", [parsedAs("banan", 3, .piece, 360)]),
        typed("ser 2", [parsedAs("ser-zolty", 2, .thinSlice, 30)]),
        typed("150 łososia", [parsedAs("losos", 150, nil, 150)]),
        typed("2-3 łyżki jogurtu", [parsedAs("jogurt", 2.5, .tablespoon, 50)]),
        typed("mleko 2%", [parsedAs("mleko", 1, .glass, 250)]),
        typed("jogurt 2-3%", [parsedAs("jogurt", 1, .package, 150)]),
    ]

    /// Units.
    static let units: [MealPhrase] = [
        typed("łosoś 150 g", [parsedAs("losos", 150, nil, 150)]),
        typed("2 razy 50 g sera", [parsedAs("ser-zolty", 100, nil, 100)]),
        typed("2x50g sera", [parsedAs("ser-zolty", 100, nil, 100)]),
        typed("1,5kg ziemniaków", [parsedAs("ziemniaki", 1500, nil, 1500)]),
        typed("pół kilo ziemniaków", [parsedAs("ziemniaki", 500, nil, 500)]),
        typed("10 dkg szynki", [parsedAs("szynka", 100, nil, 100)]),
        typed("250 g twarogu", [parsedAs("twarog", 250, nil, 250)]),
        typed("ok. 100 g ryżu", [parsedAs("ryz", 100, nil, 100)]),
        typed("szklanka mleka", [parsedAs("mleko", 1, .glass, 250)]),
        typed("pół szklanki mleka", [parsedAs("mleko", 0.5, .glass, 125)]),
        typed("pół litra mleka", [parsedAs("mleko", 500, nil, 500)]),
        typed("200 ml mleka", [parsedAs("mleko", 200, nil, 200)]),
        typed("0.5 l mleka", [parsedAs("mleko", 500, nil, 500)]),
        typed("litr wody", [parsedAs("woda", 1000, nil, 1000)]),
        typed("szklanka wody", [parsedAs("woda", 1, .glass, 250)]),
        typed("kubek kawy", [parsedAs("kawa", 1, .mug, 250)]),
        typed("2 kubki herbaty", [parsedAs("herbata", 2, .mug, 500)]),
        typed("garść migdałów", [parsedAs("migdaly", 1, .handful, 30)]),
        typed("garstkę migdałów", [parsedAs("migdaly", 1, .handful, 30)]),
        typed("2 garści migdałów", [parsedAs("migdaly", 2, .handful, 60)]),
        typed("10 sztuk migdałów", [parsedAs("migdaly", 10, .piece, 12)]),
        typed("3 plastry sera", [parsedAs("ser-zolty", 3, .thinSlice, 45)]),
        typed("plasterek szynki", [parsedAs("szynka", 1, .thinSlice, 15)]),
        typed("2 sztuki jajka", [parsedAs("jajko", 2, .piece, 110)]),
        typed("3 szt. jajek", [parsedAs("jajko", 3, .piece, 165)]),
        typed("puszka tuńczyka", [parsedAs("tunczyk", 1, .can, 120)]),
        typed("pół puszki fasoli", [parsedAs("fasola", 0.5, .can, 120)]),
        typed("miska owsianki", [parsedAs("owsianka", 1, .bowl, 300)]),
        typed("2 łyżeczki cukru", [parsedAs("cukier", 2, .teaspoon, 10)]),
        typed("łyżka miodu", [parsedAs("miod", 1, .tablespoon, 20)]),
        typed("łyżka masła orzechowego", [parsedAs("maslo-orzechowe", 1, .tablespoon, 16)]),
        typed("3 łyżki płatków owsianych", [parsedAs("platki-owsiane", 3, .tablespoon, 30)]),
        typed("2 pączki", [parsedAs("paczek", 2, .piece, 140)]),
        typed("2 jajka (ok. 120 g)", [parsedAs("jajko", 2, .piece, 110)]),
        typed("owsianka z garścią płatków owsianych", [
              parsedAs("owsianka", 1, .bowl, 300),
              parsedAs("platki-owsiane", 1, .handful, 30)
             ]),
    ]

    /// Longest alias, Polish endings, never inside a word.
    static let matching: [MealPhrase] = [
        typed("masło orzechowe", [parsedAs("maslo-orzechowe", 1, .tablespoon, 16)]),
        typed("jogurt naturalny", [parsedAs("jogurt", 1, .package, 150)]),
        typed("kasza jaglana", [parsedAs("kasza-jaglana", 1, .serving, 150)]),
        typed("kaszy", [parsedAs("kasza-gryczana", 1, .serving, 150)]),
        typed("2 serki wiejskie", [parsedAs("serek-wiejski", 2, .package, 400)]),
        typed("serki", [parsedAs("serek-wiejski", 1, .package, 200)]),
        typed("sera", [parsedAs("ser-zolty", 1, .thinSlice, 15)]),
        typed("2 ogórki", [parsedAs("ogorek", 2, .piece, 240)]),
        typed("ogórków", [parsedAs("ogorek", 1, .piece, 120)]),
        typed("czosnkiem", [parsedAs("czosnek", 1, .clove, 5)]),
        typed("marchewki", [parsedAs("marchew", 1, .piece, 80)]),
        typed("zupy pomidorowej", [parsedAs("zupa-pomidorowa", 1, .serving, 300)]),
        typed("pomidorówka", [parsedAs("zupa-pomidorowa", 1, .serving, 300)]),
        typed("3 pomidory", [parsedAs("pomidor", 3, .piece, 450)]),
        typed("orzechów włoskich", [parsedAs("orzechy-wloskie", 1, .handful, 30)]),
        typed("szklanka soku pomarańczowego", [parsedAs("sok-pomaranczowy", 1, .glass, 250)]),
        typed("migdał", [parsedAs("migdaly", 1, .handful, 30)]),
        typed("porem", [parsedAs("por", 1, .piece, 150)]),
        typed("kawka", [parsedAs("kawa", 1, .mug, 250)]),
        typed("latte", [parsedAs("kawa-z-mlekiem", 1, .mug, 300)]),
        typed("wędlina", [parsedAs("szynka", 1, .thinSlice, 15)]),
        typed("jajko sadzone na maśle", [parsedAs("jajko", 1, .piece, 55), parsedAs("maslo", 1, .teaspoon, 5)]),
        typed("kawa bez cukru", [parsedAs("kawa", 1, .mug, 250)]),
        typed("kawa bez mleka", [parsedAs("kawa", 1, .mug, 250)]),
        typed("szklanka mleka bez laktozy", [parsedAs("mleko-bez-laktozy", 1, .glass, 250)]),
        typed("sałatka", [parsedAs("salata", 1, .handful, 30)]),
        typed("pora", [], unknown: ["pora"]),
        typed("wódka", [], unknown: ["wódka"]),
        typed("oliwki", [], unknown: ["oliwki"]),
    ]

    /// "na" and "w" split softly, cooking words are dropped, no amount means a serving, more units.
    static let softSplitsAndServings: [MealPhrase] = [
        typed("jajko na twardo", [parsedAs("jajko", 1, .piece, 55)]),
        typed("dwa jajka na miękko", [parsedAs("jajko", 2, .piece, 110)]),
        typed("pół awokado na chlebie", [parsedAs("awokado", 0.5, .piece, 70), parsedAs("chleb", 1, .slice, 35)]),
        typed("na śniadanie owsianka", [parsedAs("owsianka", 1, .bowl, 300)]),
        typed("owsianka na mleku", [parsedAs("owsianka", 1, .bowl, 300)]),
        typed("łosoś w sosie", [parsedAs("losos", 1, .serving, 150)]),
        typed("kurczak z grilla", [parsedAs("piers-z-kurczaka", 1, .serving, 150)]),
        typed("łosoś z piekarnika", [parsedAs("losos", 1, .serving, 150)]),
        typed("2 łyżki oliwy na patelni", [parsedAs("oliwa", 2, .tablespoon, 24)]),
        typed("ziemniaki", [parsedAs("ziemniaki", 1, .serving, 200)]),
        typed("3 ziemniaki", [parsedAs("ziemniaki", 3, .piece, 300)]),
        typed("5 pomidorów", [parsedAs("pomidor", 5, .piece, 750)]),
        typed("talerz zupy pomidorowej", [parsedAs("zupa-pomidorowa", 1, .bowl, 350)]),
        typed("filiżanka kawy", [parsedAs("kawa", 1, .mug, 250)]),
        typed("butelka wody", [parsedAs("woda", 1, .can, 400)]),
        typed("kubeczek jogurtu", [parsedAs("jogurt", 1, .package, 150)]),
        typed("kawa z odrobiną mleka", [parsedAs("kawa", 1, .mug, 250), parsedAs("mleko", 1, .teaspoon, 5)]),
    ]

    /// Typos are guesses.
    static let guesses: [MealPhrase] = [
        typed("bannan", [parsedAs("banan", 1, .piece, 120, guess: true)]),
        typed("kurczk", [parsedAs("piers-z-kurczaka", 1, .serving, 150, guess: true)]),
        typed("awocado", [parsedAs("awokado", 1, .piece, 140, guess: true)]),
        typed("2 jogurtyy greckie", [parsedAs("jogurt-grecki", 2, .package, 300, guess: true)]),
    ]

    static let cleanedNames: [CleanedNameCase] = [
        CleanedNameCase(fragment: "6 pierogów", name: "pierogów"),
        CleanedNameCase(fragment: "2 łyżki sosu sojowego", name: "sosu sojowego"),
        CleanedNameCase(fragment: "pół szklanki kefiru", name: "kefiru"),
        CleanedNameCase(fragment: "  Pierogi z MIĘSEM  ", name: "pierogi z mięsem"),
        CleanedNameCase(fragment: "100g tofu", name: "tofu"),
        CleanedNameCase(fragment: "3 szt. naleśników", name: "naleśników"),
        CleanedNameCase(fragment: "2 x 50 g halloumi", name: "halloumi"),
        CleanedNameCase(fragment: "2 pączki", name: "pączki"),
        CleanedNameCase(fragment: "pierogi (6 szt.)", name: "pierogi"),
        CleanedNameCase(fragment: "mleko 2%", name: "mleko 2%"),
        CleanedNameCase(fragment: "kefir 2-3%", name: "kefir 2-3%"),
        CleanedNameCase(fragment: "ok. 200 ml kefiru", name: "kefiru"),
        CleanedNameCase(fragment: "dwa i pół", name: ""),
        CleanedNameCase(fragment: "kawałek pizzy", name: "pizzy"),
        CleanedNameCase(fragment: "3-4 kopytka", name: "kopytka"),
        CleanedNameCase(fragment: "", name: ""),
    ]
}

@Suite("Meal parser")
struct MealParserTests {
    let parser = MealParser(catalog: FoodCatalog(items: MealFixture.items))

    @Test("Phrases the web parser got wrong", arguments: MealPhrases.webRegressions)
    func webRegressions(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Splitting into fragments", arguments: MealPhrases.segmentation)
    func segmentation(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Unknown dishes stay whole, in her letters", arguments: MealPhrases.unknownDishes)
    func unknownDishes(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Amounts", arguments: MealPhrases.amounts)
    func amounts(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Units", arguments: MealPhrases.units)
    func units(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Longest alias, Polish endings, never inside a word", arguments: MealPhrases.matching)
    func matching(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Soft splits, cooking words and servings", arguments: MealPhrases.softSplitsAndServings)
    func softSplitsAndServings(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test("Typos are guesses", arguments: MealPhrases.guesses)
    func guesses(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test func withoutALatteProductCoffeeWithMilkIsTwoItems() {
        let catalog = FoodCatalog(items: MealFixture.items.filter { $0.id != "kawa-z-mlekiem" })
        expectParse(typed("kawa z mlekiem", [parsedAs("kawa", 1, .mug, 250), parsedAs("mleko", 1, .glass, 250)]),
                    with: MealParser(catalog: catalog))
    }

    @Test(arguments: MealPhrases.cleanedNames)
    func cleanedName(_ expected: CleanedNameCase) {
        #expect(parser.cleanedName(of: expected.fragment) == expected.name)
    }

    @Test func emptyAndWhitespaceInputGiveNothing() {
        for text in ["", "   ", "\n \t ", ", ;", " i  z "] {
            let meal = parser.parse(text)
            #expect(meal.items.isEmpty)
            #expect(meal.unknown.isEmpty)
            #expect(meal.totals == .zero)
        }
    }

    @Test func herProductsWinOverTheCatalog() {
        let cheese = FoodItem(id: "user-ser", name: "ser", category: .dairy,
                              per100: Macros(kcal: 300, protein: 20, carbs: 1, fat: 24),
                              defaultPortion: Portion(unit: .thinSlice, grams: 20))
        let pierogi = FoodItem(id: "user-pierogi", name: "pierogi ruskie", aliases: ["pierogi", "pierogów"],
                               category: .dishes, per100: Macros(kcal: 200, protein: 6, carbs: 30, fat: 6),
                               defaultPortion: Portion(unit: .piece, grams: 40))
        let dish = FoodItem(id: "user-pierogi-z-miesem", name: "pierogi z mięsem", category: .dishes,
                            per100: Macros(kcal: 230, protein: 10, carbs: 28, fat: 8),
                            defaultPortion: Portion(unit: .serving, grams: 250))
        let taught = MealParser(catalog: FoodCatalog(items: MealFixture.items), userFoods: [cheese, pierogi, dish])
        expectParse(typed("10 dag sera", [parsedAs("user-ser", 100, nil, 100)]), with: taught)
        expectParse(typed("ser", [parsedAs("user-ser", 1, .thinSlice, 20)]), with: taught)
        // Her "ser" replaces only that alias: "ser żółty" is still the catalog product.
        expectParse(typed("plaster sera żółtego", [parsedAs("ser-zolty", 1, .thinSlice, 15)]), with: taught)
        expectParse(typed("6 pierogów", [parsedAs("user-pierogi", 6, .piece, 240)]), with: taught)
        // A taught dish with "z" in its name is no longer split.
        expectParse(typed("pierogi z mięsem", [parsedAs("user-pierogi-z-miesem", 1, .serving, 250)]), with: taught)
        expectParse(typed("pierogów z mięsem i kawa",
                          [parsedAs("user-pierogi-z-miesem", 1, .serving, 250), parsedAs("kawa", 1, .mug, 250)]),
                    with: taught)
    }

    @Test func macrosFollowFromTheGramsAndAddUp() throws {
        let meal = parser.parse("trzy jajka, łyżeczka masła, kromka chleba żytniego")
        for parsed in meal.items {
            let fixtureItem = MealFixture.items.first { $0.id == parsed.foodID }
            let food = try #require(fixtureItem)
            #expect(parsed.macros == food.macros(grams: parsed.grams))
        }
        #expect(meal.totals == meal.items.map(\.macros).sum())
        // 165 g of eggs, 5 g of butter, 40 g of rye bread.
        #expect(abs(meal.totals.kcal - (231 + 36.75 + 90)) < 1e-9)
    }

    @Test func eachItemKeepsTheTextAsTyped() {
        let meal = parser.parse("Trzy JAJKA,  kromka chleba żytniego\n2 x 50g sera")
        #expect(meal.items.map(\.text) == ["Trzy JAJKA", "kromka chleba żytniego", "2 x 50g sera"])
        #expect(meal.items.map(\.foodName) == ["jajko", "chleb żytni", "ser żółty"])
    }

    @Test func roundTripsThroughJSON() throws {
        let meal = parser.parse("100 g ryżu, 6 pierogów")
        #expect(meal.unknown == ["pierogów"])
        let data = try JSONEncoder().encode(meal)
        #expect(try JSONDecoder().decode(ParsedMeal.self, from: data) == meal)
    }

    @Test func editDistanceCountsASwapAsOne() {
        #expect(MealParser.editDistance(Array("kurczka"), Array("kurczak")) == 1)
        #expect(MealParser.editDistance(Array("bannan"), Array("banan")) == 1)
        #expect(MealParser.editDistance(Array("deser"), Array("ser")) == 2)
        #expect(MealParser.editDistance(Array(""), Array("ser")) == 3)
    }
}

/// Made-up everyday meal notes against the bundled FoodDB.json. Products, amounts and grams come
/// from the real catalog, so a change in FoodDB.json that changes what she gets shows up here.
enum BuiltInMealPhrases {
    static let everyday: [MealPhrase] = [
        typed("owsianka z bananem i łyżką masła orzechowego", [
              parsedAs("owsianka", 1, .bowl, 300),
              parsedAs("banan", 1, .piece, 120),
              parsedAs("maslo-orzechowe", 1, .tablespoon, 16)
             ]),
        typed("2 kromki chleba żytniego z twarożkiem i rzodkiewką", [
              parsedAs("chleb-zytni", 2, .slice, 80),
              parsedAs("twarog", 1, .serving, 100),
              parsedAs("rzodkiewka", 1, .serving, 50)
             ]),
        typed("zupa pomidorowa z ryżem", [parsedAs("zupa-pomidorowa", 1, .serving, 350)]),
        typed("jajecznica z trzech jajek i pomidor", [
              parsedAs("jajko", 3, .piece, 165),
              parsedAs("pomidor", 1, .piece, 130)
             ]),
        typed("jajecznica z 3 jaj na maśle", [parsedAs("jajko", 3, .piece, 165), parsedAs("maslo", 1, .teaspoon, 5)]),
        typed("kawa z mlekiem", [parsedAs("kawa-z-mlekiem", 1, .mug, 250)]),
        typed("pół awokado na toście", [
              parsedAs("awokado", 0.5, .piece, 70),
              parsedAs("chleb-tostowy", 1, .slice, 25)
             ]),
        typed("200 g kurczaka, kasza gryczana i surówka", [
              parsedAs("piers-z-kurczaka", 200, nil, 200),
              parsedAs("kasza-gryczana", 1, .serving, 150),
              parsedAs("surowka", 1, .serving, 120)
             ]),
        typed("jogurt grecki z borówkami i garścią orzechów", [
              parsedAs("jogurt-grecki", 1, .package, 150),
              parsedAs("borowki", 1, .serving, 100),
              parsedAs("orzechy", 1, .handful, 30)
             ]),
        typed("pierogi ruskie 6 sztuk", [parsedAs("pierogi-ruskie", 6, .piece, 270)]),
        typed("pierogi z mięsem", [parsedAs("pierogi-z-miesem", 1, .serving, 270)]),
        typed("naleśniki z twarogiem", [parsedAs("nalesniki-z-serem", 1, .serving, 200)]),
        typed("sałatka z tuńczykiem", [parsedAs("salatka", 1, .serving, 200), parsedAs("tunczyk", 1, .can, 120)]),
        typed("sałatka z pomidorów i ogórka", [
              parsedAs("salatka", 1, .serving, 200),
              parsedAs("pomidor", 1, .piece, 130),
              parsedAs("ogorek", 1, .piece, 150)
             ]),
        typed("łosoś pieczony 150g z batatami", [parsedAs("losos", 150, nil, 150), parsedAs("batat", 1, .serving, 150)]),
        typed("kurczak w sosie pomidorowym z ryżem", [
              parsedAs("piers-z-kurczaka", 1, .serving, 150),
              parsedAs("sos-pomidorowy", 1, .serving, 120),
              parsedAs("ryz", 1, .serving, 150)
             ]),
        typed("kotlet schabowy z ziemniakami i mizerią", [
              parsedAs("kotlet-schabowy", 1, .piece, 150),
              parsedAs("ziemniaki", 1, .serving, 200),
              parsedAs("mizeria", 1, .serving, 150)
             ]),
        typed("barszcz czerwony z uszkami", [parsedAs("barszcz", 1, .serving, 300), parsedAs("uszka", 1, .serving, 80)]),
        typed("talerz zupy ogórkowej", [parsedAs("zupa-ogorkowa", 1, .bowl, 350)]),
        typed("pizza 2 kawałki", [parsedAs("pizza", 2, .chunk, 220)]),
        typed("kiełbasa z grilla z musztardą", [
              parsedAs("kielbasa", 1, .piece, 100),
              parsedAs("musztarda", 1, .teaspoon, 5)
             ]),
        typed("kanapka z szynką i serem", [
              parsedAs("chleb", 1, .slice, 35),
              parsedAs("szynka", 1, .serving, 30),
              parsedAs("ser-zolty", 1, .serving, 30)
             ]),
        typed("jajko na miękko", [parsedAs("jajko", 1, .piece, 55)]),
        typed("10 migdałów", [parsedAs("migdaly", 10, .piece, 12)]),
        typed("kawałek gorzkiej czekolady", [parsedAs("czekolada-gorzka", 1, .chunk, 10)]),
        typed("herbata z cytryną", [parsedAs("herbata", 1, .mug, 250), parsedAs("cytryna", 1, .serving, 10)]),
        typed("kieliszek wina", [parsedAs("wino", 1, .glass, 150)]),
        typed("piwo bez alkoholu", [parsedAs("piwo-bezalkoholowe", 1, .can, 500)]),
        // Folded letters must not pick another product: "mąki" is flour (not "maki" sushi), "soli" is salt.
        typed("2 łyżki mąki", [parsedAs("maka", 2, .tablespoon, 20)]),
        typed("szczypta soli", [parsedAs("sol", 1, .teaspoon, 1)]),
        // An unknown dish keeps what it is made of, to be taught once.
        typed("koktajl z banana i szpinaku", [parsedAs("szpinak", 1, .serving, 100)], unknown: ["koktajl z banana"]),
    ]
}

/// The parser's key for a name: the letter runs of the normalized text ("Pierś z kurczaka" → "piers z kurczaka").
private func aliasKey(_ phrase: String) -> String {
    var words: [String] = []
    var current = ""
    for character in FoodText.normalized(phrase) {
        if character.isLetter {
            current.append(character)
        } else if !current.isEmpty {
            words.append(current)
            current = ""
        }
    }
    if !current.isEmpty { words.append(current) }
    return words.joined(separator: " ")
}

@Suite("Meal parser with the built-in catalog")
struct MealParserBuiltInCatalogTests {
    let parser = MealParser(catalog: .builtIn)

    @Test("Everyday meals", arguments: BuiltInMealPhrases.everyday)
    func everydayMeals(_ expected: MealPhrase) {
        expectParse(expected, with: parser)
    }

    @Test func theCatalogIsBundled() {
        let ids = FoodCatalog.builtIn.items.map(\.id)
        #expect(ids.count > 300)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyNameBelongsToOneProductAndHasThreeLetters() {
        var owner: [String: String] = [:]
        for item in FoodCatalog.builtIn.items {
            for phrase in [item.name] + item.aliases {
                let key = aliasKey(phrase)
                let letters = key.filter { $0.isLetter }.count
                #expect(letters >= 3, "\(item.id): \(phrase)")
                let previous = owner[key] ?? item.id
                #expect(previous == item.id, "\(phrase): \(previous) and \(item.id)")
                owner[key] = item.id
            }
        }
    }

    @Test func energyAgreesWithTheMacros() {
        // Alcohol has energy of its own (7 kcal per gram), which 4 / 4 / 9 doesn't count.
        let alcohol: Set<String> = ["wino", "piwo", "wodka", "drink"]
        for item in FoodCatalog.builtIn.items {
            let macros = item.per100
            if alcohol.contains(item.id) {
                #expect(macros.kcal >= macros.kcalFromMacros, "\(item.id)")
            } else {
                let tolerance = max(15, 0.15 * macros.kcal)
                #expect(abs(macros.kcal - macros.kcalFromMacros) <= tolerance, "\(item.id)")
            }
        }
    }

    @Test func everyPortionHasAWeight() {
        for item in FoodCatalog.builtIn.items {
            let weights = [item.defaultPortion.grams] + item.portions.map(\.grams)
            let positive = weights.allSatisfy { $0 > 0 }
            #expect(positive, "\(item.id)")
        }
    }
}
