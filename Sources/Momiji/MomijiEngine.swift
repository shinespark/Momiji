import Foundation
import MomijiConverter
import MomijiCore

final class MomijiEngine {
    static let shared = MomijiEngine()

    let defaults = UserDefaults.standard
    let tableStore: RomajiTableStore
    let backend: AzooKeyBackend
    let session: InputSession
    private(set) var settings: MomijiSettings

    private static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Momiji", isDirectory: true)
    }

    private static var zenzaiModelURL: URL? {
        let url = Bundle.main.resourceURL?.appendingPathComponent("zenzai/ggml-model-Q5_K_M.gguf")
        return url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    private init() {
        settings = MomijiSettings.load(from: defaults)
        tableStore = RomajiTableStore(directory: Self.supportDirectory)
        let memory = Self.supportDirectory.appendingPathComponent("memory", isDirectory: true)
        try? FileManager.default.createDirectory(at: memory, withIntermediateDirectories: true)
        backend = AzooKeyBackend(configuration: .init(
            romajiTableTSV: tableStore.loadAzooKeyTSV(),
            zenzaiModelURL: settings.zenzaiEnabled ? Self.zenzaiModelURL : nil,
            memoryDirectoryURL: memory
        ))
        session = InputSession(backend: backend, options: Self.sessionOptions(settings))
        NotificationCenter.default.addObserver(forName: .momijiSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }

    private static func sessionOptions(_ settings: MomijiSettings) -> SessionOptions {
        SessionOptions(selectionKeyLayout: settings.selectionKeyLayout, suggestionEnabled: settings.suggestionEnabled)
    }

    func update(_ change: (inout MomijiSettings) -> Void) {
        change(&settings)
        settings.save(to: defaults)
        NotificationCenter.default.post(name: .momijiSettingsDidChange, object: nil)
    }

    private func reload() {
        settings = MomijiSettings.load(from: defaults)
        session.options = Self.sessionOptions(settings)
        var configuration = backend.configuration
        configuration.romajiTableTSV = tableStore.loadAzooKeyTSV()
        configuration.zenzaiModelURL = settings.zenzaiEnabled ? Self.zenzaiModelURL : nil
        backend.configuration = configuration
    }
}
