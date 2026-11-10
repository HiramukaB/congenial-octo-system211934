/// One product recognised in a meal text.
public struct ParsedItem: Codable, Sendable, Hashable {
    /// The fragment as she typed it, trimmed: "2 łyżki oliwy".
    public var text: String
    public var foodID: String
    public var foodName: String
    /// How many `unit`s – or grams (millilitres) when `unit` is nil.
    public var amount: Double
    /// nil when she gave grams or millilitres.
    public var unit: PortionUnit?
    /// The resolved weight; 1 ml counts as 1 g.
    public var grams: Double
    public var macros: Macros
    /// Matched despite a typo ("bannan") – worth a question mark in the UI.
    public var isGuess: Bool

    public init(text: String, foodID: String, foodName: String, amount: Double, unit: PortionUnit?,
                grams: Double, macros: Macros, isGuess: Bool = false) {
        self.text = text
        self.foodID = foodID
        self.foodName = foodName
        self.amount = amount
        self.unit = unit
        self.grams = grams
        self.macros = macros
        self.isGuess = isGuess
    }
}

/// What a meal text turned into.
public struct ParsedMeal: Codable, Sendable, Hashable {
    public var items: [ParsedItem]
    /// Fragments that matched nothing, without amounts and units, in her own letters: "pierogi z mięsem".
    public var unknown: [String]
    /// The sum of the items, unrounded (rounding is for the UI).
    public var totals: Macros

    /// `totals` defaults to the sum of `items`.
    public init(items: [ParsedItem] = [], unknown: [String] = [], totals: Macros? = nil) {
        self.items = items
        self.unknown = unknown
        self.totals = totals ?? items.map(\.macros).sum()
    }
}

/// Turns free Polish text ("trzy jajka, łyżeczka masła, kromka chleba żytniego") into products,
/// amounts and macros. Deterministic: the numbers always come from the catalog.
///
/// 1. The text is split on , ; + ! ? … new lines and full stops (not the one of "szt." or "ok."), then on
///    the words i, oraz, plus, a and z/ze – except inside a known name ("pierś z kurczaka") or an amount
///    ("dwa i pół"). After an unknown dish, "z …" stays with it: "pierogi z mięsem" is one dish to teach;
///    a smoothie is only what went into it ("koktajl z banana i szpinaku").
///    "na" and "w" split softly: after them only a food counts ("na maśle", "w sosie pomidorowym"), the
///    rest is how or where it was eaten ("na twardo", "w pracy"). Foods typed without a comma are cut
///    apart too ("kurczak ryż brokuł", "kurczak z ryżem do tego surówka"), but never a name of two words
///    ("jogurt grecki"). After "i", a food in the form it takes after "z" carries that list on: in
///    "kawa z cukrem i mlekiem" the milk went into the coffee; so it did in "kawa z cukrem, z mlekiem".
/// 2. In each fragment the amount (2, 0,5, 1/2, ½, pół, trzy, trzy czwarte, 2 x 50) and the unit (g, dag,
///    kg, ml, l, łyżka, kromka, garść, talerz …) are read; the remaining words are the name. With no
///    amount at all she means one serving ("pierogi"), or one piece of a singular ("pieróg"); a count
///    means pieces ("6 pierogów"). A count written after what came with a dish counts the dish
///    ("pierogi ruskie z cebulką 10 sztuk"). A clock time ("8:30", "o 8", "8 rano"), energy ("250 kcal"),
///    the protein on a label ("20 g białka") or a number of the name ("pizza 4 sery") is no amount.
/// 3. The name is matched against every alias: the alias with the most words wins, then the
///    earliest, then the closest form, then the longest. Words match exactly or through a Polish
///    ending (masło → masła, czosnek → czosnku, jajko → jajek), never inside another word
///    (deser ≠ ser, kawałek ≠ kawa). Only when nothing matches, a typo is allowed (a guess).
public struct MealParser: Sendable {
    private let aliases: [MealAlias]
    /// Multi-word aliases with a joining word inside ("pierś z kurczaka"), which must not be split.
    private let joiningAliases: [MealAlias]
    /// All aliases of two or more words ("sos pomidorowy").
    private let multiWordAliases: [MealAlias]
    /// Adjectives that end a two-word name ("mleko owsiane", "kasza jaglana"): in any form they describe
    /// the food before them ("kawa z mlekiem owsianym"), they are no second food.
    private let modifiers: [MealAliasWord]

    /// Products she taught the app (`userFoods`) win over catalog products with the same alias.
    public init(catalog: FoodCatalog, userFoods: [FoodItem] = []) {
        var keys: [String] = []
        var entries: [String: (words: [String], item: FoodItem, isUserFood: Bool)] = [:]
        var productNames = Set<String>()
        let sources: [(items: [FoodItem], isUserFood: Bool)] = [(catalog.items, false), (userFoods, true)]
        for source in sources {
            for item in source.items {
                productNames.insert(MealText.words(of: item.name).joined(separator: " "))
                for phrase in [item.name] + item.aliases {
                    let words = MealText.words(of: phrase)
                    if words.isEmpty { continue }
                    let key = words.joined(separator: " ")
                    if let existing = entries[key] {
                        if source.isUserFood && !existing.isUserFood {
                            entries[key] = (words, item, true)
                        }
                    } else {
                        keys.append(key)
                        entries[key] = (words, item, source.isUserFood)
                    }
                }
            }
        }
        var list: [MealAlias] = []
        // One-word names: an adjective that is one ("pomidorowa") names a dish, it does not only describe one.
        let singleWords = Set(keys.filter { entries[$0]?.words.count == 1 })
        for (order, key) in keys.enumerated() {
            if let entry = entries[key] {
                let isSingular = (entry.item.singular ?? []).contains { phrase in
                    MealText.words(of: phrase).joined(separator: " ") == key
                }
                list.append(MealAlias(words: entry.words, item: entry.item, order: order, isSingular: isSingular,
                                      singleWords: singleWords))
            }
        }
        aliases = list
        joiningAliases = list.filter { alias in
            alias.words.count > 1 && alias.words.contains { MealWords.isProtectable($0.text) }
        }
        multiWordAliases = list.filter { $0.words.count > 1 }
        var seen = Set<String>()
        var describing: [MealAliasWord] = []
        for alias in list where alias.words.count == 2 {
            if alias.words.contains(where: { MealWords.isProtectable($0.text) }) { continue }
            let word = alias.words[1]
            if MealWords.isAdjective(word.text) && !productNames.contains(word.text) && !seen.contains(word.text) {
                seen.insert(word.text)
                describing.append(word)
            }
        }
        modifiers = describing
    }

    public func parse(_ text: String) -> ParsedMeal {
        let meal = MealText(text)
        var items: [ParsedItem] = []
        var unknown: [String] = []
        var start = 0
        // "kawa z cukrem, z mlekiem": the dish the next fragment may go on with.
        var carried: MealPreviousItem?
        for k in 0...meal.tokens.count {
            if k == meal.tokens.count || meal.tokens[k].kind == .separator {
                if start < k {
                    carried = parseChunk(meal, start..<k, carrying: carried, items: &items, unknown: &unknown)
                }
                start = k + 1
            }
        }
        return ParsedMeal(items: items, unknown: unknown)
    }

    /// The fragment without amounts and units, lowercased – the name to pre-fill when she teaches
    /// an unknown product: "6 pierogów" → "pierogów", "2 łyżki sosu sojowego" → "sosu sojowego".
    public func cleanedName(of fragment: String) -> String {
        let meal = MealText(fragment)
        return meal.cleaned(0..<meal.tokens.count).lowercased()
    }

    // MARK: - Segments

