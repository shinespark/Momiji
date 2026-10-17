import Foundation

public struct RomajiTableStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var fileURL: URL {
        directory.appendingPathComponent("romaji_table.tsv")
    }

    public func importTable(from fileURL: URL) throws -> String {
        let converted = try RomajiTableImporter.convert(googleTSV: String(contentsOf: fileURL, encoding: .utf8))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try converted.write(to: self.fileURL, atomically: true, encoding: .utf8)
        return fileURL.lastPathComponent
    }

    public func loadAzooKeyTSV() -> String? {
        try? String(contentsOf: fileURL, encoding: .utf8)
    }

    public func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
