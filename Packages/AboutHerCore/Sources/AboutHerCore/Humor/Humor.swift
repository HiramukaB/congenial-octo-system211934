import Foundation

/// Something that makes her smile – a joke, a quote, anything else – kept to come back to on a
/// heavier day.
public struct HumorItem: Codable, Sendable, Hashable, Identifiable {
    /// Raw values are stable keys for her data file.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// żart
        case joke
        /// cytat
        case quote
        /// coś innego
        case other
    }

    public var id: UUID
    public var text: String
    public var kind: Kind
    /// Who said or wrote it, or where it comes from; nil when she didn't say.
    public var source: String?
    /// When she added it.
    public var createdAt: Date
    /// She marked it as a favourite.
    public var isFavorite: Bool

    /// A blank `source` is stored as nil.
    public init(id: UUID = UUID(), text: String, kind: Kind, source: String? = nil, createdAt: Date = Date(),
                isFavorite: Bool = false) {
        self.id = id
        self.text = text
        self.kind = kind
        self.source = HumorItem.cleanSource(source)
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }

    /// `source` without spaces around it; nil when nothing is left.
    public static func cleanSource(_ source: String?) -> String? {
        guard let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    enum CodingKeys: String, CodingKey {
        case id, text, kind, source, createdAt, isFavorite
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(UUID.self, forKey: .id),
                  text: try container.decode(String.self, forKey: .text),
                  kind: try container.decode(Kind.self, forKey: .kind),
                  source: try container.decodeIfPresent(String.self, forKey: .source),
                  createdAt: try container.decode(Date.self, forKey: .createdAt),
                  isFavorite: try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isFavorite, forKey: .isFavorite)
    }
}

extension AppData {
    /// Her jokes and quotes, the newest first.
    public var humorNewestFirst: [HumorItem] {
        Array(humor.reversed())
    }

    /// Adds `item`, or – when one with its id is already there – replaces its text, kind, source
    /// and favourite mark. It keeps its place and the time it was added.
    public mutating func saveHumor(_ item: HumorItem) {
        guard let index = humor.firstIndex(where: { $0.id == item.id }) else {
            humor.append(item)
            return
        }
        var updated = item
        updated.createdAt = humor[index].createdAt
        humor[index] = updated
    }

    public mutating func setHumorFavorite(id: UUID, _ isFavorite: Bool) {
        guard let index = humor.firstIndex(where: { $0.id == id }) else { return }
        humor[index].isFavorite = isFavorite
    }

    public mutating func removeHumor(id: UUID) {
        humor.removeAll { $0.id == id }
    }

    /// The joke or quote for `day`: another one each day, in turn, and her favourites twice as
    /// often. nil while she has none.
    public func humorItem(for day: LocalDate) -> HumorItem? {
        let pool = humor + humor.filter(\.isFavorite)
        guard !pool.isEmpty else { return nil }
        let index = day.julianDay % pool.count
        return pool[index < 0 ? index + pool.count : index]
    }
}
