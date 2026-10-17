import Testing
@testable import MomijiCore

@Test func dvorakLabels() {
    #expect(SelectionKeys.labels(for: .dvorak) == Array("aoeuidhtns"))
}

@Test func qwertyLabels() {
    #expect(SelectionKeys.labels(for: .qwerty) == Array("asdfghjkl;"))
}

@Test func dvorakIndex() {
    #expect(SelectionKeys.index(of: "s", layout: .dvorak) == 9)
    #expect(SelectionKeys.index(of: "f", layout: .dvorak) == nil)
}

@Test func qwertySemicolon() {
    #expect(SelectionKeys.index(of: ";", layout: .qwerty) == 9)
}

@Test func digits() {
    #expect(SelectionKeys.index(of: "1", layout: .dvorak) == 0)
    #expect(SelectionKeys.index(of: "0", layout: .qwerty) == 9)
}

@Test func uppercaseIsNotSelection() {
    #expect(SelectionKeys.index(of: "A", layout: .dvorak) == nil)
}
