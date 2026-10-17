import Foundation
import MomijiConverter
import MomijiCore

var tablePath: String?
var useZenzai = true
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "--table":
        tablePath = arguments.popFirst()
    case "--no-zenzai":
        useZenzai = false
    default:
        FileHandle.standardError.write(Data("usage: momiji-try [--table <google形式TSV>] [--no-zenzai]\n".utf8))
        exit(2)
    }
}

let tableTSV = try tablePath.map { try RomajiTableImporter.convert(googleTSV: String(contentsOfFile: $0, encoding: .utf8)) }
let modelURL = URL(fileURLWithPath: "Resources/zenzai/ggml-model-Q5_K_M.gguf")
if useZenzai && !FileManager.default.fileExists(atPath: modelURL.path) {
    FileHandle.standardError.write(Data("Zenzai モデルがありません。scripts/fetch-zenzai-model.sh を実行してください\n".utf8))
    exit(1)
}
let memory = FileManager.default.temporaryDirectory.appendingPathComponent("momiji-try", isDirectory: true)
try FileManager.default.createDirectory(at: memory, withIntermediateDirectories: true)
let backend = AzooKeyBackend(configuration: .init(
    romajiTableTSV: tableTSV,
    zenzaiModelURL: useZenzai ? modelURL : nil,
    memoryDirectoryURL: memory
))

while let line = readLine() {
    backend.reset()
    backend.insert(line)
    backend.prepareForConversion()
    backend.moveCursorToEnd()
    let whole = backend.candidates().filter { $0.readingCount == backend.reading.count }
    print("# \(backend.reading)")
    for candidate in whole.prefix(5) {
        print(candidate.text)
    }
}