    /// Returns the fragment's dish, which the next fragment may go on with.
    private func parseChunk(_ meal: MealText, _ chunk: Range<Int>, carrying carried: MealPreviousItem?,
                            items: inout [ParsedItem], unknown: inout [String]) -> MealPreviousItem? {
        let protected = protectedTokens(meal, chunk)
        // One dish and what came with it, which a group after "i" may carry on: "kawa z cukrem i mlekiem".
        // The item made from the part before.
        var previous: MealPreviousItem?
        // The dish (the first item), and whether a later part showed it is only the name of a dish.
        var firstItem: MealPreviousItem?
        // "kawa z cukrem, z mlekiem": a fragment may go on with the dish of the one before.
        if let carried, goesOn(meal, chunk) {
            firstItem = carried
        }
        var dropsFirst = false
        // Whether something came with the dish after "z": only then can a group after "i" carry the list on.
        var withList = false
        // "kawa bez cukru i mleka": the group before ended under "bez".
        var negatedBefore = false
        for group in meal.split(chunk, at: MealWords.joining, keeping: protected) {
            let parts = separated(meal, meal.split(group, at: MealWords.splitting, keeping: protected), protected)
            // "kawa bez cukru i z mlekiem": a group that starts with "z" carries the dish on too.
            let continues = firstItem != nil
                && (withList || meal.isWord(group.lowerBound, group.upperBound, in: MealWords.withWords))
                && MealParser.carriesOn(meal, group)
            if !continues {
                if dropsFirst, let earliest = firstItem {
                    items.remove(at: earliest.index)
                }
                previous = nil
                firstItem = nil
                dropsFirst = false
                withList = false
            }
            // Whether this group was only an add-in left out under the "bez" before it.
            var leftOut = false
            var i = 0
            while i < parts.count {
                let part = parts[i]
                // After "na" and "w" only a food counts, and no typo: "na miękko" is not a guess at a food.
                let soft = MealParser.isSoft(meal, parts, i)
                // Split off at z, ze, na or w, or the first part of a list carried on after "i".
                let added = (i > 0 && MealParser.follows(meal, part, MealWords.splitting)) || (i == 0 && continues)
                if i > 0 && MealParser.follows(meal, part, MealWords.withWords) {
                    withList = true
                }
                let head = analyze(meal, part, protected, allowingTypos: !soft)
                // "kurczak z grilla 400 g", "jajka na twardo 3 sztuki": the amount belongs to the food before.
                if head.match == nil && (head.quantity != nil || head.unit != nil)
                    && MealParser.saysHowCooked(meal, part) {
                    if let earlier = previous, earlier.analysis.quantity == nil && earlier.analysis.unit == nil {
                        var merged = earlier.analysis
                        merged.quantity = head.quantity
                        merged.unit = head.unit
                        merged.quantityIsDecimal = head.quantityIsDecimal
                        merged.quantityFollowsName = true
                        items[earlier.index] = makeItem(meal, earlier.part.lowerBound..<part.upperBound, merged,
                                                        earlier.match)
                    }
                    previous = nil
                    i += 1
                    continue
                }
                // "pizza z szynką na pół z mężem": shared, so half of the dish and of what came with it
                // ("pół na pół" and "przekrojone na pół" are no share).
                if soft, head.match == nil, head.nameTokens.isEmpty, head.unit == nil,
                   let share = head.quantity, share > 0, share < 1, let dish = firstItem,
                   !MealParser.isNoShare(meal, part) {
                    for index in items.indices where index >= dish.index {
                        guard let food = product(items[index].foodID) else { continue }
                        items[index].amount *= share
                        items[index].grams *= share
                        items[index].macros = food.macros(grams: items[index].grams)
                    }
                    previous = nil
                    i += 1
                    continue
                }
                if head.nameTokens.isEmpty {
                    i += 1
                    continue
                }
                if let match = head.match {
                    var analysis = head
                    // "kawa bez cukru i mleka": an add-in after "bez … i" was left out too.
                    if negatedBefore, parts.count == 1, analysis.quantity == nil, analysis.unit == nil,
                       match.quality == 2, MealWords.addIns.contains(match.alias.item.id) {
                        leftOut = true
                        i += 1
                        continue
                    }
                    // "pierś z kurczka", "pomidorwa z ryzem": a typo in the dish's own name, not a second food.
                    if let earliest = firstItem, match.quality == 1 || earliest.match.quality == 1,
                       MealParser.follows(meal, part, MealWords.withWords),
                       continuesName(meal, head, of: earliest) {
                        i += 1
                        continue
                    }
                    // "pierogi ruskie z cebulką 10 sztuk", "jajka na maśle 2 sztuki": the count is the dish's.
                    if let earliest = firstItem, added,
                       MealParser.countsTheDish(head, earliest, besides: match.alias.item) {
                        let dish = MealParser.counted(earliest, by: head)
                        items[dish.index] = makeItem(meal, dish.part.lowerBound..<part.upperBound, dish.analysis,
                                                     dish.match)
                        if let earlier = previous, earlier.index == dish.index {
                            previous = dish
                        }
                        firstItem = dish
                        analysis.quantity = nil
                        analysis.unit = nil
                        analysis.quantityIsDecimal = false
                        analysis.quantityFollowsName = false
                    }
                    // "mleko do kawy": a splash, not a glass.
                    if analysis.quantity == nil && analysis.unit == nil, MealWords.milks.contains(match.alias.item.id),
                       part.contains(where: { k in
                           meal.isWord(k, part.upperBound, "do")
                               && meal.isWord(k + 1, part.upperBound, in: MealWords.forDrinks)
                       }) {
                        var splash = analysis
                        splash.quantity = MealWords.splashMillilitres
                        splash.unit = .grams(1)
                        items.append(makeItem(meal, part, splash, match))
                        previous = nil
                        i += 1
                        continue
                    }
                    // Milk with no amount of its own, after the drink or dish it went into.
                    if let dish = firstItem, analysis.quantity == nil && analysis.unit == nil,
                       MealWords.milks.contains(match.alias.item.id) {
                        let dishID = items[dish.index].foodID
                        // "latte na mleku owsianym", "owsianka z bananem i mlekiem": the milk is already in it.
                        if MealWords.milkDishes.contains(dishID) {
                            previous = nil
                            i += 1
                            continue
                        }
                        // "kawa z mlekiem", "kawa z cukrem i mlekiem": a splash, not a glass.
                        if MealWords.splashDrinks.contains(dishID) {
                            var splash = analysis
                            splash.quantity = MealWords.splashMillilitres
                            splash.unit = .grams(1)
                            items.append(makeItem(meal, part, splash, match))
                            previous = nil
                            i += 1
                            continue
                        }
                    }
                    // "jajecznica na łyżce masła z 3 jajek": counted by its eggs, the jajecznica is only their name.
                    if let earliest = firstItem, !dropsFirst, analysis.quantity != nil,
                       MealParser.follows(meal, part, MealWords.withWords),
                       isMadeOf(match.alias.item, named: MealParser.firstWord(meal, of: earliest),
                                allowingTypos: earliest.match.quality == 1) {
                        dropsFirst = true
                    }
                    items.append(makeItem(meal, part, analysis, match))
                    previous = MealPreviousItem(index: items.count - 1, part: part, analysis: analysis, match: match)
                    if firstItem == nil { firstItem = previous }
                    // "pierogi z mięsem i cebulką": a name with "z" in it starts the list too.
                    if match.alias.words.contains(where: { MealWords.withWords.contains($0.text) }) {
                        withList = true
                    }
                    i += 1
                    continue
                }
                // "na twardo", "na śniadanie", "w pracy": how or where, not something to teach.
                if soft {
                    i += 1
                    continue
                }
                // "koktajl z banana i szpinaku": a smoothie is what went into it, counted food by food.
                if head.nameTokens.count == 1, MealWords.containers.contains(meal.tokens[head.nameTokens[0]].norm),
                   i + 1 < parts.count, MealParser.follows(meal, parts[i + 1], MealWords.withWords) {
                    previous = nil
                    i += 1
                    continue
                }
                // "pączek z lukrem 2 sztuki": a count after something unknown that came with the dish.
                if let earliest = firstItem, added, MealParser.countsTheDish(head, earliest, besides: nil) {
                    let dish = MealParser.counted(earliest, by: head)
                    items[dish.index] = makeItem(meal, dish.part.lowerBound..<part.upperBound, dish.analysis,
                                                 dish.match)
                    firstItem = dish
                }
                // An unknown head keeps what is said about it: "pierogi z mięsem" is one dish to teach,
                // not pierogi plus a portion of meat. A part with its own amount or unit is a food of its own,
                // and so is a food typed after it without a comma.
                var last = part.upperBound
                var j = i + 1
                while j < parts.count {
                    if MealParser.isSoft(meal, parts, j) || !MealParser.follows(meal, parts[j], MealWords.splitting) {
                        break
                    }
                    let following = analyze(meal, parts[j], protected, allowingTypos: true)
                    if following.quantity != nil || following.unit != nil {
                        // "pyzy z mięsem 4 sztuki", "pyzy z mięsem 1 porcja": a count after what came with an unknown
                        // dish counts the dish, unless that is counted in pieces itself ("… z jajkami 2 sztuki").
                        let isCount = following.unit == nil || following.unit == MealUnit.portion(.piece)
                            || following.unit == MealUnit.portion(.serving)
                        let countsDish = following.quantity != nil && following.quantityFollowsName && isCount
                            && following.match?.alias.item.defaultPortion.unit != PortionUnit.piece
                        if !countsDish { break }
                    }
                    if !following.nameTokens.isEmpty { last = parts[j].upperBound }
                    j += 1
                }
                let name = meal.cleaned(part.lowerBound..<last)
                if name.filter({ $0.isLetter }).count >= 2 {
                    unknown.append(name)
                }
                previous = nil
                i = j
            }
            // "kawa bez cukru i mleka": the group ended under "bez".
            if let last = parts.last {
                negatedBefore = leftOut || last.contains(where: { k in
                    meal.isWord(k, last.upperBound, MealWords.negation) && !protected.contains(k)
                })
            }
        }
        if dropsFirst, let earliest = firstItem {
            items.remove(at: earliest.index)
            return nil
        }
        return firstItem
    }

    /// Whether a fragment goes on with the dish of the one before: it starts with "z" and an amount ("jajecznica,
    /// z 3 jajek") or a food in the form it takes after "z" ("kawa z cukrem, z mlekiem"), not with a name or
    /// a dish of its own ("Z Kasią kawa", "z pizza"). After someone only a share goes on ("pizza. Z mężem na pół").
    private func goesOn(_ meal: MealText, _ chunk: Range<Int>) -> Bool {
        guard meal.isWord(chunk.lowerBound, chunk.upperBound, in: MealWords.withWords) else { return false }
        var withSomeone = false
        for k in (chunk.lowerBound + 1)..<chunk.upperBound {
            let token = meal.tokens[k]
            if token.isQuantity { return !withSomeone }
            guard token.kind == .word else { continue }
            let word = token.norm
            if withSomeone {
                return word == "na" && k + 1 < chunk.upperBound && meal.tokens[k + 1].isQuantity
            }
            if MealWords.units[word] != nil { return true }
            if word == "ok" || word == "okolo" { continue }
            // "Z mężem", "Z Kasią", "Z Oliwią": someone, not something that came with the dish.
            if MealWords.filler.contains(word) || meal.chars[token.start].isUppercase {
                withSomeone = true
                continue
            }
            let instrumental = MealWords.instrumentalLetters.contains(meal.chars[token.end - 1])
                || MealWords.instrumentalEndings.contains(where: { word.hasSuffix($0) })
            return instrumental && bestMatch([word], allowingTypos: false) != nil
        }
        return false
    }

    /// Whether a group after "i" carries on what came with the dish: "kawa z cukrem i mlekiem" (a food in the
    /// form it takes after "z"), "kurczak z ryżem i z surówką".
    private static func carriesOn(_ meal: MealText, _ group: Range<Int>) -> Bool {
        if meal.isWord(group.lowerBound, group.upperBound, in: MealWords.withWords) { return true }
        for k in group where meal.tokens[k].kind == .word {
            let word = meal.tokens[k].norm
            if MealWords.numbers[word] != nil || MealWords.filler.contains(word) { continue }
            return MealWords.instrumentalLetters.contains(meal.chars[meal.tokens[k].end - 1])
                || MealWords.instrumentalEndings.contains(where: { word.hasSuffix($0) })
        }
        return false
    }

