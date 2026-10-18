import Foundation
import Testing
@testable import MomijiCore

private func rows(_ googleTSV: String) throws -> [Substring] {
    try RomajiTableImporter.convert(googleTSV: googleTSV).split(separator: "\n")
}

@Test func twoColumns() throws {
    #expect(try rows("ka\tか\n").first == "ka\tか")
}

@Test func threeColumnsAppendNext() throws {
    #expect(try rows("kk\tっ\tk").first == "kk\tっk")
}

@Test func escapesBraces() throws {
    #expect(try rows(";[\t{").first == ";[\t{lbracket}")
}

@Test func skipsBlankLines() throws {
    #expect(try rows("a\tあ\n\n\ni\tい").prefix(2) == ["a\tあ", "i\tい"])
}

@Test func addsSymbolsMissingFromTable() throws {
    let lines = try rows("a\tあ")
    #expect(lines.contains("?\t？"))
    #expect(lines.contains("!\t！"))
    #expect(lines.contains("/\t・"))
    #expect(lines.contains("-\tー"))
    #expect(lines.contains("{lbracket}\t｛"))
}

@Test func keepsSymbolsDefinedInTable() throws {
    let lines = try rows("-\t－")
    #expect(lines.contains("-\t－"))
    #expect(!lines.contains("-\tー"))
}

@Test func symbolAfterPrefixIsConverted() throws {
    let lines = try rows("n\tん\nna\tな")
    #expect(lines.contains("n-\tんー"))
    #expect(lines.contains("n?\tん？"))
}

@Test func symbolUsedAsPrefixFallsBackToFullWidth() throws {
    let lines = try rows(";h\t←")
    #expect(lines.contains(";h\t←"))
    #expect(lines.contains(";a\t；a"))
    #expect(lines.contains(";{composition-separator}\t；"))
}

@Test func invalidLine() {
    #expect(throws: RomajiTableImportError.invalidLine(lineNumber: 2)) {
        try RomajiTableImporter.convert(googleTSV: "a\tあ\nbad")
    }
}

@Test func emptyTable() {
    #expect(throws: RomajiTableImportError.empty) {
        try RomajiTableImporter.convert(googleTSV: "\n\n")
    }
}

@Test func dvorakFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "dvorak_jp", withExtension: "tsv", subdirectory: "Fixtures"))
    let tsv = try String(contentsOf: url, encoding: .utf8)
    let lines = try RomajiTableImporter.convert(googleTSV: tsv).split(separator: "\n")
    #expect(lines.contains("cc\tっc"))
    #expect(lines.contains(";h\t←"))
    #expect(!lines.contains { $0.split(separator: "\t", omittingEmptySubsequences: false).count != 2 })
}

@Test func prefixRowWaitsForNextInput() throws {
    let lines = try RomajiTableImporter.convert(googleTSV: "n\tん\nna\tな\nnya\tにゃ").split(separator: "\n")
    #expect(lines.contains("nb\tんb"))
    #expect(lines.contains("n{composition-separator}\tん"))
    #expect(!lines.contains("na\tんa"))
    #expect(!lines.contains("ny\tんy"))
    #expect(!lines.contains { $0.contains("{any character}") })
}
