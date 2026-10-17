import Foundation

public enum CharacterFormConverter {
    public static func convert(reading: String, romanInput: String, to form: CharacterForm) -> String {
        switch form {
        case .hiragana:
            reading
        case .fullKatakana:
            reading.applyingTransform(.hiraganaToKatakana, reverse: false) ?? reading
        case .halfWidth:
            convert(reading: reading, romanInput: romanInput, to: .fullKatakana)
                .applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? reading
        case .fullAlphanumeric:
            romanInput.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? romanInput
        case .halfAlphanumeric:
            romanInput
        }
    }
}
