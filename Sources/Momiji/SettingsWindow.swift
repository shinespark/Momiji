import AppKit
import MomijiCore
import SwiftUI
import UniformTypeIdentifiers

final class SettingsModel: ObservableObject {
    @Published var settings: MomijiSettings
    @Published var errorMessage: String?
    private let engine: MomijiEngine

    init(engine: MomijiEngine) {
        self.engine = engine
        settings = engine.settings
    }

    func update(_ change: @escaping (inout MomijiSettings) -> Void) {
        engine.update(change)
        settings = engine.settings
    }

    func importTable() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.tabSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let name = try engine.tableStore.importTable(from: url)
            update { $0.romajiTableName = name }
            errorMessage = nil
        } catch RomajiTableImportError.invalidLine(let line) {
            errorMessage = "\(line) 行目の形式が正しくありません"
        } catch RomajiTableImportError.empty {
            errorMessage = "ローマ字テーブルが空です"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetTable() {
        engine.tableStore.reset()
        update { $0.romajiTableName = nil }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Picker("選択キー", selection: Binding(
                get: { model.settings.selectionKeyLayout },
                set: { value in model.update { $0.selectionKeyLayout = value } }
            )) {
                Text("Dvorak（a o e u i d h t n s）").tag(SelectionKeyLayout.dvorak)
                Text("QWERTY（a s d f g h j k l ;）").tag(SelectionKeyLayout.qwerty)
            }
            LabeledContent("ローマ字テーブル") {
                VStack(alignment: .leading) {
                    Text(model.settings.romajiTableName ?? "標準")
                    HStack {
                        Button("ファイルから読み込む…") { model.importTable() }
                        Button("標準に戻す") { model.resetTable() }
                            .disabled(model.settings.romajiTableName == nil)
                    }
                    if let message = model.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            Toggle("Zenzai（ニューラル変換）", isOn: Binding(
                get: { model.settings.zenzaiEnabled },
                set: { value in model.update { $0.zenzaiEnabled = value } }
            ))
            Toggle("入力中の自動サジェスト", isOn: Binding(
                get: { model.settings.suggestionEnabled },
                set: { value in model.update { $0.suggestionEnabled = value } }
            ))
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: SettingsModel(engine: .shared)))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "Momiji 設定"
            newWindow.styleMask = [.titled, .closable]
            newWindow.isReleasedWhenClosed = false
            newWindow.setContentSize(hosting.view.fittingSize)
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
