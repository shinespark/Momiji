import Foundation
import Testing
@testable import MomijiCore

private func freshDefaults() -> UserDefaults {
    let name = "momiji-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeFile(_ text: String, name: String = "table.tsv") -> URL {
    let url = temporaryDirectory().appendingPathComponent(name)
    try! text.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@Test func settingsDefaults() {
    let settings = MomijiSettings.load(from: freshDefaults())
    #expect(settings.selectionKeyLayout == .dvorak)
    #expect(settings.zenzaiEnabled)
    #expect(settings.suggestionEnabled)
    #expect(settings.romajiTableName == nil)
}

@Test func settingsRoundTrip() {
    let defaults = freshDefaults()
    var settings = MomijiSettings()
    settings.selectionKeyLayout = .qwerty
    settings.zenzaiEnabled = false
    settings.save(to: defaults)
    #expect(MomijiSettings.load(from: defaults) == settings)
}

@Test func importCopiesTable() throws {
    let store = RomajiTableStore(directory: temporaryDirectory())
    let source = writeFile("ka\tか", name: "dvorak_jp.tsv")
    #expect(try store.importTable(from: source) == "dvorak_jp.tsv")
    try FileManager.default.removeItem(at: source)
    #expect(store.loadAzooKeyTSV() == "ka\tか")
}

@Test func failedImportKeepsOld() throws {
    let store = RomajiTableStore(directory: temporaryDirectory())
    _ = try store.importTable(from: writeFile("ka\tか"))
    #expect(throws: RomajiTableImportError.invalidLine(lineNumber: 1)) {
        try store.importTable(from: writeFile("bad"))
    }
    #expect(store.loadAzooKeyTSV() == "ka\tか")
}

@Test func resetRemovesTable() throws {
    let store = RomajiTableStore(directory: temporaryDirectory())
    _ = try store.importTable(from: writeFile("ka\tか"))
    store.reset()
    #expect(store.loadAzooKeyTSV() == nil)
}
