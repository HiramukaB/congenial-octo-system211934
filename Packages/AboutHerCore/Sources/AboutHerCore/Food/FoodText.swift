/// Text normalisation shared by the meal parser and the product catalog.
public enum FoodText {
    private static let folding: [Character: Character] = [
        "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z", "ż": "z",
    ]

    /// Lowercased, Polish letters folded to ASCII (ą→a, ć→c, ę→e, ł→l, ń→n, ó→o, ś→s, ź→z, ż→z),
    /// runs of whitespace collapsed to one space, trimmed. Digits and punctuation are kept.
    /// Written out by hand instead of relying on Unicode folding, so it behaves the same on
    /// iOS and Linux (and "ł", which has no decomposition, is folded too).
    public static func normalized(_ text: String) -> String {
        var result = ""
        var pendingSpace = false
        for character in text.lowercased() {
            if character.isWhitespace {
                pendingSpace = !result.isEmpty
                continue
            }
            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(folding[character] ?? character)
        }
        return result
    }
}
