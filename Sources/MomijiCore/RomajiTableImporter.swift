public enum RomajiTableImportError: Error, Equatable, Sendable {
    case empty
    case invalidLine(lineNumber: Int)
}

public enum RomajiTableImporter {
    public static func convert(googleTSV: String) throws(RomajiTableImportError) -> String {
        var rows: [String] = []
        for (offset, rawLine) in googleTSV.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.hasSuffix("\r") ? rawLine.dropLast() : rawLine
            if line.allSatisfy(\.isWhitespace) {
                continue
            }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            switch columns.count {
            case 2:
                rows.append("\(escape(columns[0]))\t\(escape(columns[1]))")
            case 3:
                rows.append("\(escape(columns[0]))\t\(escape(columns[1]))\(escape(columns[2]))")
            default:
                throw .invalidLine(lineNumber: offset + 1)
            }
        }
        if rows.isEmpty {
            throw .empty
        }
        return rows.joined(separator: "\n")
    }

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
