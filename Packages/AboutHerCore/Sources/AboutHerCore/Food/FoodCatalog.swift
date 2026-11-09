import Foundation

/// The built-in product list (Resources/FoodDB.json) – read-only, shipped with the app.
/// Products she teaches the app live in her own data file and are passed to the parser separately.
public struct FoodCatalog: Sendable {
    public let items: [FoodItem]

    public init(items: [FoodItem]) {
        self.items = items
    }

    public func item(id: String) -> FoodItem? {
        items.first { $0.id == id }
    }

    /// The bundled catalog. Loaded once; empty only if the resource is missing (a build error).
    public static let builtIn: FoodCatalog = {
        guard let url = Bundle.module.url(forResource: "FoodDB", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(FoodCatalogFile.self, from: raw)
        else {
            assertionFailure("FoodDB.json is missing or invalid")
            return FoodCatalog(items: [])
        }
        return FoodCatalog(items: file.items)
    }()
}

/// The layout of FoodDB.json.
public struct FoodCatalogFile: Codable, Sendable {
    public var version: Int
    public var items: [FoodItem]

    public init(version: Int, items: [FoodItem]) {
        self.version = version
        self.items = items
    }
}
