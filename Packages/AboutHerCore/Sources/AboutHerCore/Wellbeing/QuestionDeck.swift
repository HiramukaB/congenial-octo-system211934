import Foundation

/// The question cards of "chwila dla siebie": short, open questions to sit with in a meditation or
/// over a cup of tea – about the body, rest, boundaries, joy, change, the people close to her,
/// gratitude, dreams and the cycle. Written for this app.
///
/// Cards come from an endless run of shuffled rounds. Every round holds each question once, in its
/// own order, so no card comes back before the whole deck has been drawn. Where she is in the deck
/// is a single number, so that is all the app has to remember.
public enum QuestionDeck {
    public static let questions = [
        // The body
        "co mówi Ci dziś Twoje ciało, kiedy na chwilę się zatrzymasz?",
        "w którym miejscu ciała czujesz teraz najwięcej spokoju?",
        "gdzie w ciele nosisz dziś napięcie i co pomogłoby mu odpłynąć?",
        "za co chciałabyś dziś podziękować swoim dłoniom?",
        "przy jakim ruchu czujesz, że Twoje ciało się cieszy?",
        "co Twoje ciało robi dla Ciebie każdego dnia, choć rzadko to zauważasz?",
        "czego Twoje ciało potrzebuje dziś bardziej niż zwykle?",
        // Rest
        "jak wygląda odpoczynek, po którym naprawdę czujesz się lżej?",
        "co mogłabyś dziś odłożyć na później bez żadnej straty?",
        "kiedy ostatnio pozwoliłaś sobie zwyczajnie nic nie robić?",
        "która chwila dnia należy tylko do Ciebie?",
        "co pomaga Ci spokojnie zasnąć?",
        "w jakiej ciszy najlepiej Ci się myśli?",
        "gdzie czujesz się najbezpieczniej, kiedy jesteś zmęczona?",
        // Boundaries
        "na co chciałabyś częściej odpowiadać „nie”?",
        "czego dziś nie musisz brać na siebie?",
        "po czym poznajesz, że czegoś jest dla Ciebie za dużo?",
        "jakie „tak” mówisz z przyzwyczajenia, a nie z chęci?",
        "kiedy ostatnio postawiłaś siebie na pierwszym miejscu?",
        "ile miejsca w swoim tygodniu chcesz zostawić tylko dla siebie?",
        "co chroni Twój spokój?",
        // Joy
        "co ostatnio rozbawiło Cię do łez?",
        "jaki drobiazg potrafi poprawić Ci cały dzień?",
        "co robiłaś jako dziewczynka z największą radością?",
        "jaki zapach przywołuje w Tobie dobre wspomnienie?",
        "przy jakim zajęciu zapominasz o upływie czasu?",
        "jaka piosenka zawsze poprawia Ci nastrój?",
        "z jakiej drobnej przyjemności nie chciałabyś nigdy rezygnować?",
        // Change
        "co zmieniło się w Tobie w ostatnim roku, choć nikt tego nie widzi?",
        "czego ostatnio dowiedziałaś się o sobie?",
        "jaki mały krok jest dziś w zasięgu Twojej ręki?",
        "co chcesz zostawić za sobą, a co zabrać ze sobą dalej?",
        "która decyzja z przeszłości okazała się dla Ciebie najlepsza?",
        "na co dałabyś sobie zgodę, gdybyś przestała czekać na idealny moment?",
        "co powiedziałaby Ci Ty sprzed roku, gdyby zobaczyła Cię dziś?",
        // The people close to her
        "przy kim nie musisz niczego udawać?",
        "komu chciałabyś dziś podziękować, choćby w myślach?",
        "czego nauczyła Cię bliska Ci osoba?",
        "co najbardziej cenisz w ludziach, którymi się otaczasz?",
        "jak okazujesz troskę, a jak najchętniej ją przyjmujesz?",
        "czyje słowa dodają Ci sił, gdy jest trudniej?",
        "z kim chciałabyś spędzać więcej czasu?",
        // Gratitude
        "za jakie trzy drobiazgi z dzisiaj jesteś wdzięczna?",
        "co dobrego wydarzyło się ostatnio, choć ledwo to zauważyłaś?",
        "za co jesteś wdzięczna sobie sprzed lat?",
        "co masz dziś, o czym kiedyś tylko marzyłaś?",
        "jaki widok, dźwięk albo smak ucieszył Cię ostatnio?",
        "czyja życzliwość została z Tobą na długo?",
        "który zwyczajny moment dnia chciałabyś zatrzymać na dłużej?",
        // Dreams
        "o czym marzysz, kiedy nikt nie pyta?",
        "jakie marzenie z dzieciństwa wciąż w Tobie mieszka?",
        "jakie miejsce chciałabyś kiedyś zobaczyć i co Cię w nim przyciąga?",
        "czego chcesz więcej w swoim życiu, a czego mniej?",
        "co chciałabyś stworzyć własnymi rękami?",
        "jaką siebie chciałabyś spotkać za dziesięć lat?",
        // The cycle
        "jak zmienia się Twoja energia w ciągu miesiąca?",
        "w której części cyklu czujesz się najsilniejsza?",
        "czego potrzebujesz od siebie w dni okresu?",
        "jak możesz dziś zadbać o siebie, słuchając tego, co czujesz?",
        "co chciałabyś, żeby bliscy wiedzieli o Twoich trudniejszych dniach?",
    ]

    /// The card at `position`; 0 is the very first card she draws. Negative positions count as 0.
    public static func question(at position: Int) -> String {
        let count = questions.count
        guard count > 0 else { return "" }
        let position = Swift.max(0, position)
        let round = order(ofRound: position / count)
        return questions[round[position % count]]
    }

    /// Which card of its round the card at `position` is: 1 … `questions.count`.
    public static func cardNumber(at position: Int) -> Int {
        let count = questions.count
        guard count > 0 else { return 0 }
        return Swift.max(0, position) % count + 1
    }

    /// The order of one round: every index of `questions` once. A round never starts with the card
    /// the round before it ended on, so no card shows twice in a row.
    static func order(ofRound round: Int) -> [Int] {
        var indices = shuffledIndices(seed: round)
        if round > 0, indices.count > 2, indices.first == shuffledIndices(seed: round - 1).last {
            indices.swapAt(0, 1)
        }
        return indices
    }

    /// A Fisher–Yates shuffle driven by SplitMix64: the same order on every device and with every
    /// Swift version, so it never has to be stored.
    private static func shuffledIndices(seed: Int) -> [Int] {
        var indices = Array(questions.indices)
        var random = DeckRandom(seed: UInt64(truncatingIfNeeded: seed))
        var index = indices.count - 1
        while index > 0 {
            let other = Int(random.next() % UInt64(index + 1))
            indices.swapAt(index, other)
            index -= 1
        }
        return indices
    }
}

/// SplitMix64, seeded by the round of the deck.
private struct DeckRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x2545_F491_4F6C_DD1D &+ 0x5DEE_CE66_D
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
