import Foundation
import Testing
@testable import MomijiCore

@Test func twoColumns() throws {
    #expect(try RomajiTableImporter.convert(googleTSV: "ka\tか\n") == "ka\tか")
}

@Test func threeColumnsAppendNext() throws {
    #expect(try RomajiTableImporter.convert(googleTSV: "kk\tっ\tk") == "kk\tっk")
}

@Test func escapesBraces() throws {
    #expect(try RomajiTableImporter.convert(googleTSV: ";[\t{") == ";[\t{lbracket}")
}

@Test func skipsBlankLines() throws {
    #expect(try RomajiTableImporter.convert(googleTSV: "a\tあ\n\n\ni\tい") == "a\tあ\ni\tい")
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
