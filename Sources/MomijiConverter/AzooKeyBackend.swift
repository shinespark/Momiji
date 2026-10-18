import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary
import MomijiCore

public final class AzooKeyBackend: ConversionBackend {
    public struct Configuration: Sendable {
        public var romajiTableTSV: String?
        public var zenzaiModelURL: URL?
        public var memoryDirectoryURL: URL

        public init(romajiTableTSV: String?, zenzaiModelURL: URL?, memoryDirectoryURL: URL) {
            self.romajiTableTSV = romajiTableTSV
            self.zenzaiModelURL = zenzaiModelURL
            self.memoryDirectoryURL = memoryDirectoryURL
        }
    }

    private static let tableName = "dev.shinespark.Momiji.romaji"

    public var configuration: Configuration {
        didSet { applyConfiguration() }
    }

    private let converter = KanaKanjiConverter.withDefaultDictionary()
    private var composingText = ComposingText()
    private var inputStyle: InputStyle = .roman2kana
    private var lastCandidates: [Candidate] = []

    public init(configuration: Configuration) {
        self.configuration = configuration
        applyConfiguration()
    }

    private func applyConfiguration() {
        if let tsv = configuration.romajiTableTSV, let table = Self.loadTable(tsv: tsv) {
            InputStyleManager.registerInputStyle(table: table, for: Self.tableName)
            inputStyle = .mapped(id: .tableName(Self.tableName))
        } else {
            inputStyle = .roman2kana
        }
    }

    private static func loadTable(tsv: String) -> InputTable? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("momiji-\(UUID().uuidString).tsv")
        defer { try? FileManager.default.removeItem(at: url) }
        guard (try? tsv.write(to: url, atomically: true, encoding: .utf8)) != nil else {
            return nil
        }
        return try? InputStyleManager.loadTable(from: url)
    }

    public var reading: String { composingText.convertTarget }

    public var romanInput: String {
        String(composingText.input.compactMap { element in
            guard case .character(let character) = element.piece else { return nil }
            if case .roman2kana = element.inputStyle {
                return SymbolRules.symbol(for: character) ?? character
            }
            return character
        })
    }

    public var cursor: Int { composingText.convertTargetCursorPosition }

    public func insert(_ text: String) {
        let text = if case .roman2kana = inputStyle {
            text.map { SymbolRules.output(for: $0) ?? String($0) }.joined()
        } else {
            text
        }
        composingText.insertAtCursorPosition(text, inputStyle: inputStyle)
    }

    public func deleteBackward() {
        composingText.deleteBackwardFromCursorPosition(count: 1)
    }

    public func deleteForward() {
        composingText.deleteForwardFromCursorPosition(count: 1)
    }

    public func moveCursor(by offset: Int) {
        _ = composingText.moveCursorFromCursorPosition(count: offset)
    }

    public func moveCursorToStart() {
        moveCursor(by: -cursor)
    }

    public func moveCursorToEnd() {
        moveCursor(by: reading.count - cursor)
    }

    public func reset() {
        composingText = ComposingText()
        lastCandidates = []
        converter.stopComposition()
    }

    public func candidates() -> [ConversionCandidate] {
        guard !composingText.isEmpty else { return [] }
        let result = converter.requestCandidates(composingText.prefixToCursorPosition(), options: options(prediction: false, useZenzai: true))
        return store(result.mainResults)
    }

    public func bestConversion(ofReadingFrom offset: Int) -> String {
        var rest = composingText
        _ = rest.moveCursorFromCursorPosition(count: offset - rest.convertTargetCursorPosition)
        rest.deleteBackwardFromCursorPosition(count: offset)
        _ = rest.moveCursorFromCursorPosition(count: rest.convertTarget.count - rest.convertTargetCursorPosition)
        guard !rest.isEmpty else { return "" }
        let results = converter.requestCandidates(rest, options: options(prediction: false, useZenzai: true)).mainResults
        return results.first?.text ?? rest.convertTarget
    }

    public func predictions(useZenzai: Bool) -> [ConversionCandidate] {
        guard !composingText.isEmpty else { return [] }
        var text = composingText
        _ = text.moveCursorFromCursorPosition(count: text.convertTarget.count - text.convertTargetCursorPosition)
        let result = converter.requestCandidates(text, options: options(prediction: true, useZenzai: useZenzai))
        return store(result.predictionResults)
    }

    public func commit(_ candidate: ConversionCandidate) {
        guard lastCandidates.indices.contains(candidate.id) else { return }
        let raw = lastCandidates[candidate.id]
        converter.setCompletedData(raw)
        converter.updateLearningData(raw)
        composingText.prefixComplete(composingCount: raw.composingCount)
        lastCandidates = []
        if composingText.isEmpty {
            converter.commitUpdateLearningData()
            converter.stopComposition()
        }
    }

    public func prepareForConversion() {
        let position = cursor
        moveCursorToEnd()
        composingText.insertAtCursorPosition([.init(piece: .compositionSeparator, inputStyle: inputStyle)])
        moveCursor(by: min(position, reading.count) - cursor)
    }

    public func readingForConversion() -> String {
        var text = composingText
        _ = text.moveCursorFromCursorPosition(count: text.convertTarget.count - text.convertTargetCursorPosition)
        text.insertAtCursorPosition([.init(piece: .compositionSeparator, inputStyle: inputStyle)])
        return text.convertTarget
    }

    private func store(_ results: [Candidate]) -> [ConversionCandidate] {
        lastCandidates = results
        let total = composingText.convertTarget.count
        return results.enumerated().map { index, candidate in
            var rest = composingText
            rest.prefixComplete(composingCount: candidate.composingCount)
            return ConversionCandidate(text: candidate.text, readingCount: total - rest.convertTarget.count, id: index)
        }
    }

    private func options(prediction: Bool, useZenzai: Bool) -> ConvertRequestOptions {
        let zenzai: ConvertRequestOptions.ZenzaiMode = if useZenzai, let url = configuration.zenzaiModelURL {
            .on(weight: url, inferenceLimit: 10, personalizationMode: nil)
        } else {
            .off
        }
        return ConvertRequestOptions(
            requireJapanesePrediction: prediction ? .manualMix : .disabled,
            requireEnglishPrediction: .disabled,
            keyboardLanguage: .ja_JP,
            learningType: .inputAndOutput,
            memoryDirectoryURL: configuration.memoryDirectoryURL,
            sharedContainerURL: configuration.memoryDirectoryURL,
            textReplacer: .withDefaultEmojiDictionary(),
            specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
            zenzaiMode: zenzai,
            metadata: .init(versionString: "Momiji")
        )
    }
}
