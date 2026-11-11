import Foundation

/// Her first steps in the app: the name she wants to be called by, when she finished the welcome
/// steps and whether she has seen the short guide to the app.
///
/// Empty until she goes through them – also in every file from before schema 4, so data she has
/// already logged meets the welcome once, with its steps filled in from that data.
public struct OnboardingState: Codable, Sendable, Hashable {
    /// How she wants to be addressed; nil when she left it empty.
    public var name: String?
    /// When she finished the welcome steps; nil until then.
    public var completedAt: Date?
    /// She has seen the short guide to the app, or skipped it.
    public var hasSeenTutorial: Bool

    /// A blank `name` is stored as nil.
    public init(name: String? = nil, completedAt: Date? = nil, hasSeenTutorial: Bool = false) {
        self.name = OnboardingState.cleanName(name)
        self.completedAt = completedAt
        self.hasSeenTutorial = hasSeenTutorial
    }

    /// She has finished the welcome steps.
    public var isCompleted: Bool {
        completedAt != nil
    }

    /// `name` without spaces around it; nil when nothing is left.
    public static func cleanName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    enum CodingKeys: String, CodingKey {
        case name, completedAt, hasSeenTutorial
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try container.decodeIfPresent(String.self, forKey: .name),
                  completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt),
                  hasSeenTutorial: try container.decodeIfPresent(Bool.self, forKey: .hasSeenTutorial) ?? false)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(hasSeenTutorial, forKey: .hasSeenTutorial)
    }
}