    /// Whether a count written after what came with the dish counts the dish: "pierogi z cebulką 10 sztuk",
    /// "chleb z masłem 2 kromki", "pączek z lukrem 2 sztuki" – but not "barszcz z uszkami 12 sztuk",
    /// "kurczak z ziemniakami 3 sztuki" or "jogurt grecki z granolą 2 łyżki". `food` is what came with it.
    private static func countsTheDish(_ analysis: MealAnalysis, _ dish: MealPreviousItem,
                                      besides food: FoodItem?) -> Bool {
        guard analysis.quantity != nil, analysis.quantityFollowsName,
              dish.analysis.quantity == nil, dish.analysis.unit == nil else { return false }
        let item = dish.match.alias.item
        switch analysis.unit {
        case nil, .portion(.piece)?:
            if MealWords.countedDishes.contains(item.defaultPortion.unit) { return true }
            if let food, food.defaultPortion.unit == .piece { return false }
            return lists(item, .piece)
        case .portion(let unit)?:
            if let food, lists(food, unit) { return false }
            return lists(item, unit)
        case .grams?:
            return false
        }
    }

    /// Whether the product has a portion of this unit of its own.
    private static func lists(_ item: FoodItem, _ unit: PortionUnit) -> Bool {
        item.defaultPortion.unit == unit || item.portions.contains { $0.unit == unit }
    }

    /// The dish with the count written after what came with it.
    private static func counted(_ dish: MealPreviousItem, by analysis: MealAnalysis) -> MealPreviousItem {
        var merged = dish.analysis
        merged.quantity = analysis.quantity
        merged.unit = analysis.unit
        merged.quantityIsDecimal = analysis.quantityIsDecimal
        merged.quantityFollowsName = true
        return MealPreviousItem(index: dish.index, part: dish.part, analysis: merged, match: dish.match)
    }

    /// Whether the product has a name "<word> z …" ("jajecznica z jajek" of jajko): the dish that `word`
    /// names is made of it. A typo is allowed when the dish itself was a guess ("jajecznca z 3 jajek").
    private func isMadeOf(_ item: FoodItem, named word: String, allowingTypos: Bool) -> Bool {
        joiningAliases.contains { alias in
            alias.item.id == item.id && alias.words.count >= 3 && MealWords.withWords.contains(alias.words[1].text)
                && MealParser.quality(of: word, as: alias.words[0], allowingTypos: allowingTypos) > 0
        }
    }

    /// Whether the part is the rest of the dish's own name "<dish> z …" with a typo in one of them:
    /// "pierś z kurczka" and "pomidorwa z ryzem" are one dish, not a second food.
    private func continuesName(_ meal: MealText, _ analysis: MealAnalysis, of dish: MealPreviousItem) -> Bool {
        guard let match = analysis.match else { return false }
        let word = meal.tokens[analysis.nameTokens[match.position]].norm
        let first = MealParser.firstWord(meal, of: dish)
        let typos = dish.match.quality == 1
        return joiningAliases.contains { alias in
            alias.item.id == dish.match.alias.item.id && alias.words.count >= 3
                && MealWords.withWords.contains(alias.words[1].text)
                && MealParser.quality(of: first, as: alias.words[0], allowingTypos: typos) > 0
                && MealParser.quality(of: word, as: alias.words[2], allowingTypos: true) > 0
        }
    }

    /// The first word of the name an earlier item was matched by: "jajecznica".
    private static func firstWord(_ meal: MealText, of earlier: MealPreviousItem) -> String {
        meal.tokens[earlier.analysis.nameTokens[earlier.match.position]].norm
    }

    /// Whether the word before "na" makes "na pół" no share: "pół na pół" is half and half,
    /// "przekrojone na pół" only cut.
    private static func isNoShare(_ meal: MealText, _ part: Range<Int>) -> Bool {
        guard part.lowerBound >= 2 else { return false }
        let k = part.lowerBound - 2
        return meal.isWord(k, part.lowerBound, "pol")
            || meal.isWord(k, part.lowerBound, startingWith: MealWords.cutStems)
    }

    /// Whether part `index` was split off at "na" or "w".
    private static func isSoft(_ meal: MealText, _ parts: [Range<Int>], _ index: Int) -> Bool {
        index > 0 && follows(meal, parts[index], MealWords.softWords)
    }

    /// Whether the word right before `part` is one of `words`: the part was split off there.
    private static func follows(_ meal: MealText, _ part: Range<Int>, _ words: Set<String>) -> Bool {
        part.lowerBound > 0 && meal.isWord(part.lowerBound - 1, meal.tokens.count, in: words)
    }

    /// Whether the part only says how it was cooked, maybe with an amount: "grilla 250 g", "twardo 3 sztuki".
    private static func saysHowCooked(_ meal: MealText, _ part: Range<Int>) -> Bool {
        var cooked = false
        for k in part where meal.tokens[k].kind == .word {
            let word = meal.tokens[k].norm
            if MealWords.preparation.contains(word) || MealWords.manner.contains(word) {
                cooked = true
            } else if MealWords.numbers[word] == nil && MealWords.units[word] == nil
                        && !MealWords.filler.contains(word) && !MealWords.times.contains(word) {
                return false
            }
        }
        return cooked
    }

    /// Joining words that belong to a known name ("pierś z kurczaka") or to an amount ("dwa i pół").
    private func protectedTokens(_ meal: MealText, _ chunk: Range<Int>) -> Set<Int> {
        var protected = Set<Int>()
        // Amounts, units and cooking words never break a name: "jajecznica z trzech jajek".
        let words = chunk.filter { meal.tokens[$0].kind == .word && !MealWords.isNeverName(meal.tokens[$0].norm) }
        for alias in joiningAliases {
            let count = alias.words.count
            guard words.count >= count else { continue }
            for s in 0...(words.count - count) {
                if !aliasMatches(meal, words, at: s, alias) { continue }
                if startsInsideAnotherName(meal, words, at: s, alias) { continue }
                for t in 0..<count where MealWords.isProtectable(alias.words[t].text) {
                    // "owsianka z łyżeczką kakao": a unit right after it measures the next food.
                    if !meal.isUnit(words[s + t] + 1, chunk.upperBound) {
                        protected.insert(words[s + t])
                    }
                }
            }
        }
        if chunk.count >= 3 {
            for k in (chunk.lowerBound + 1)..<(chunk.upperBound - 1) {
                if meal.isWord(k, chunk.upperBound, "i") && meal.isWord(k + 1, chunk.upperBound, "pol")
                    && meal.tokens[k - 1].isQuantity {
                    protected.insert(k)
                }
            }
        }
        return protected
    }

    /// Whether `alias` matches the words from `s` on, exactly or through an ending (no typos).
    /// The caller makes sure all its words fit.
    private func aliasMatches(_ meal: MealText, _ words: [Int], at s: Int, _ alias: MealAlias) -> Bool {
        for t in 0..<alias.words.count {
            if MealParser.quality(of: meal.tokens[words[s + t]].norm, as: alias.words[t], allowingTypos: false) == 0 {
                return false
            }
        }
        return true
    }

