public struct KeyInput: Equatable, Sendable {
    public enum Key: Equatable, Hashable, Sendable {
        case character(Character)
        case space, enter, escape, tab, backspace, delete
        case left, right, up, down, home, end, pageUp, pageDown
        case function(Int)
    }

    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let shift = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public let key: Key
    public let modifiers: Modifiers

    public init(key: Key, modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    private static let specialKeys: [UInt16: Key] = [
        36: .enter, 76: .enter, 48: .tab, 49: .space, 51: .backspace, 53: .escape, 117: .delete,
        115: .home, 119: .end, 116: .pageUp, 121: .pageDown,
        123: .left, 124: .right, 125: .down, 126: .up,
        122: .function(1), 120: .function(2), 99: .function(3), 118: .function(4), 96: .function(5),
        97: .function(6), 98: .function(7), 100: .function(8), 101: .function(9), 109: .function(10),
    ]

    public static func make(keyCode: UInt16, charactersIgnoringModifiers: String?, modifiers: Modifiers) -> KeyInput? {
        if let key = specialKeys[keyCode] {
            return KeyInput(key: key, modifiers: modifiers)
        }
        guard let character = charactersIgnoringModifiers?.first else {
            return nil
        }
        return KeyInput(key: .character(character), modifiers: modifiers)
    }
}
