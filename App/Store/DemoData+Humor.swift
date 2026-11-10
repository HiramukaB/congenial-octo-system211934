import Foundation
import AboutHerCore

extension DemoData {
    /// Six short, light entries written for the demo – jokes, quotes and something else, oldest
    /// first. One quote is the made-up Ola's own words and her favourite; the newest is from today.
    static func addHumor(to data: inout AppData, now: Date) {
        let day: TimeInterval = 24 * 60 * 60
        data.humor = [
            HumorItem(text: "Nie wszystko musi być zrobione dziś. Niektóre rzeczy mogą spokojnie poczekać do jutra, a potem do pojutrza.",
                      kind: .quote,
                      source: "kartka z lodówki",
                      createdAt: now.addingTimeInterval(-12 * day)),
            HumorItem(text: "Zrobiłam dziś listę rzeczy do zrobienia. Pierwszy punkt już odhaczony: zrobić listę.",
                      kind: .joke,
                      createdAt: now.addingTimeInterval(-9 * day)),
            HumorItem(text: "Mówią, że śmiech to zdrowie. Dlatego dziś śmiałam się z siebie trzy razy – profilaktycznie.",
                      kind: .joke,
                      createdAt: now.addingTimeInterval(-6 * day)),
            HumorItem(text: "Herbata nie rozwiąże wszystkich problemów, ale daje im chwilę, żeby rozwiązały się same.",
                      kind: .quote,
                      source: "Ola",
                      createdAt: now.addingTimeInterval(-4 * day),
                      isFavorite: true),
            HumorItem(text: "Wyjście na spacer: minuta. Szukanie drugiej rękawiczki: dwanaście minut.",
                      kind: .other,
                      createdAt: now.addingTimeInterval(-1 * day)),
            HumorItem(text: "Plan na dziś: nie mieć planu i trzymać się go bardzo konsekwentnie.",
                      kind: .other,
                      createdAt: now.addingTimeInterval(-2 * 60 * 60)),
        ]
    }
}
