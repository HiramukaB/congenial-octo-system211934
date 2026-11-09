import Foundation

/// Everything she logs. Stored as one JSON file; this same file is the backup format.
///
/// Every field decodes with a default, so files written by older versions keep loading
/// when new fields are added.
public struct AppData: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Days she marked as bleeding.
    public var periodDays: Set<LocalDate>

    public init(periodDays: Set<LocalDate> = []) {
        self.schemaVersion = AppData.currentSchemaVersion
        self.periodDays = periodDays
    }

    public mutating func togglePeriodDay(_ date: LocalDate) {
        if periodDays.contains(date) {
            periodDays.remove(date)
        } else {
            periodDays.insert(date)
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, periodDays
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? AppData.currentSchemaVersion
        periodDays = Set(try container.decodeIfPresent([LocalDate].self, forKey: .periodDays) ?? [])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        // Sorted, so backups are readable and compare cleanly.
        try container.encode(periodDays.sorted(), forKey: .periodDays)
    }
}

public enum AppDataCoding {
    public static func encode(_ appData: AppData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(appData)
    }

    public static func decode(_ raw: Data) throws -> AppData {
        try JSONDecoder().decode(AppData.self, from: raw)
    }

    /// True when the file was written by a newer version of the app: a higher schema version,
    /// or fields this version doesn't know. Such a file must never be saved back by this
    /// version, because the unknown fields would be lost.
    public static func isFromNewerVersion(_ raw: Data) -> Bool {
        guard let topLevel = try? JSONDecoder().decode(TopLevelKeys.self, from: raw) else { return false }
        if let version = topLevel.schemaVersion, version > AppData.currentSchemaVersion {
            return true
        }
        let known = Set(AppData.CodingKeys.allCases.map(\.rawValue))
        return !topLevel.keys.isSubset(of: known)
    }

    private struct TopLevelKeys: Decodable {
        let keys: Set<String>
        let schemaVersion: Int?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: AnyKey.self)
            keys = Set(container.allKeys.map(\.stringValue))
            schemaVersion = try? container.decode(Int.self, forKey: AnyKey(stringValue: "schemaVersion"))
        }
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }
}
