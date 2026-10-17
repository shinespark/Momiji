import Foundation

public struct MomijiSettings: Codable, Equatable, Sendable {
    public var selectionKeyLayout: SelectionKeyLayout = .dvorak
    public var zenzaiEnabled = true
    public var suggestionEnabled = true
    public var romajiTableName: String?

    private static let key = "settings"

    public init() {}

    public static func load(from defaults: UserDefaults) -> MomijiSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(MomijiSettings.self, from: data) else {
            return MomijiSettings()
        }
        return settings
    }

    public func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

public extension Notification.Name {
    static let momijiSettingsDidChange = Notification.Name("dev.shinespark.Momiji.settingsDidChange")
}