    /// Whether a name found at word `s` begins inside another product's name: in "sosie pomidorowym
    /// z ryżem" the words "pomidorowym z ryżem" are the sauce and the rice, not the soup "pomidorowa z ryżem".
    private func startsInsideAnotherName(_ meal: MealText, _ words: [Int], at s: Int, _ alias: MealAlias) -> Bool {
        guard s > 0 else { return false }
        for other in multiWordAliases where other.item.id != alias.item.id {
            let count = other.words.count
            // `other` would cover the word before the name and its first word.
            for t in 1..<count {
                let begin = s - t
                if begin >= 0 && begin + count <= words.count && aliasMatches(meal, words, at: begin, other) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Foods typed without commas

    /// The parts with each food typed without a comma cut off on its own: "kurczak ryż brokuł" is three.
    private func separated(_ meal: MealText, _ parts: [Range<Int>], _ protected: Set<Int>) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var pending = Array(parts.reversed())
        while let part = pending.popLast() {
            if let cut = secondFood(meal, part, protected), cut > part.lowerBound && cut < part.upperBound {
                pending.append(cut..<part.upperBound)
                pending.append(part.lowerBound..<cut)
            } else {
                result.append(part)
            }
        }
        return result
    }

    /// Where a second food starts in `part` ("kurczak ryż" → at "ryż"), or nil. A name stays whole: an
    /// adjective of a two-word name ("kawa z mlekiem owsianym"), the word after a flavoured head ("sos
    /// curry"), a genitive of meat or fish ("udko indyka"), anything after "do" ("miód do herbaty") and
    /// a word before the name of the same kind ("wafelek prince polo").
    private func secondFood(_ meal: MealText, _ part: Range<Int>, _ protected: Set<Int>) -> Int? {
        let head = analyze(meal, part, protected, allowingTypos: false)
        guard let match = head.match, head.nameTokens.count <= MealWords.maxSeparatedWords else { return nil }
        let names = head.nameTokens
        let first = match.position
        let last = first + match.alias.words.count
        var j = last
        while j < names.count {
            let k = names[j]
            let word = meal.tokens[k].norm
            // "miód do herbaty" is what it is for; "do tego surówka" is one more food.
            if word == "do" && !meal.isWord(k + 1, part.upperBound, in: MealWords.besides) { break }
            if let other = separateFood(meal, k, from: match), !(j == last && belongsToHead(meal, names, match, word)) {
                let start = MealParser.amountStart(meal, k, after: names[j - 1])
                let genitive = word.hasSuffix("a") || word.hasSuffix("u")
                if start == k && other.quality < 3 && match.quality == 3 && genitive
                    && MealWords.genitiveFoods.contains(other.alias.item.category)
                    && !MealParser.follows(meal, part, MealWords.withWords) {
                    j += 1
                    continue
                }
                return cut(meal, part, at: k, amountFrom: start, plainSecond: other.quality == 3, protected)
            }
            j += 1
        }
        // "bananem kawa z mlekiem": a food before a longer name.
        for b in 0..<first {
            if let other = separateFood(meal, names[b], from: match),
               other.alias.item.category != match.alias.item.category {
                let k = names[first]
                let start = MealParser.amountStart(meal, k, after: names[first - 1])
                return cut(meal, part, at: k, amountFrom: start, plainSecond: match.quality == 3, protected)
            }
        }
        // "kurczak z grilla 250 g ryż": the amount after the cooking words belongs to the food before them.
        if first == 0 {
            let k = names[0]
            let start = MealParser.amountStart(meal, k, after: part.lowerBound)
            if start < k && MealParser.saysHowCooked(meal, part.lowerBound..<start) {
                return cut(meal, part, at: k, amountFrom: start, plainSecond: match.quality == 3, protected)
            }
        }
        return nil
    }

    /// The other product the word at `k` names on its own, exactly or through an ending, or nil: the same
    /// product, an adjective of a two-word name ("owsianym") and "sery" of "4 sery" are none.
    private func separateFood(_ meal: MealText, _ k: Int, from head: MealCandidate) -> MealCandidate? {
        let word = meal.tokens[k].norm
        if MealWords.namedAfterNumber.contains(word) && k > 0 && meal.tokens[k - 1].isQuantity { return nil }
        // "rosół schabowy", "zupa pomidorowa mielony": after a dish, a dish named by an adjective is a second food.
        let namesDish = MealWords.dishAdjectives.contains(word) && head.alias.item.category == .dishes
        guard let other = bestMatch([word], allowingTypos: false), other.alias.item.id != head.alias.item.id,
              !isModifier(word) || namesDish else { return nil }
        return other
    }

    /// Whether `word`, right after the name, still belongs to it: a flavour ("sos curry", "sok jabłko") or
    /// a two-word name turned round ("latte kawa" for "kawa latte").
    private func belongsToHead(_ meal: MealText, _ names: [Int], _ match: MealCandidate, _ word: String) -> Bool {
        if let lastWord = match.alias.words.last, MealWords.flavoured.contains(lastWord.text) { return true }
        if match.alias.words.count == 1 {
            let pair = bestMatch([word, meal.tokens[names[match.position]].norm], allowingTypos: false)
            if let pair, pair.alias.words.count == 2 && pair.alias.item.id == match.alias.item.id { return true }
        }
        return false
    }

    /// Whether `word` is a form of an adjective that ends a two-word name: "owsianym" of "mleko owsiane".
    private func isModifier(_ word: String) -> Bool {
        modifiers.contains { modifier in
            if word == modifier.text { return true }
            guard let stem = modifier.vowelStem, word.hasPrefix(stem) else { return false }
            return MealWords.adjectiveForms.contains(String(word.dropFirst(stem.count)))
        }
    }

    /// The first token of the amount written right before token `k`, after token `floor`: in
    /// "jajka 2 kromki chleba" the bread's amount starts at "2".
    private static func amountStart(_ meal: MealText, _ k: Int, after floor: Int) -> Int {
        var start = k
        while start - 1 > floor && meal.isAmountToken(start - 1) {
            start -= 1
        }
        return start
    }

    /// Where to cut before the second food at `k`, whose amount would start at `start`: "kurczak 150 g ryż"
    /// keeps the 150 g with the chicken, "2 jajka 2 kromki chleba" gives the bread its 2.
    private func cut(_ meal: MealText, _ part: Range<Int>, at k: Int, amountFrom start: Int, plainSecond: Bool,
                     _ protected: Set<Int>) -> Int {
        if start == k { return k }
        // "2 jajka 4 kromki chleba 2 plastry sera": an amount with a food after it is that food's,
        // so the second food is read only up to it.
        var secondEnd = part.upperBound
        for m in (k + 1)..<part.upperBound {
            guard let found = meal.quantity(at: m, end: part.upperBound) else { continue }
            let next = meal.isUnit(found.next, part.upperBound) ? found.next + 1 : found.next
            if meal.hasNameWord(next..<part.upperBound) { secondEnd = m }
            break
        }
        let second = analyze(meal, k..<secondEnd, protected, allowingTypos: false)
        let first = analyze(meal, part.lowerBound..<start, protected, allowingTypos: false)
        if second.quantity != nil || (first.quantity == nil && plainSecond) { return k }
        return start
    }

    // MARK: - One fragment

    private func analyze(_ meal: MealText, _ part: Range<Int>, _ protected: Set<Int>,
                         allowingTypos: Bool) -> MealAnalysis {
        var result = MealAnalysis()
        let end = part.upperBound
        var used = Set<Int>()          // tokens of the amount
        var unitToken: Int?            // the unit word right after the amount
        var quantityToken: Int?        // the first token of the amount
        var q = part.lowerBound
        while q < end {
            guard let found = meal.quantity(at: q, end: end) else {
                q += 1
                continue
            }
            // "pizza 4 sery", "chleb 7 zbóż", "pizza 30 cm": a number of the name, not an amount.
            if meal.isWord(found.next, end, in: MealWords.namedAfterNumber) && meal.hasNameWord(part.lowerBound..<q) {
                q = found.next
                continue
            }
            var value = found.value
            var after = found.next
            var isDecimal = meal.tokens[q].kind == .number && after == q + 1 && value != value.rounded()
            used.formUnion(q..<after)
            // "2 pączki" is a count of doughnuts, not of packages.
            if meal.isUnit(after, end) && !meal.isDoughnut(after) {
                unitToken = after
                after += 1
            }
            // "2 x 50 g", "2x50g", "2 razy 50 g", "50 g x 2"
            if meal.isTimes(after, end), after + 1 < end, let second = meal.quantity(at: after + 1, end: end) {
                used.formUnion(after..<second.next)
                value *= second.value
                isDecimal = false
                after = second.next
                if meal.isUnit(after, end) && !meal.isDoughnut(after) {
                    unitToken = after
                }
            }
            // A run of digits nobody eats ("99999999999999999999 g") is no amount at all.
            if value.isFinite && value <= MealWords.maxAmount {
                quantityToken = q
                result.quantity = value
                result.quantityIsDecimal = isDecimal
                result.quantityFollowsName = meal.hasNameWord(part.lowerBound..<q)
            } else {
                unitToken = nil
            }
            break
        }

        var names: [Int] = []
        var unitWords: [Int] = []
        var negated = false
        for k in part {
            let token = meal.tokens[k]
            guard token.kind == .word, !used.contains(k) else { continue }
            let word = token.norm
            // "kawa bez cukru": nothing after "bez" was eaten (unless it is part of a name: "mleko bez laktozy").
            if word == MealWords.negation && !protected.contains(k) { negated = true }
            if negated { continue }
            if MealWords.numbers[word] != nil || MealWords.times.contains(word) || MealWords.filler.contains(word)
                || MealWords.preparation.contains(word) {
                continue
            }
            if MealWords.isJoining(word) && !protected.contains(k) { continue }
            if MealWords.units[word] != nil && !meal.isDoughnut(k) {
                unitWords.append(k)
                continue
            }
            names.append(k)
        }
        // A unit right after another number belongs to that number: "2 jajka (ok. 120 g)" is two eggs, not 2 g.
        let looseUnits = unitWords.filter { k in
            !(k > part.lowerBound && meal.tokens[k - 1].isQuantity && !used.contains(k - 1))
        }
        if let unitToken {
            result.unit = MealWords.units[meal.tokens[unitToken].norm]
        } else if let first = looseUnits.first,
                  result.quantity != nil || !MealWords.unitSymbols.contains(meal.tokens[first].norm) {
            // A bare "L" or "g" with no number is a size or a stray letter, not a litre or a gram.
            result.unit = MealWords.units[meal.tokens[first].norm]
        }
        if !names.isEmpty {
            result.nameTokens = names
            // "kawa z Kasią": a capitalised word right after another word is a name, never a typo of a food.
            let isName = names.contains { k in
                k > 0 && meal.tokens[k - 1].kind == .word && meal.chars[meal.tokens[k].start].isUppercase
            }
            result.match = bestMatch(names.map { meal.tokens[$0].norm }, allowingTypos: allowingTypos && !isName)
            // "sok z 4 pomarańczy": the count stands inside the name.
            if let amountAt = quantityToken, let match = result.match, match.alias.words.count > 1 {
                result.quantityInsideName = names[match.position] < amountAt
                    && amountAt < names[match.position + match.alias.words.count - 1]
            }
        } else if !unitWords.isEmpty,
                  let match = bestMatch(unitWords.map { meal.tokens[$0].norm }, allowingTypos: false) {
            // "2 pączki" is normalized like the unit "paczki": with nothing else, the unit word is the name.
            result.unit = nil
            result.nameTokens = unitWords
            result.match = match
        }
        return result
    }

    private func makeItem(_ meal: MealText, _ part: Range<Int>, _ analysis: MealAnalysis,
                          _ match: MealCandidate) -> ParsedItem {
        let item = match.alias.item
        let quantity = analysis.quantity
        let amount: Double
        let unit: PortionUnit?
        let grams: Double
        switch analysis.unit {
        case .grams(let perUnit)?:
            amount = (quantity ?? 1) * perUnit
            unit = nil
            grams = amount
        case .portion(let portion)?:
            amount = quantity ?? 1
            unit = portion
            grams = amount * item.grams(per: portion)
        case nil:
            // "piwo 0,0" is no amount of beer.
            let count: Double? = quantity == 0 && item.category == .drinks ? nil : quantity
            if let count, count < 3, analysis.quantityIsDecimal, analysis.quantityFollowsName,
               item.category == .drinks {
                // "pepsi 0,5", "woda mineralna 1,5": litres.
                amount = count * 1000
                unit = nil
                grams = amount
            } else if let count, count > 20 {
                // A bare number above 20 is grams: "150 łososia".
                amount = count
                unit = nil
                grams = count
            } else if let count, analysis.quantityInsideName, item.category == .drinks {
                // "sok z 4 pomarańczy": the juice of four oranges, not four glasses.
                amount = count * MealWords.juicePerFruit
                unit = nil
                grams = amount
            } else if let count {
                // A count means pieces: "6 pierogów", "pół melona".
                let portion = MealParser.countedPortion(of: item)
                amount = count
                unit = portion.unit
                grams = count * portion.grams
            } else if let serving = item.portions.first(where: { $0.unit == .serving }),
                      item.defaultPortion.unit != .serving, !MealParser.namesOnePiece(meal, analysis, match) {
                // With no amount at all she means one serving: "pierogi" is a plateful, "pieróg" one.
                amount = 1
                unit = .serving
                grams = serving.grams
            } else {
                amount = 1
                unit = item.defaultPortion.unit
                grams = item.defaultPortion.grams
            }
        }
        let first = meal.tokens[part.lowerBound].start
        let last = meal.tokens[part.upperBound - 1].end
        return ParsedItem(text: String(meal.chars[first..<last]), foodID: item.id, foodName: item.name,
                          amount: amount, unit: unit, grams: grams, macros: item.macros(grams: grams),
                          isGuess: match.quality == 1)
    }

    /// Whether the name is one piece: a singular of the product exactly ("naleśnik"), or a form only a
    /// singular takes ("z jajkiem", "w ziemniaku").
    private static func namesOnePiece(_ meal: MealText, _ analysis: MealAnalysis, _ match: MealCandidate) -> Bool {
        guard let singular = match.alias.item.singular, !singular.isEmpty else { return false }
        if match.quality == 3 { return match.alias.isSingular }
        let word = meal.tokens[analysis.nameTokens[match.position]].norm
        return match.quality == 2 && MealWords.singularEndings.contains(where: { word.hasSuffix($0) })
    }

    /// What a count with no unit counts: the product's piece when it is bigger than its usual amount
    /// ("pół melona", "2 kolby kukurydzy", but not "2 kostki czekolady"), otherwise its default portion.
    private static func countedPortion(of item: FoodItem) -> Portion {
        if item.defaultPortion.unit == .serving || item.defaultPortion.unit == .chunk,
           let piece = item.portions.first(where: { $0.unit == .piece }), piece.grams > item.defaultPortion.grams {
            return piece
        }
        return item.defaultPortion
    }

    /// The product an item was made from (an item always has one).
    private func product(_ id: String) -> FoodItem? {
        aliases.first(where: { $0.item.id == id })?.item
    }

    // MARK: - Matching

    private func bestMatch(_ words: [String], allowingTypos: Bool) -> MealCandidate? {
        if let found = bestCandidate(words, allowingTypos: false) {
            return found
        }
        return allowingTypos ? bestCandidate(words, allowingTypos: true) : nil
    }

    private func bestCandidate(_ words: [String], allowingTypos: Bool) -> MealCandidate? {
        var best: MealCandidate?
        for alias in aliases {
            let count = alias.words.count
            guard words.count >= count else { continue }
            for s in 0...(words.count - count) {
                var quality = 3
                for t in 0..<count {
                    quality = Swift.min(quality, MealParser.quality(of: words[s + t], as: alias.words[t],
                                                                    allowingTypos: allowingTypos))
                    if quality == 0 { break }
                }
                if quality == 0 { continue }
                let candidate = MealCandidate(alias: alias, position: s, quality: quality)
                if let current = best, !candidate.isBetter(than: current) { continue }
                best = candidate
            }
        }
        return best
    }

    /// 3 the same word, 2 an inflected form, 1 a typo (only when allowed), 0 no match.
    private static func quality(of word: String, as alias: MealAliasWord, allowingTypos: Bool) -> Int {
        if word == alias.text { return 3 }
        if MealWords.falseFriends.contains(word) { return 0 }
        // ser → sera, kurczak → kurczakiem; never inside a word (deser ≠ ser), never for "z" or "i".
        if alias.length >= 3 && hasEnding(word, after: alias.text) { return 2 }
        // "surówka" is no form of "surowy", "maślanka" none of "maślana".
        if let stem = alias.vowelStem, hasEnding(word, after: stem, orNone: alias.bareStemIsWord),
           !(alias.isDescriptive && word.dropFirst(stem.count).hasPrefix("k")) { return 2 }
        if let stem = alias.fleetingStem, hasEnding(word, after: stem) { return 2 }
        if let plural = alias.genitivePlural, word == plural { return 2 }
        if allowingTypos {
            let length = word.count
            if length >= 5 {
                let limit = length <= 7 ? 1 : 2
                if Swift.abs(length - alias.length) <= limit
                    && editDistance(Array(word), Array(alias.text)) <= limit {
                    return 1
                }
            }
        }
        return 0
    }

    /// Whether `word` is `stem` plus one of the Polish endings (or nothing, when `orNone`).
    private static func hasEnding(_ word: String, after stem: String, orNone: Bool = false) -> Bool {
        guard word.hasPrefix(stem) else { return false }
        let rest = String(word.dropFirst(stem.count))
        return rest.isEmpty ? orNone : MealWords.endings.contains(rest)
    }

    /// Damerau-Levenshtein distance (optimal string alignment): "bannan" → "banan" is 1.
    static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var best = Swift.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] {
                    best = Swift.min(best, d[i - 2][j - 2] + 1)
                }
                d[i][j] = best
            }
        }
        return d[a.count][b.count]
    }
}

