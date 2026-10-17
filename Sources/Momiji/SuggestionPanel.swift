import AppKit

final class SuggestionPanel: ListPanel {
    init() { super.init(fontSize: 13) }

    func update(_ suggestions: [String], caret: NSRect) {
        guard !suggestions.isEmpty else {
            orderOut(nil)
            return
        }
        show(rows: suggestions.map { Row(label: nil, text: $0, isSelected: false) }, footer: nil, below: caret)
    }
}
