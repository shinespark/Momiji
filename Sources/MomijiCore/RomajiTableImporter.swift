public enum RomajiTableImportError: Error, Equatable, Sendable {
    case empty
    case invalidLine(lineNumber: Int)
}

public enum RomajiTableImporter {
    public static func convert(googleTSV: String) throws(RomajiTableImportError) -> String {
        var rules: [(input: Substring, output: String, waitsForNext: Bool)] = []
        for (offset, rawLine) in googleTSV.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.hasSuffix("\r") ? rawLine.dropLast() : rawLine
            if line.allSatisfy(\.isWhitespace) {
                continue
            }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            switch columns.count {
            case 2:
                rules.append((columns[0], escape(columns[1]), false))
            case 3:
                rules.append((columns[0], escape(columns[1]) + escape(columns[2]), true))
            default:
                throw .invalidLine(lineNumber: offset + 1)
            }
        }
        if rules.isEmpty {
            throw .empty
        }
        let inputs = rules.map(\.input)
        var rows: [String] = []
        for rule in rules {
            let input = escape(rule.input)
            let isPrefixOfAnother = !rule.waitsForNext && inputs.contains { $0.count > rule.input.count && $0.hasPrefix(rule.input) }
            if isPrefixOfAnother {
                for next in followingCharacters where !inputs.contains(where: { $0.hasPrefix(rule.input + String(next)) }) {
                    let nextText = escape(Substring(String(next)))
                    rows.append("\(input)\(nextText)\t\(rule.output)\(nextText)")
                }
                rows.append("\(input){composition-separator}\t\(rule.output)")
            } else {
                rows.append("\(input)\t\(rule.output)")
            }
        }
        return rows.joined(separator: "\n")
    }

    private static let followingCharacters: [Character] = (0x21...0x7E).compactMap { Unicode.Scalar($0).map(Character.init) }

    private static func escape(_ text: Substring) -> String {
        var result = ""
        for character in text {
            switch character {
            case "{": result += "{lbracket}"
            case "}": result += "{rbracket}"
            default: result.append(character)
            }
        }
        return result
    }
}