// MARK: - Index

/// One word of an alias, with its inflection stems worked out once.
private struct MealAliasWord: Sendable {
    let text: String
    let length: Int
    /// masło → masł (masła, masłem); migdały → migdał (migdałów).
    let vowelStem: String?
    /// From 5 letters the stem is a form too: migdały → migdał, pierogi → pierog (pieróg) –
    /// but not an adjective's stem: "pomidorów" is no form of "pomidorowa".
    let bareStemIsWord: Bool
    /// Fleeting e: czosnek → czosnk (czosnku), cukier → cukr (cukru).
    let fleetingStem: String?
    /// Inserted e: jajko → jajek, bułka → bułek, borówki → borówek.
    let genitivePlural: String?
    /// An adjective that only describes ("surowy", "maślana"), not a dish's own name ("pomidorowa"):
    /// "surówka" and "maślanka" are no forms of it.
    let isDescriptive: Bool

    init(_ text: String, isDescriptive: Bool) {
        self.isDescriptive = isDescriptive
        let letters = Array(text)
        let count = letters.count
        self.text = text
        length = count
        if count >= 4 && MealWords.stemVowels.contains(letters[count - 1]) {
            vowelStem = String(letters[0..<(count - 1)])
        } else {
            vowelStem = nil
        }
        bareStemIsWord = count >= 5 && !String(letters[0..<(count - 1)]).hasSuffix("ow")
        var fleeting: String?
        if count >= 4 && letters[count - 2] == "e" && !MealWords.vowels.contains(letters[count - 1]) {
            let cut = letters[count - 3] == "i" ? 3 : 2
            let stem = String(letters[0..<(count - cut)]) + String(letters[count - 1])
            if stem.count >= 3 { fleeting = stem }
        }
        fleetingStem = fleeting
        if count >= 4 && "aoi".contains(letters[count - 1]) && letters[count - 2] == "k"
            && !MealWords.vowels.contains(letters[count - 3]) {
            genitivePlural = String(letters[0..<(count - 2)]) + "ek"
        } else {
            genitivePlural = nil
        }
    }
}

private struct MealAlias: Sendable {
    let words: [MealAliasWord]
    let item: FoodItem
    /// Position in the catalog, then her products – the last tie-breaker.
    let order: Int
    let letters: Int
    /// One of the product's singular forms ("naleśnik"): one piece, not a serving.
    let isSingular: Bool

    init(words: [String], item: FoodItem, order: Int, isSingular: Bool, singleWords: Set<String>) {
        self.words = words.map { word in
            MealAliasWord(word, isDescriptive: MealWords.isAdjective(word) && !singleWords.contains(word))
        }
        self.item = item
        self.order = order
        self.isSingular = isSingular
        letters = words.reduce(0) { $0 + $1.count }
    }
}

private struct MealCandidate: Sendable {
    let alias: MealAlias
    /// Index of the first name word it covers.
    let position: Int
    let quality: Int

    /// More words first ("jogurt grecki" over "jogurt"), then the earlier one ("kawa bez cukru"),
    /// then the closer form, then the longer alias ("serki" → serek, not ser).
    func isBetter(than other: MealCandidate) -> Bool {
        if alias.words.count != other.alias.words.count { return alias.words.count > other.alias.words.count }
        if position != other.position { return position < other.position }
        if quality != other.quality { return quality > other.quality }
        if alias.letters != other.alias.letters { return alias.letters > other.alias.letters }
        return alias.order < other.alias.order
    }
}

private struct MealAnalysis {
    var quantity: Double?
    var unit: MealUnit?
    var nameTokens: [Int] = []
    var match: MealCandidate?
    /// The amount is one number with a decimal part ("0,5"), not a count, a fraction or a range.
    var quantityIsDecimal = false
    /// A name word comes before the amount: "piwo 0,5", not "0,5 piwa".
    var quantityFollowsName = false
    /// The count stands inside the name: "sok z 4 pomarańczy" counts the fruit, not glasses.
    var quantityInsideName = false
}

/// The item made from an earlier part of a group, which a later part may still change:
/// "kurczak z grilla 400 g", "kawa z mlekiem".
private struct MealPreviousItem {
    let index: Int
    let part: Range<Int>
    let analysis: MealAnalysis
    let match: MealCandidate
}

// MARK: - Tokens

private struct MealToken {
    enum Kind {
        case word, number, fraction, slash, percent, times, dash, time, separator, other
    }

    let kind: Kind
    /// A word, normalized with `FoodText.normalized`.
    var norm: String = ""
    /// The value of a number or a fraction sign.
    var value: Double = 0
    /// A number that reads as an hour with minutes: "8.30", "12.30".
    var isClock = false
    /// Character offsets in the original text.
    let start: Int
    let end: Int

    var isQuantity: Bool {
        (kind == .number && !isClock) || kind == .fraction || (kind == .word && MealWords.numbers[norm] != nil)
    }
}

