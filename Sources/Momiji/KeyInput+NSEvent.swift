import AppKit
import MomijiCore

extension KeyInput {
    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        var modifiers: KeyInput.Modifiers = []
        let flags = event.modifierFlags
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        guard let input = KeyInput.make(keyCode: event.keyCode, charactersIgnoringModifiers: event.charactersIgnoringModifiers, modifiers: modifiers) else {
            return nil
        }
        self = input
    }
}
