import Foundation
import Testing
import MomijiCore
@testable import MomijiConverter

private let dvorakFixture: String = {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../MomijiCoreTests/Fixtures/dvorak_jp.tsv")
    let tsv = try! String(contentsOf: url, encoding: .utf8)
    return try! RomajiTableImporter.convert(googleTSV: tsv)
}()

private func backend(table: String?) -> AzooKeyBackend {
    let memory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: memory, withIntermediateDirectories: true)
    return AzooKeyBackend(configuration: .init(romajiTableTSV: table, zenzaiModelURL: nil, memoryDirectoryURL: memory))
}

// AzooKey の InputStyleManager.shared を共有するため、並列に走らせるとクラッシュする
@Suite(.serialized) struct AzooKeyBackendTests {
    @Test func dvorakTableReading() {
        let b = backend(table: dvorakFixture)
        b.insert("cana")
        #expect(b.reading == "かな")
    }

    @Test func semicolonSymbol() {
        let b = backend(table: dvorakFixture)
        b.insert(";h")
        #expect(b.reading == "←")
    }

    @Test func semicolonDiphthong() {
        let b = backend(table: dvorakFixture)
        b.insert("ch;neru")
        #expect(b.reading == "ちゃんねる")
    }

    @Test func trailingN() {
        let b = backend(table: nil)
        b.insert("kan")
        #expect(b.readingForConversion() == "かん")
    }

    @Test func convertsKanji() {
        let b = backend(table: nil)
        b.insert("kanji")
        b.moveCursorToEnd()
        #expect(b.candidates().contains { $0.text == "漢字" })
    }

    @Test func commitPrefixLeavesRest() throws {
        let b = backend(table: nil)
        b.insert("kanjihenkan")
        b.prepareForConversion()
        b.moveCursorToStart()
        b.moveCursor(by: 3)
        let c = try #require(b.candidates().first { $0.text == "漢字" })
        b.commit(c)
        #expect(b.reading == "へんかん")
    }

    @Test func predictionsExtendReading() {
        let b = backend(table: nil)
        b.insert("arigat")
        #expect(b.predictions(useZenzai: false).contains { $0.text.hasPrefix("ありがとう") })
    }

    @Test func prepareForConversionFinishesN() {
        let b = backend(table: dvorakFixture)
        b.insert("kan")
        b.prepareForConversion()
        #expect(b.reading == "かん")
    }

    @Test func committingPredictionConsumesReading() throws {
        let b = backend(table: nil)
        b.insert("arigat")
        let prediction = try #require(b.predictions(useZenzai: false).first { $0.text.hasPrefix("ありがとう") })
        b.commit(prediction)
        #expect(b.reading.isEmpty)
    }

    @Test func nyaInDvorakTable() {
        let b = backend(table: dvorakFixture)
        b.insert("nya")
        #expect(b.reading == "にゃ")
    }

    @Test func nhuInDvorakTable() {
        let b = backend(table: dvorakFixture)
        b.insert("nhu")
        #expect(b.reading == "にゅ")
    }

    @Test func nBeforeConsonantInDvorakTable() {
        let b = backend(table: dvorakFixture)
        b.insert("nba")
        #expect(b.reading == "んば")
    }

    @Test func candidatesStayWithinCursorWithoutZenzai() {
        let b = backend(table: nil)
        b.insert("kanjihenkan")
        b.prepareForConversion()
        b.moveCursorToStart()
        b.moveCursor(by: 6)
        let candidates = b.candidates()
        #expect(!candidates.isEmpty)
        #expect(candidates.allSatisfy { $0.readingCount <= 6 })
        #expect(candidates.contains { $0.readingCount == 6 })
    }

    @Test func bestConversionOfRest() {
        let b = backend(table: nil)
        b.insert("kanjihenkan")
        b.prepareForConversion()
        #expect(b.bestConversion(ofReadingFrom: 3) == "変換")
        #expect(b.reading == "かんじへんかん")
    }
}