/// The text as characters plus its tokens. Words are runs of letters, so Polish letters never
/// split a word ("ząbek" stays whole); a comma between two digits is a decimal comma.
private struct MealText {
    let chars: [Character]
    let tokens: [MealToken]

    init(_ text: String) {
        let chars = Array(text)
        var tokens: [MealToken] = []
        let n = chars.count
        var i = 0
        while i < n {
            let c = chars[i]
            // "Jabłko. Banan.": a sentence ends a fragment too (but not "szt." or "ok.").
            if c.isNewline || MealWords.separators.contains(c)
                || (c == "." && !MealText.closesAbbreviation(tokens, at: i)) {
                tokens.append(MealToken(kind: .separator, start: i, end: i + 1))
                i += 1
            } else if c.isWhitespace {
                i += 1
            } else if MealText.isDigit(c) {
                var j = i
                while j < n && MealText.isDigit(chars[j]) { j += 1 }
                // "8:30", "13:00": a clock time, never an amount.
                if j + 2 < n && chars[j] == ":" && MealText.isDigit(chars[j + 1]) && MealText.isDigit(chars[j + 2]) {
                    var k = j + 1
                    while k < n && MealText.isDigit(chars[k]) { k += 1 }
                    tokens.append(MealToken(kind: .time, start: i, end: k))
                    i = k
                    continue
                }
                var digits = String(chars[i..<j])
                var isClock = false
                var isWhole = true
                if j + 1 < n && (chars[j] == "," || chars[j] == ".") && MealText.isDigit(chars[j + 1]) {
                    var k = j + 1
                    while k < n && MealText.isDigit(chars[k]) { k += 1 }
                    let fraction = String(chars[(j + 1)..<k])
                    // "8.30", "12.30": an hour and its minutes (an amount only with a unit: "7.50 g").
                    if chars[j] == ".", fraction.count == 2, let hour = Int(digits), let minute = Int(fraction) {
                        isClock = hour >= 5 && hour <= 23 && minute < 60
                    }
                    digits += "." + fraction
                    j = k
                    isWhole = false
                }
                // "o 8 owsianka", "godz. 13 zupa": an hour, never an amount.
                if isWhole && MealText.followsClockWord(tokens, chars), let hour = Int(digits) {
                    isClock = hour <= 24
                }
                tokens.append(MealToken(kind: .number, value: Double(digits) ?? 0, isClock: isClock, start: i, end: j))
                i = j
            } else if let fraction = MealWords.fractions[c] {
                tokens.append(MealToken(kind: .fraction, value: fraction, start: i, end: i + 1))
                i += 1
            } else if c.isLetter {
                var j = i
                while j < n && chars[j].isLetter { j += 1 }
                tokens.append(MealToken(kind: .word, norm: FoodText.normalized(String(chars[i..<j])),
                                        start: i, end: j))
                i = j
            } else {
                let kind: MealToken.Kind
                switch c {
                case "/": kind = .slash
                case "%": kind = .percent
                case "×", "*": kind = .times
                case "-", "–": kind = .dash
                default: kind = .other
                }
                tokens.append(MealToken(kind: kind, start: i, end: i + 1))
                i += 1
            }
        }
        self.chars = chars
        self.tokens = tokens
    }

    /// Whether a full stop at `offset` closes an abbreviation written right before it: "szt.", "ok.", "np.".
    static func closesAbbreviation(_ tokens: [MealToken], at offset: Int) -> Bool {
        guard let last = tokens.last else { return false }
        return last.kind == .word && last.end == offset && MealWords.abbreviations.contains(last.norm)
    }

    /// Whether the text so far ends with "o" or "godz." ("o 8", "godz. 13"): the number after it is an hour.
    static func followsClockWord(_ tokens: [MealToken], _ chars: [Character]) -> Bool {
        var k = tokens.count - 1
        if k >= 0 && tokens[k].kind == .other && chars[tokens[k].start] == "." { k -= 1 }
        return k >= 0 && tokens[k].kind == .word && MealWords.clockWords.contains(tokens[k].norm)
    }

    /// Letter runs of the normalized phrase: "Pierś z kurczaka" → ["piers", "z", "kurczaka"].
    static func words(of phrase: String) -> [String] {
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
        return words
    }

    static func isDigit(_ character: Character) -> Bool {
        guard let ascii = character.asciiValue else { return false }
        return ascii >= 48 && ascii <= 57
    }

    func isWord(_ k: Int, _ end: Int, _ word: String) -> Bool {
        k < end && tokens[k].kind == .word && tokens[k].norm == word
    }

    func isWord(_ k: Int, _ end: Int, in words: Set<String>) -> Bool {
        k < end && tokens[k].kind == .word && words.contains(tokens[k].norm)
    }

    /// Whether token `k` is a word that starts with one of `stems`: "przekrojone" with "przekroj".
    func isWord(_ k: Int, _ end: Int, startingWith stems: Set<String>) -> Bool {
        guard k < end && tokens[k].kind == .word else { return false }
        let word = tokens[k].norm
        return stems.contains(where: { word.hasPrefix($0) })
    }

    func isUnit(_ k: Int, _ end: Int) -> Bool {
        k < end && tokens[k].kind == .word && MealWords.units[tokens[k].norm] != nil
    }

    /// "pączek", "pączki" written with "ą": normalized they read like the unit "paczek", "paczki"
    /// (but "z paczką chipsów" is a package).
    func isDoughnut(_ k: Int) -> Bool {
        let token = tokens[k]
        guard token.kind == .word, MealWords.units[token.norm] == MealUnit.portion(.package),
              token.end - token.start >= 2 else { return false }
        let second = chars[token.start + 1]
        return second == "ą" || second == "Ą"
    }

    func isTimes(_ k: Int, _ end: Int) -> Bool {
        k < end && (tokens[k].kind == .times || (tokens[k].kind == .word && MealWords.times.contains(tokens[k].norm)))
    }

    /// Whether a word in `range` can be part of a name: not an amount, a unit, a filler, cooking or joining word.
    func hasNameWord(_ range: Range<Int>) -> Bool {
        for k in range where tokens[k].kind == .word {
            let word = tokens[k].norm
            if !MealWords.isNeverName(word) && !MealWords.isJoining(word) { return true }
        }
        return false
    }

    /// Whether token `k` belongs to an amount: a number, a unit, "x", "ok.", "i pół".
    func isAmountToken(_ k: Int) -> Bool {
        let token = tokens[k]
        switch token.kind {
        case .number, .fraction, .slash, .times, .dash:
            return true
        case .word:
            let word = token.norm
            return MealWords.numbers[word] != nil || MealWords.units[word] != nil || MealWords.times.contains(word)
                || MealWords.filler.contains(word) || (word == "i" && isWord(k + 1, tokens.count, "pol"))
        case .other:
            return chars[token.start] == "."
        default:
            return false
        }
    }

    /// The range split at the given words, unless protected. Parts may be empty.
    func split(_ range: Range<Int>, at words: Set<String>, keeping protected: Set<Int>) -> [Range<Int>] {
        var parts: [Range<Int>] = []
        var start = range.lowerBound
        for k in range where tokens[k].kind == .word && words.contains(tokens[k].norm) && !protected.contains(k) {
            parts.append(start..<k)
            start = k + 1
        }
        parts.append(start..<range.upperBound)
        return parts
    }

    /// Whether the number at `k` is a fat content, not an amount: "mleko 2%", "jogurt 2-3%".
    func isPercentage(_ k: Int, _ end: Int) -> Bool {
        if k + 1 < end && tokens[k + 1].kind == .percent { return true }
        return k + 3 < end && tokens[k + 1].kind == .dash && tokens[k + 2].kind == .number
            && tokens[k + 3].kind == .percent
    }

    /// The amount starting at token `k`: 2, 0,5, 1/2, ½, 1 1/2, 1½, 2-3, pół, trzy, dwa i pół.
    /// `next` is the token after it. nil when no amount starts there (also for "2%", "2-3%", "8.30"
    /// and "250 kcal").
    func quantity(at k: Int, end: Int) -> (value: Double, next: Int)? {
        let token = tokens[k]
        var value: Double
        var next: Int
        switch token.kind {
        case .number:
            if isPercentage(k, end) { return nil }
            if token.isClock && !isUnit(k + 1, end) { return nil }
            // "8 rano owsianka", "ok. 13 obiad: zupa", "2 śniadanie: jogurt": an hour or the meal's number.
            if token.value <= 24 && token.value == token.value.rounded()
                && isWord(k + 1, end, in: MealWords.hourWords) { return nil }
            if k + 2 < end && tokens[k + 1].kind == .slash && tokens[k + 2].kind == .number {
                if tokens[k + 2].value == 0 { return nil }
                value = token.value / tokens[k + 2].value
                next = k + 3
            } else {
                value = token.value
                next = k + 1
                if next < end && tokens[next].kind == .fraction {
                    value += tokens[next].value
                    next += 1
                } else if next + 2 < end && tokens[next].kind == .number && tokens[next + 1].kind == .slash
                            && tokens[next + 2].kind == .number
                            && tokens[next].value > 0 && tokens[next].value < tokens[next + 2].value {
                    value += tokens[next].value / tokens[next + 2].value
                    next += 3
                } else if next + 1 < end && tokens[next].kind == .dash && tokens[next + 1].kind == .number {
                    // "2-3 łyżki": the middle.
                    value = (value + tokens[next + 1].value) / 2
                    next += 2
                }
            }
        case .fraction:
            value = token.value
            next = k + 1
        case .word:
            guard let number = MealWords.numbers[token.norm] else { return nil }
            value = number
            next = k + 1
        default:
            return nil
        }
        // "trzy czwarte szklanki", "jedna trzecia pizzy".
        if token.kind == .word || token.kind == .number, next < end, tokens[next].kind == .word,
           let divisor = MealWords.fractionWords[tokens[next].norm] {
            value /= divisor
            next += 1
        }
        // "baton 250 kcal", "200-250 kcal": the energy on the wrapper.
        if isWord(next, end, in: MealWords.energy) { return nil }
        // "skyr 20 g białka": the protein on the label, not an amount ("100 g białka jaj" is one).
        if isUnit(next, end), MealWords.units[tokens[next].norm] == MealUnit.grams(1),
           isWord(next + 1, end, in: MealWords.nutrients), !isWord(next + 2, end, in: MealWords.proteinFoods) {
            return nil
        }
        if isWord(next, end, "i") && isWord(next + 1, end, "pol") {
            return (value + 0.5, next + 2)
        }
        return (value, next)
    }

