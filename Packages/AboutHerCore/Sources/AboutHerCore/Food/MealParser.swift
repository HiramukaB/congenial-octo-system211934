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
/// 1. The text is split on , ; + and new lines, then on the words i, oraz, plus, a and z/ze –
///    except inside a known name ("pierś z kurczaka") or an amount ("dwa i pół"). After an
///    unknown dish, "z …" stays with it: "pierogi z mięsem" is one dish to teach.
///    "na" and "w" split softly: after them only a food counts ("na maśle", "w sosie
///    pomidorowym"), the rest is how or where it was eaten ("na twardo", "w pracy").
/// 2. In each fragment the amount (2, 0,5, 1/2, ½, pół, trzy, 2 x 50) and the unit (g, dag, kg,
///    ml, l, łyżka, kromka, garść, talerz …) are read; the remaining words are the name. With no
///    amount at all she means one serving ("pierogi"); a count means pieces ("6 pierogów").
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

    /// Products she taught the app (`userFoods`) win over catalog products with the same alias.
    public init(catalog: FoodCatalog, userFoods: [FoodItem] = []) {
        var keys: [String] = []
        var entries: [String: (words: [String], item: FoodItem, isUserFood: Bool)] = [:]
        let sources: [(items: [FoodItem], isUserFood: Bool)] = [(catalog.items, false), (userFoods, true)]
        for source in sources {
            for item in source.items {
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
        for (order, key) in keys.enumerated() {
            if let entry = entries[key] {
                list.append(MealAlias(words: entry.words, item: entry.item, order: order))
            }
        }
        aliases = list
        joiningAliases = list.filter { alias in
            alias.words.count > 1 && alias.words.contains { MealWords.isProtectable($0.text) }
        }
        multiWordAliases = list.filter { $0.words.count > 1 }
    }

    public func parse(_ text: String) -> ParsedMeal {
        let meal = MealText(text)
        var items: [ParsedItem] = []
        var unknown: [String] = []
        var start = 0
        for k in 0...meal.tokens.count {
            if k == meal.tokens.count || meal.tokens[k].kind == .separator {
                if start < k {
                    parseChunk(meal, start..<k, items: &items, unknown: &unknown)
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

    private func parseChunk(_ meal: MealText, _ chunk: Range<Int>,
                            items: inout [ParsedItem], unknown: inout [String]) {
        let protected = protectedTokens(meal, chunk)
        for group in meal.split(chunk, at: MealWords.joining, keeping: protected) {
            let parts = meal.split(group, at: MealWords.splitting, keeping: protected)
            var i = 0
            while i < parts.count {
                let part = parts[i]
                // After "na" and "w" only a food counts, and no typo: "na miękko" is not a guess at a food.
                let soft = MealParser.isSoft(meal, parts, i)
                let head = analyze(meal, part, protected, allowingTypos: !soft)
                if head.nameTokens.isEmpty {
                    i += 1
                    continue
                }
                if let match = head.match {
                    items.append(makeItem(meal, part, head, match))
                    i += 1
                    continue
                }
                // "na twardo", "na śniadanie", "w pracy": how or where, not something to teach.
                if soft {
                    i += 1
                    continue
                }
                // An unknown head keeps what is said about it: "pierogi z mięsem" is one dish to teach,
                // not pierogi plus a portion of meat. A part with its own amount or unit is a food of its own.
                var last = part.upperBound
                var j = i + 1
                while j < parts.count {
                    if MealParser.isSoft(meal, parts, j) { break }
                    let following = analyze(meal, parts[j], protected, allowingTypos: true)
                    if following.quantity != nil || following.unit != nil { break }
                    if !parts[j].isEmpty { last = parts[j].upperBound }
                    j += 1
                }
                let name = meal.cleaned(part.lowerBound..<last)
                if name.filter({ $0.isLetter }).count >= 2 {
                    unknown.append(name)
                }
                i = j
            }
        }
    }

    /// Whether part `index` was split off at "na" or "w".
    private static func isSoft(_ meal: MealText, _ parts: [Range<Int>], _ index: Int) -> Bool {
        index > 0 && MealWords.softWords.contains(meal.tokens[parts[index].lowerBound - 1].norm)
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
                    protected.insert(words[s + t])
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

    // MARK: - One fragment

    private func analyze(_ meal: MealText, _ part: Range<Int>, _ protected: Set<Int>,
                         allowingTypos: Bool) -> MealAnalysis {
        var result = MealAnalysis()
        let end = part.upperBound
        var used = Set<Int>()          // tokens of the amount
        var unitToken: Int?            // the unit word right after the amount
        for k in part {
            guard let found = meal.quantity(at: k, end: end) else { continue }
            var value = found.value
            var after = found.next
            used.formUnion(k..<after)
            if meal.isUnit(after, end) {
                unitToken = after
                after += 1
            }
            // "2 x 50 g", "2x50g", "2 razy 50 g", "50 g x 2"
            if meal.isTimes(after, end), after + 1 < end, let second = meal.quantity(at: after + 1, end: end) {
                used.formUnion(after..<second.next)
                value *= second.value
                after = second.next
                if meal.isUnit(after, end) {
                    unitToken = after
                }
            }
            result.quantity = value
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
            if MealWords.units[word] != nil {
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
        } else if let first = looseUnits.first {
            result.unit = MealWords.units[meal.tokens[first].norm]
        }
        if !names.isEmpty {
            result.nameTokens = names
            result.match = bestMatch(names.map { meal.tokens[$0].norm }, allowingTypos: allowingTypos)
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
            // With no amount at all she means one serving: "pierogi" is a plateful, "6 pierogów" six pieces.
            var serving: Portion?
            if quantity == nil && item.defaultPortion.unit != .serving {
                serving = item.portions.first { $0.unit == .serving }
            }
            if let quantity, quantity > 20 {
                // A bare number above 20 is grams: "150 łososia".
                amount = quantity
                unit = nil
                grams = quantity
            } else if let serving {
                amount = 1
                unit = .serving
                grams = serving.grams
            } else {
                amount = quantity ?? 1
                unit = item.defaultPortion.unit
                grams = amount * item.defaultPortion.grams
            }
        }
        let first = meal.tokens[part.lowerBound].start
        let last = meal.tokens[part.upperBound - 1].end
        return ParsedItem(text: String(meal.chars[first..<last]), foodID: item.id, foodName: item.name,
                          amount: amount, unit: unit, grams: grams, macros: item.macros(grams: grams),
                          isGuess: match.quality == 1)
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
        if let stem = alias.vowelStem, hasEnding(word, after: stem, orNone: alias.bareStemIsWord) { return 2 }
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

    init(_ text: String) {
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

    init(words: [String], item: FoodItem, order: Int) {
        self.words = words.map { MealAliasWord($0) }
        self.item = item
        self.order = order
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
}

// MARK: - Tokens

private struct MealToken {
    enum Kind {
        case word, number, fraction, slash, percent, times, dash, separator, other
    }

    let kind: Kind
    /// A word, normalized with `FoodText.normalized`.
    var norm: String = ""
    /// The value of a number or a fraction sign.
    var value: Double = 0
    /// Character offsets in the original text.
    let start: Int
    let end: Int

    var isQuantity: Bool {
        kind == .number || kind == .fraction || (kind == .word && MealWords.numbers[norm] != nil)
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
            if c.isNewline || c == "," || c == ";" || c == "+" {
                tokens.append(MealToken(kind: .separator, start: i, end: i + 1))
                i += 1
            } else if c.isWhitespace {
                i += 1
            } else if MealText.isDigit(c) {
                var j = i
                while j < n && MealText.isDigit(chars[j]) { j += 1 }
                var digits = String(chars[i..<j])
                if j + 1 < n && (chars[j] == "," || chars[j] == ".") && MealText.isDigit(chars[j + 1]) {
                    var k = j + 1
                    while k < n && MealText.isDigit(chars[k]) { k += 1 }
                    digits += "." + String(chars[(j + 1)..<k])
                    j = k
                }
                tokens.append(MealToken(kind: .number, value: Double(digits) ?? 0, start: i, end: j))
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

    func isUnit(_ k: Int, _ end: Int) -> Bool {
        k < end && tokens[k].kind == .word && MealWords.units[tokens[k].norm] != nil
    }

    func isTimes(_ k: Int, _ end: Int) -> Bool {
        k < end && (tokens[k].kind == .times || (tokens[k].kind == .word && MealWords.times.contains(tokens[k].norm)))
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
    /// `next` is the token after it. nil when no amount starts there (also for "2%" and "2-3%").
    func quantity(at k: Int, end: Int) -> (value: Double, next: Int)? {
        let token = tokens[k]
        var value: Double
        var next: Int
        switch token.kind {
        case .number:
            if isPercentage(k, end) { return nil }
            if k + 2 < end && tokens[k + 1].kind == .slash && tokens[k + 2].kind == .number {
                if tokens[k + 2].value == 0 { return nil }
                return (token.value / tokens[k + 2].value, k + 3)
            }
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
            case .fraction, .slash, .times:
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
        ("dwa dwie dwoch dwoma dwom", 2),
        ("trzy trzech trzema", 3),
        ("cztery czterech czterema", 4),
        ("piec pieciu piecioma", 5),
        ("szesc szesciu szescioma", 6),
        ("siedem siedmiu siedmioma", 7),
        ("osiem osmiu osmioma", 8),
        ("dziewiec dziewieciu dziewiecioma", 9),
        ("dziesiec dziesieciu dziesiecioma", 10),
        ("pare paru", 2),
        ("kilka kilku", 3),
    ] as [(String, Double)])

    static let units: [String: MealUnit] = table([
        ("g gr gram gramy gramow grama", .grams(1)),
        ("dag dkg deko deka dekagram dekagramy dekagramow", .grams(10)),
        ("kg kilo kilogram kilograma kilogramy kilogramow", .grams(1000)),
        ("ml mililitr mililitra mililitry mililitrow", .grams(1)),
        ("l litr litra litry litrow", .grams(1000)),
        ("lyzka lyzki lyzek lyzke lyzkami lyz lyzce lyzkach", .portion(.tablespoon)),
        ("lyzeczka lyzeczki lyzeczek lyzeczke lyzeczkami lyzeczce", .portion(.teaspoon)),
        ("odrobina odrobiny odrobine", .portion(.teaspoon)),
        ("szklanka szklanki szklanek szklanke szklankami szklance", .portion(.glass)),
        ("kieliszek kieliszka kieliszki kieliszkow kieliszkiem lampka lampki lampke", .portion(.glass)),
        ("kubek kubka kubki kubkow kubkiem kubku", .portion(.mug)),
        ("kufel kufla kufle kuflem filizanka filizanki filizanke", .portion(.mug)),
        ("kromka kromki kromek kromke kromkami kromce kromkach", .portion(.slice)),
        ("plaster plastra plastry plastrow plastrem plastrami plastrze plastrach", .portion(.thinSlice)),
        ("plasterek plasterka plasterki plasterkow plasterkiem plasterkami", .portion(.thinSlice)),
        ("plasterku plasterkach", .portion(.thinSlice)),
        ("garsc garsci garscia garstka garstki garstke", .portion(.handful)),
        ("sztuka sztuki sztuk sztuke szt galka galki galek galke", .portion(.piece)),
        ("porcja porcje porcji porcjami", .portion(.serving)),
        ("miska miski misek miske misce miseczka miseczki miseczke", .portion(.bowl)),
        ("talerz talerza talerze talerzy talerzem talerzu", .portion(.bowl)),
        ("puszka puszki puszek puszke puszce butelka butelki butelek butelke", .portion(.can)),
        ("opakowanie opakowania opakowan opakowaniem opakowaniu paczka paczki paczek paczke", .portion(.package)),
        ("tabliczka tabliczki tabliczek tabliczke kubeczek kubeczka kubeczki", .portion(.package)),
        ("kawalek kawalka kawalki kawalkow kawalkiem kawalkami kawalku", .portion(.chunk)),
        ("kawaleczek kawaleczka kawaleczki", .portion(.chunk)),
        ("zabek zabka zabki zabkow zabkiem zabkami", .portion(.clove)),
    ] as [(String, MealUnit)])

    /// "2 x 50 g", "2 razy 50 g" (× and * are tokens of their own).
    static let times: Set<String> = ["x", "razy"]
    /// Words around an amount that are not part of the name: "ok. 100 g".
    static let filler: Set<String> = ["ok", "okolo"]
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
        "mikrofalowki", "ekspresu", "kranu",
    ]
    /// "kawa bez cukru": nothing after it was eaten.
    static let negation = "bez"
    /// Words that look like an inflected short alias but are other words (pora ≠ por, wódka ≠ woda,
    /// oliwki ≠ oliwa). They still match a product spelled exactly like them.
    static let falseFriends: Set<String> = ["pora", "wodka", "wodki", "oliwka", "oliwki", "oliwkami"]
    /// Polish endings of nouns and adjectives, normalized (ę → e, ą → a, ó → o).
    static let endings: Set<String> = [
        "a", "u", "y", "i", "e", "o", "em", "om", "ie", "ach", "ami", "ow", "owi", "ka", "ki", "kiem", "kami",
        "iem", "ia", "iu", "ej", "iej", "ego", "emu", "ym", "im", "ymi", "imi", "ych", "ich",
    ]
    /// Final vowels replaced by an ending: masło → masła.
    static let stemVowels: Set<Character> = ["a", "e", "o", "y", "i"]
    static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
    static let fractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]

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
