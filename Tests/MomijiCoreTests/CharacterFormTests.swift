import Testing
@testable import MomijiCore

@Test func halfWidthKatakana() {
    #expect(CharacterFormConverter.convert(reading: "かな", romanInput: "kana", to: .halfWidth) == "ｶﾅ")
}

@Test func fullAlphanumeric() {
    #expect(CharacterFormConverter.convert(reading: "かな", romanInput: "kana", to: .fullAlphanumeric) == "ｋａｎａ")
}

@Test func fullKatakana() {
    #expect(CharacterFormConverter.convert(reading: "かな", romanInput: "kana", to: .fullKatakana) == "カナ")
}
