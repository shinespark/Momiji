import AppKit
import InputMethodKit
import MomijiCore

@objc(MomijiInputController)
final class MomijiInputController: IMKInputController {
    private var engine: MomijiEngine { .shared }
    private weak var currentClient: (any IMKTextInput & NSObjectProtocol)?

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? (any IMKTextInput & NSObjectProtocol),
              let input = KeyInput(event: event) else {
            return false
        }
        currentClient = client
        let result = engine.session.handle(input)
        if let text = result.commitText, !text.isEmpty {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        render(client: client)
        return result.handled
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? (any IMKTextInput & NSObjectProtocol) else { return }
        if let text = engine.session.commitAll(), !text.isEmpty {
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        render(client: client)
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
    }

    func currentCaretRect() -> NSRect {
        var rect = NSRect.zero
        _ = currentClient?.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        return rect
    }

    private static let candidatePanel = CandidatePanel()
    private static let suggestionPanel = SuggestionPanel()

    func sessionStateDidChange(_ state: SessionState) {
        let caret = currentCaretRect()
        Self.candidatePanel.update(state.candidateWindow, caret: caret)
        Self.suggestionPanel.update(state.candidateWindow == nil ? state.suggestions : [], caret: caret)
    }

    private func render(client: any IMKTextInput & NSObjectProtocol) {
        let state = engine.session.state
        let marked = NSMutableAttributedString()
        for (index, segment) in state.marked.enumerated() {
            let style: NSUnderlineStyle = segment.isFocused ? .thick : .single
            marked.append(NSAttributedString(string: segment.text, attributes: [
                .underlineStyle: style.rawValue,
                .markedClauseSegment: index,
            ]))
        }
        let caret = state.cursor ?? (state.marked.first.map { ($0.text as NSString).length } ?? 0)
        client.setMarkedText(
            marked,
            selectionRange: NSRange(location: min(caret, marked.length), length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        sessionStateDidChange(state)
    }
}
