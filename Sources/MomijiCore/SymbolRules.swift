import Foundation

public enum SymbolRules {
    static let symbols: [Character] = (0x21...0x7E)
        .compactMap { Unicode.Scalar($0).map(Character.init) }
        .filter { !$0.isLetter && !$0.isNumber }

    private static let japaneseForms: [Character: String] = [
        "-": "ー", "~": "〜", ".": "。", ",": "、", "[": "「", "]": "」", "/": "・",
        "\"": "”", "'": "’",
    ]

    public static func output(for character: Character) -> String? {
        guard symbols.contains(character) else { return nil }
        if let form = japaneseForms[character] { return form }
        return String(character).applyingTransform(.fullwidthToHalfwidth, reverse: true)
    }

    public static func symbol(for output: Character) -> Character? {
        symbols.first { self.output(for: $0) == String(output) }
    }
}
