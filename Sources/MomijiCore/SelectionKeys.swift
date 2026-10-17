public enum SelectionKeyLayout: String, Codable, CaseIterable, Sendable {
    case dvorak
    case qwerty
}

public enum SelectionKeys {
    private static let digits = Array("1234567890")

    public static func labels(for layout: SelectionKeyLayout) -> [Character] {
        switch layout {
        case .dvorak: Array("aoeuidhtns")
        case .qwerty: Array("asdfghjkl;")
        }
    }

    public static func index(of character: Character, layout: SelectionKeyLayout) -> Int? {
        labels(for: layout).firstIndex(of: character) ?? digits.firstIndex(of: character)
    }
}
