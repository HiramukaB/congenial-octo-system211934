import Foundation

/// One thing she logged as eaten: what she typed and what the parser made of it.
/// The text is kept, so the entry can be parsed again after she teaches the app a product.
public struct MealEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var text: String
    public var items: [ParsedItem]
    /// Parts of the text no product matched (cleaned of quantities), shown as "nie znam jeszcze: …".
    public var unknown: [String]
    public var totals: Macros

    public init(id: UUID = UUID(), createdAt: Date = Date(), text: String, parsed: ParsedMeal) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.items = parsed.items
        self.unknown = parsed.unknown
        self.totals = parsed.totals
    }

    /// The same entry, parsed again (e.g. after she taught the app a product).
    public func reparsed(with parser: MealParser) -> MealEntry {
        var entry = self
        entry.update(text: text, parsed: parser.parse(text))
        return entry
    }

    /// Replaces what she typed and what it was parsed into; the id and the time stay.
    public mutating func update(text: String, parsed: ParsedMeal) {
        self.text = text
        items = parsed.items
        unknown = parsed.unknown
        totals = parsed.totals
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, text, items, unknown, totals
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        let decodedItems = try container.decodeIfPresent([ParsedItem].self, forKey: .items) ?? []
        items = decodedItems
        unknown = try container.decodeIfPresent([String].self, forKey: .unknown) ?? []
        totals = try container.decodeIfPresent(Macros.self, forKey: .totals) ?? decodedItems.map(\.macros).sum()
    }
}

/// Glasses of water in the three parts of the day.
public struct WaterDay: Codable, Sendable, Hashable {
    public enum Slot: String, Codable, Sendable, CaseIterable {
        case morning, midday, evening
    }

    /// About 2 litres: a guide, not a norm to tick off.
    public static let goalGlasses = 8

    public var morning: Int
    public var midday: Int
    public var evening: Int

    public init(morning: Int = 0, midday: Int = 0, evening: Int = 0) {
        self.morning = morning
        self.midday = midday
        self.evening = evening
    }

    public var total: Int { morning + midday + evening }

    public func count(in slot: Slot) -> Int {
        switch slot {
        case .morning: morning
        case .midday: midday
        case .evening: evening
        }
    }

    /// Adds (or with a negative delta removes) glasses; a slot never goes below zero.
    public mutating func add(_ delta: Int, to slot: Slot) {
        switch slot {
        case .morning: morning = Swift.max(0, morning + delta)
        case .midday: midday = Swift.max(0, midday + delta)
        case .evening: evening = Swift.max(0, evening + delta)
        }
    }

    enum CodingKeys: String, CodingKey {
        case morning, midday, evening
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        morning = try container.decodeIfPresent(Int.self, forKey: .morning) ?? 0
        midday = try container.decodeIfPresent(Int.self, forKey: .midday) ?? 0
        evening = try container.decodeIfPresent(Int.self, forKey: .evening) ?? 0
    }
}