    /// The original text of the tokens without amounts and units, in her letters:
    /// "6 pierogów" → "pierogów", "pierogi (6 szt.)" → "pierogi". A unit word stays when
    /// it is the only word ("2 pączki" → "pączki").
    func cleaned(_ range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        let start = range.lowerBound
        let end = range.upperBound
        var removed = Set<Int>()
        var unitWords: [Int] = []
        var hasName = false
        for k in range {
            let token = tokens[k]
            switch token.kind {
            case .number:
                // "mleko 2%" and "jogurt 2-3%" keep their numbers.
                if !isPercentage(k, end) { removed.insert(k) }
            case .fraction, .slash, .times, .time:
                removed.insert(k)
            case .dash:
                if k > start && tokens[k - 1].kind == .number && k + 1 < end && tokens[k + 1].kind == .number
                    && !isPercentage(k + 1, end) {
                    removed.insert(k)
                }
            case .word:
                let word = token.norm
                if MealWords.numbers[word] != nil || MealWords.times.contains(word) || MealWords.filler.contains(word) {
                    removed.insert(k)
                } else if word == "i" && k > start && tokens[k - 1].isQuantity && isWord(k + 1, end, "pol") {
                    removed.insert(k)
                } else if MealWords.units[word] != nil {
                    unitWords.append(k)
                } else {
                    hasName = true
                }
            default:
                break
            }
        }
        if hasName { removed.formUnion(unitWords) }
        // A dot right after a removed word belongs to it: "szt.", "g.".
        for k in start..<(end - 1) {
            if removed.contains(k) && tokens[k].kind == .word && tokens[k + 1].kind == .other
                && chars[tokens[k + 1].start] == "." && tokens[k + 1].start == tokens[k].end {
                removed.insert(k + 1)
            }
        }
        // Each removed token becomes a space; then spaces are collapsed and empty brackets dropped.
        var out: [Character] = []
        var position = tokens[start].start
        for k in range where removed.contains(k) {
            out.append(contentsOf: chars[position..<tokens[k].start])
            out.append(" ")
            position = tokens[k].end
        }
        out.append(contentsOf: chars[position..<tokens[end - 1].end])
        return MealText.trimmedName(MealText.withoutEmptyBrackets(MealText.collapsed(out)))
    }

    static func collapsed(_ characters: [Character]) -> [Character] {
        var result: [Character] = []
        var pendingSpace = false
        for character in characters {
            if character.isWhitespace {
                pendingSpace = !result.isEmpty
                continue
            }
            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(character)
        }
        return result
    }

    /// "pierogi ( )" → "pierogi " – brackets left empty once the amount is gone.
    static func withoutEmptyBrackets(_ characters: [Character]) -> [Character] {
        var result: [Character] = []
        var i = 0
        while i < characters.count {
            if characters[i] == "(" {
                var j = i + 1
                while j < characters.count && characters[j] == " " { j += 1 }
                if j < characters.count && characters[j] == ")" {
                    i = j + 1
                    continue
                }
            }
            result.append(characters[i])
            i += 1
        }
        return result
    }

    /// Punctuation and spaces trimmed from both ends; letters, digits, "%" and a closing bracket stay.
    static func trimmedName(_ characters: [Character]) -> String {
        var s = 0
        var e = characters.count
        while s < e && !keepsName(characters[s]) { s += 1 }
        while e > s && !keepsName(characters[e - 1]) {
            if characters[e - 1] == ")" && characters[s..<(e - 1)].contains("(") { break }
            e -= 1
        }
        return String(characters[s..<e])
    }

    private static func keepsName(_ character: Character) -> Bool {
        character.isLetter || isDigit(character) || character == "%"
    }
}

// MARK: - Words

private enum MealUnit: Sendable, Equatable {
    /// Grams (or millilitres) per one: g 1, dag 10, kg 1000, ml 1, l 1000.
    case grams(Double)
    case portion(PortionUnit)
}

/// The Polish words of the parser, already normalized (ł → l, ó → o, ś → s …).
private enum MealWords {
    // The element types are spelled out, so the literals never depend on inference through `table`.
    static let numbers: [String: Double] = table([
        ("pol polowa polowy polowe polowka polowki polowke", 0.5),
        ("poltora poltorej", 1.5),
        ("cwierc", 0.25),
        ("jeden jedna jedno jednego jednej jednym", 1),
        ("dwa dwie dwoch dwoma dwom dwiema", 2),
        ("trzy trzech trzema", 3),
        ("cztery czterech czterema", 4),
        ("piec pieciu piecioma", 5),
        ("szesc szesciu szescioma", 6),
        ("siedem siedmiu siedmioma", 7),
        ("osiem osmiu osmioma", 8),
        ("dziewiec dziewieciu dziewiecioma", 9),
        ("dziesiec dziesieciu dziesiecioma", 10),
        ("pare paru paroma", 2),
        ("kilka kilku kilkoma", 3),
    ] as [(String, Double)])

    static let units: [String: MealUnit] = table([
        ("g gr gram gramy gramow grama", .grams(1)),
        ("dag dkg deko deka dekagram dekagramy dekagramow", .grams(10)),
        ("kg kilo kilogram kilograma kilogramy kilogramow", .grams(1000)),
        ("ml mililitr mililitra mililitry mililitrow", .grams(1)),
        ("l litr litra litry litrow", .grams(1000)),
        ("lyzka lyzki lyzek lyzke lyzkami lyz lyzce lyzkach", .portion(.tablespoon)),
        // "kęs ciasta", "parę łyków coli": a bite or a sip is about a spoonful.
        ("kes kesa kesy kesow kesem kesek keska lyk lyka lyki lykow lykiem lyczek lyczka", .portion(.tablespoon)),
        ("lyzeczka lyzeczki lyzeczek lyzeczke lyzeczkami lyzeczce", .portion(.teaspoon)),
        ("odrobina odrobiny odrobine", .portion(.teaspoon)),
        ("kropla kropli krople kroplami kropel kropelka kropelki kropelke kropelek", .portion(.teaspoon)),
        ("szklanka szklanki szklanek szklanke szklankami szklance szkl", .portion(.glass)),
        ("kieliszek kieliszka kieliszki kieliszkow kieliszkiem lampka lampki lampke", .portion(.glass)),
        ("kubek kubka kubki kubkow kubkiem kubku", .portion(.mug)),
        ("kufel kufla kufle kuflem filizanka filizanki filizanke", .portion(.mug)),
        ("kromka kromki kromek kromke kromkami kromce kromkach", .portion(.slice)),
        ("plaster plastra plastry plastrow plastrem plastrami plastrze plastrach", .portion(.thinSlice)),
        ("plasterek plasterka plasterki plasterkow plasterkiem plasterkami", .portion(.thinSlice)),
        ("plasterku plasterkach", .portion(.thinSlice)),
        // "5 różyczek brokuła", "2 krążki ananasa", "4 cząstki pomarańczy": a small piece, weighed like a slice.
        ("rozyczka rozyczki rozyczek rozyczke rozyczkami krazek krazka krazki krazkow krazkiem krazkami",
         .portion(.thinSlice)),
        ("czastka czastki czastek czastke czastkami", .portion(.thinSlice)),
        ("garsc garsci garscia garstka garstki garstke garscie garsciami garsciach", .portion(.handful)),
        ("sztuka sztuki sztuk sztuke szt galka galki galek galke", .portion(.piece)),
        // A cube of chocolate or sugar, a block of twaróg, butter or tofu: the product's own piece.
        ("kostka kostki kostek kostke kostce kostkami kosteczka kosteczki kosteczke kosteczek", .portion(.piece)),
        ("porcja porcje porcji porcjami", .portion(.serving)),
        ("miska miski misek miske misce miseczka miseczki miseczke", .portion(.bowl)),
        ("talerz talerza talerze talerzy talerzem talerzu", .portion(.bowl)),
        ("puszka puszki puszek puszke puszce butelka butelki butelek butelke", .portion(.can)),
        ("opakowanie opakowania opakowan opakowaniem opakowaniu paczka paczki paczek paczke op opak",
         .portion(.package)),
        ("tabliczka tabliczki tabliczek tabliczke kubeczek kubeczka kubeczki", .portion(.package)),
        ("kawalek kawalka kawalki kawalkow kawalkiem kawalkami kawalku", .portion(.chunk)),
        ("kawaleczek kawaleczka kawaleczki", .portion(.chunk)),
        ("zabek zabka zabki zabkow zabkiem zabkami", .portion(.clove)),
    ] as [(String, MealUnit)])

    /// "2 x 50 g", "2 razy 50 g" (× and * are tokens of their own).
    static let times: Set<String> = ["x", "razy"]
    /// Words that are never part of a name: around an amount ("ok. 100 g", "250 kcal", "o 8", "trzy czwarte",
    /// "do tego"), the meal ("obiad:", "zjadłam"), where it came from ("z pizzerii") and who she ate with
    /// ("z koleżanką").
    static let filler: Set<String> = [
        "ok", "okolo", "kcal", "kalorii", "kalorie",
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
        "czwarta", "czwarte", "czwartych", "trzecia", "trzecie", "trzecich",
    ]
    /// Always split: "jajko i kawa".
    static let joining: Set<String> = ["i", "oraz", "plus", "a"]
    /// Split too, unless the head is unknown: "pierogi z mięsem" stays one dish.
    static let withWords: Set<String> = ["z", "ze"]
    /// Split softly: after them only a food counts ("na maśle", "w sosie pomidorowym");
    /// "na twardo", "na śniadanie", "w pracy" are dropped.
    static let softWords: Set<String> = ["na", "w"]
    static let splitting: Set<String> = MealWords.withWords.union(MealWords.softWords)
    /// How it was cooked, never a food: "kiełbasa z grilla" is just the kiełbasa.
    static let preparation: Set<String> = [
        "grilla", "grillu", "piekarnika", "patelni", "rusztu", "rozna", "frytkownicy", "airfryera", "mikrofali",
        "mikrofalowki", "ekspresu", "kranu", "woka", "pieca", "tostera", "parowaru",
    ]
    /// How it was made, after "na": an amount after them is the food's ("jajka na twardo 3 sztuki").
    /// They stay name words ("warzywa na parze", "makaron na sucho").
    static let manner: Set<String> = [
        "twardo", "miekko", "polmiekko", "parze", "sucho", "surowo", "ostro", "slodko", "goraco", "zimno", "cieplo",
    ]
    /// "kawa bez cukru": nothing after it was eaten.
    static let negation = "bez"
    /// Words that look like an inflected short alias but are other words (pora ≠ por, wódka ≠ woda,
    /// oliwki ≠ oliwa, "protein" of a label ≠ proteina). They still match a product spelled exactly like them.
    static let falseFriends: Set<String> = ["pora", "wodka", "wodki", "oliwka", "oliwki", "oliwkami", "protein"]
    /// Polish endings of nouns and adjectives, normalized (ę → e, ą → a, ó → o).
    static let endings: Set<String> = [
        "a", "u", "y", "i", "e", "o", "em", "om", "ie", "ach", "ami", "ow", "owi", "ka", "ki", "kiem", "kami",
        "iem", "ia", "iu", "ej", "iej", "ego", "emu", "ym", "im", "ymi", "imi", "ych", "ich",
    ]
    /// Final vowels replaced by an ending: masło → masła.
    static let stemVowels: Set<Character> = ["a", "e", "o", "y", "i"]
    static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
    static let fractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]
    /// Signs that end a fragment, besides new lines and a full stop that ends a sentence.
    static let separators: Set<Character> = [",", ";", "+", "!", "?", "…"]
    /// Abbreviations a full stop may close without ending the sentence: "3 szt. jajek", "ok. 100 g", "m.in.".
    static let abbreviations: Set<String> = [
        "g", "gr", "dag", "dkg", "kg", "ml", "l", "lyz", "szt", "szkl", "op", "opak", "ok", "np", "tzw", "sr", "sw",
        "wg", "ew", "m", "in", "itp", "itd", "tj", "dr", "godz",
    ]
    /// "o 8 owsianka", "godz. 13 zupa": the number after them is an hour, never an amount.
    static let clockWords: Set<String> = ["o", "godz", "godzina", "godzinie"]
    /// "8 rano owsianka", "ok. 13 obiad: zupa": a whole number up to 24 before them is an hour.
    static let hourWords: Set<String> = ["rano", "wieczorem", "h", "sniadanie", "obiad", "kolacja", "lunch"]
    /// "do tego surówka", "do picia sok": what follows is eaten too, unlike "miód do herbaty".
    static let besides: Set<String> = ["tego", "tej", "picia"]
    /// "trzy czwarte szklanki", "jedna trzecia pizzy": the number before them is divided.
    static let fractionWords: [String: Double] = [
        "czwarta": 4, "czwarte": 4, "czwartych": 4, "trzecia": 3, "trzecie": 3, "trzecich": 3,
    ]
    /// The form a food takes after "z" ("mlekiem", "owocami", "szynką"): after "i" it carries the list on.
    static let instrumentalLetters: Set<Character> = ["ą", "Ą"]
    static let instrumentalEndings: Set<String> = ["em", "ami"]
    /// Dishes counted in pieces, slices or chunks: a count after what came with them is theirs.
    static let countedDishes: Set<PortionUnit> = [.piece, .slice, .chunk]
    /// Drinks that are only what went into them: "koktajl z banana i szpinaku" is the banana and the spinach.
    static let containers: Set<String> = [
        "koktajl", "koktajle", "koktajlu", "koktajlem", "smoothie", "smoothies", "szejk", "szejka", "shake",
    ]
    /// Unit words that need a number: a bare "L" is a size, not a litre, and "różyczki brokuła" with no number
    /// are a serving.
    static let unitSymbols: Set<String> = [
        "g", "gr", "dag", "dkg", "kg", "ml", "l", "rozyczka", "rozyczki", "rozyczek", "rozyczke", "rozyczkami",
        "krazek", "krazka", "krazki", "krazkow", "krazkiem", "krazkami", "czastka", "czastki", "czastek", "czastke",
        "czastkami",
    ]
    /// "baton 250 kcal": energy, not an amount.
    static let energy: Set<String> = ["kcal", "kalorii", "kalorie"]
    /// "skyr 20 g białka": a nutrient on the label, not an amount.
    static let nutrients: Set<String> = ["bialka", "bialko", "tluszczu", "weglowodanow", "blonnika", "cukrow"]
    /// "100 g białka jaj", "100 g białka z jajka", "30 g białka serwatkowego": egg white or whey, an amount after
    /// all (a "z" stays in the part only inside a name).
    static let proteinFoods: Set<String> = ["jaj", "jaja", "jajek", "jajka", "z", "serwatkowego", "serwatkowe", "wpc"]
    /// A number right before one of these is part of the name: "pizza 4 sery", "chleb 7 zbóż", "pizza 30 cm".
    static let namedAfterNumber: Set<String> = ["cm", "sery", "serow", "zboz", "ziaren"]
    /// The largest amount: a longer run of digits is no amount at all (and never reaches the UI).
    static let maxAmount: Double = 100_000
    /// Endings of adjectives ("owsiane", "grecki", "jaglana") – but not of nouns that look alike ("cytryna").
    static let adjectiveEndings: Set<String> = ["owy", "owa", "owe", "ny", "na", "ne", "ski", "ska", "skie", "cki",
                                                "cka", "ckie"]
    static let nounEndings: Set<String> = ["ina", "ine", "iny", "yna", "yne", "yny"]
    /// The forms of an adjective after its stem: owsian|ym, grzybow|ej.
    static let adjectiveForms: Set<String> = ["y", "a", "e", "i", "ego", "emu", "ym", "im", "ej", "iej", "ych", "ich",
                                              "ymi", "imi"]
    /// Heads whose next word is their flavour, not a second food: "sos curry", "zupa dynia", "sok jabłko".
    static let flavoured: Set<String> = ["sos", "zupa", "zupka", "sok", "budyn", "kisiel"]
    /// A genitive of these after a food says what it is made of: "udko indyka", "rosół kurczaka".
    static let genitiveFoods: Set<FoodCategory> = [.meat, .fish]
    /// Dishes named by an adjective alone: after another dish they are a second food ("rosół schabowy").
    static let dishAdjectives: Set<String> = ["schabowy", "mielony", "ruskie"]
    /// "przekrojone na pół", "pokroiłam na pół": cut in half, not shared (przekroić, pokroić, przeciąć, złożyć).
    static let cutStems: Set<String> = [
        "przekroj", "pokroj", "rozkroj", "kroj", "przekroil", "pokroil", "rozkroil", "kroil", "przeciet", "rozciet",
        "przeciel", "rozciel", "zloz",
    ]
    /// Fragments with more name words are sentences, not foods typed without commas: they are not cut.
    static let maxSeparatedWords = 12
    /// Milk with no amount after the drink or dish it went with ("kawa z cukrem i mlekiem") ...
    static let milks: Set<String> = ["mleko", "mleko-owsiane", "mleko-sojowe", "mleko-migdalowe"]
    /// ... that already has its milk ("latte na owsianym", "naleśniki na mleku") is not counted again,
    static let milkDishes: Set<String> = [
        "latte", "cappuccino", "kawa-z-mlekiem", "herbata-z-mlekiem", "kakao", "budyn", "nalesniki",
        "nalesniki-z-serem", "placuszki", "owsianka", "kasza-manna",
    ]
    /// ... and in coffee or tea it is a splash, not a glass: "kawa z mlekiem", "mleko do kawy".
    static let splashDrinks: Set<String> = ["kawa", "herbata"]
    static let splashMillilitres: Double = 30
    /// "mleko do kawy", "mleko do herbaty": the drink the splash is for.
    static let forDrinks: Set<String> = ["kawy", "herbaty", "kawki", "herbatki"]
    /// What goes into a drink or onto a dish: after "bez … i" it was left out too ("kawa bez cukru i mleka").
    static let addIns: Set<String> = MealWords.milks.union([
        "cukier", "slodzik", "miod", "smietana", "sos", "majonez", "ketchup", "cytryna", "maslo",
    ])
    /// "sok z 4 pomarańczy": the juice of one fruit, in millilitres.
    static let juicePerFruit: Double = 80
    /// Endings only a singular takes: "z jajkiem" and "w ziemniaku" are one piece, like "jajko".
    static let singularEndings: Set<String> = ["em", "u"]

    static func isJoining(_ word: String) -> Bool {
        joining.contains(word) || withWords.contains(word) || softWords.contains(word)
    }

    /// Words that are never part of a name: amounts, "x", "ok.", units and cooking words.
    static func isNeverName(_ word: String) -> Bool {
        numbers[word] != nil || times.contains(word) || filler.contains(word) || units[word] != nil
            || preparation.contains(word)
    }

    /// Words that stay part of the name when a known multi-word alias contains them.
    static func isProtectable(_ word: String) -> Bool {
        isJoining(word) || word == negation
    }

    /// Whether `word` looks like an adjective ("owsiane", "jaglana"), not a noun ("cytryna", "malina").
    static func isAdjective(_ word: String) -> Bool {
        adjectiveEndings.contains(where: { word.hasSuffix($0) }) && !nounEndings.contains(where: { word.hasSuffix($0) })
    }

    private static func table<Value>(_ groups: [(String, Value)]) -> [String: Value] {
        var result: [String: Value] = [:]
        for (words, value) in groups {
            for word in words.split(separator: " ") {
                result[String(word)] = value
            }
        }
        return result
    }
}
