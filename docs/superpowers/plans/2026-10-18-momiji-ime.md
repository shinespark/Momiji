# Momiji IME 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dvorak のホームポジションで候補を選んで即確定できる、自分用の macOS 日本語 IME「Momiji」を作る。

**Architecture:** SwiftPM のパッケージ1つで構成する。`MomijiCore`（AppKit に依存しない入力ロジック）、`MomijiConverter`（AzooKeyKanaKanjiConverter のラッパー）、`momiji-try`（精度を試す CLI）、`Momiji`（InputMethodKit のアプリ本体）の4ターゲット。`.app` は Xcode プロジェクトを使わず、`scripts/install.sh` が `swift build` の成果物からバンドルを組み立て、署名して `~/Library/Input Methods` に置く。変換は azooKey-Desktop と同じ「先頭文節（カーソルまで）の候補を確定し、残りを再変換する」モデルで行う。

**Tech Stack:** Swift / SwiftPM / InputMethodKit / AppKit / SwiftUI（設定画面）/ AzooKeyKanaKanjiConverter（`Zenzai` trait）/ Swift Testing

**Spec:** `docs/superpowers/specs/2026-10-18-momiji-ime-design.md`

## Global Constraints

- バンドル ID は `dev.shinespark.inputmethod.Momiji`、表示名は `Momiji`
- 入力モードは「ひらがな」1つだけ。英数モードは持たない
- AzooKeyKanaKanjiConverter は azooKey-Desktop の `Core/Package.swift` と同じ revision に固定し、`traits: ["Zenzai"]` を付ける。プロダクトは `KanaKanjiConverterModuleWithDefaultDictionary`
- Zenzai モデルは `https://huggingface.co/Miwa-Keita/zenz-v3.2-small-gguf/resolve/main/ggml-model-Q5_K_M.gguf`。リポジトリには入れず、`scripts/fetch-zenzai-model.sh` で `Resources/zenzai/ggml-model-Q5_K_M.gguf` に取得する（`.gitignore` 対象）
- 選択キー: Dvorak `a o e u i d h t n s`、QWERTY `a s d f g h j k l ;`、数字 `1 2 3 4 5 6 7 8 9 0`。それぞれ候補ページ内の 0〜9 番目
- 候補ウィンドウは縦並び、1ページ10件、各候補の左に選択キーを1文字表示（数字は表示しない）、右下に `n / m`
- キー判定は物理キーではなく文字で行う。修飾キー付きは `charactersIgnoringModifiers` を使う
- 署名は Keychain の `Apple Development` 証明書で行う。公証はしない
- コメントは原則書かない（非自明な回避策や外部仕様による制約のときだけ）
- ドキュメントにツールやライブラリのバージョンを書かない

## Review Focus

1. **`;` を含むローマ字** — DvorakJP Prime の `;h` → `←`、`ch;neru` → `ちゃんねる` が入力中にテーブルどおりかなになる（`;` が全角化されたり選択キー扱いされたりしない）。Task 2 のテストで固定する
2. **末尾の `n`** — `kan` と打ってスペースで変換すると読みは `かん` になる（`かn` のまま変換されない）。Task 2 のテストで固定する
3. **2ページ目以降での選択キー** — 2ページ目を表示中に `a` を押すと11番目の候補が確定する。Task 6 のテストで固定する
4. **候補が10件未満のページで範囲外の選択キー** — 3件しかないページで `s` を押しても何も起きない（確定もせず、文字も入らない）。Task 6 のテストで固定する
5. **Option+X の文字判定** — Option を押しながら X を打つと `characters` は `≈` になるが、`charactersIgnoringModifiers` の `x` で全角カタカナ変換になる。Task 4 のテストで固定する

---

## ファイル構成

```
Package.swift
.gitignore                                  # .superpowers/ .build/ Resources/zenzai/
scripts/fetch-zenzai-model.sh
scripts/install.sh
Resources/Info.plist                        # Momiji.app 用
Sources/MomijiCore/
  RomajiTableImporter.swift                 # Google日本語入力 TSV → azooKey 形式
  SelectionKeys.swift                       # 選択キー配列と文字→番号
  KeyInput.swift                            # キー入力の値型と生成
  Keymap.swift                              # ことえり風キー設定 → Action
  ConversionBackend.swift                   # 変換エンジンの抽象（プロトコル）
  InputSession.swift                        # 状態遷移（入力中/変換中/候補選択中）
  SessionState.swift                        # 画面に出す状態（未確定文字列・候補ウィンドウ・サジェスト）
  CharacterForm.swift                       # ひらがな/カタカナ/半角/英数への変換
  MomijiSettings.swift                      # 設定値の型と保存
  RomajiTableStore.swift                    # 読み込んだテーブルの保存
Sources/MomijiConverter/
  AzooKeyBackend.swift                      # ConversionBackend の AzooKey 実装
Sources/momiji-try/
  main.swift                                # 精度を試す CLI
Sources/Momiji/
  main.swift                                # IMKServer 起動
  MomijiInputController.swift               # IMKInputController
  KeyInput+NSEvent.swift
  CandidatePanel.swift                      # 候補ウィンドウ（スタイル A）
  SuggestionPanel.swift                     # 自動サジェスト
  SettingsWindow.swift                      # SwiftUI の設定画面
Tests/MomijiCoreTests/
  Fixtures/dvorak_jp.tsv                    # dvorakjp-roman-table の outputs/google_japanese_input/dvorak_jp.tsv
  RomajiTableImporterTests.swift
  SelectionKeysTests.swift
  KeymapTests.swift
  InputSessionTests.swift
  FakeBackend.swift
  CharacterFormTests.swift
  SettingsTests.swift
Tests/MomijiConverterTests/
  AzooKeyBackendTests.swift
```

---

### Task 1: パッケージの土台とローマ字テーブルの変換

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/MomijiCore/RomajiTableImporter.swift`
- Test: `Tests/MomijiCoreTests/RomajiTableImporterTests.swift`, `Tests/MomijiCoreTests/Fixtures/dvorak_jp.tsv`

**Interfaces:**
- Produces:
  - `public enum RomajiTableImporter { public static func convert(googleTSV: String) throws(RomajiTableImportError) -> String }` — azooKey の `InputStyleManager.loadTable` が読める2列 TSV を返す
  - `public enum RomajiTableImportError: Error, Equatable { case empty; case invalidLine(lineNumber: Int) }`

変換規則（azooKey は3列目を読まないため）:
- 2列 `in⇥out` → `in⇥out`
- 3列 `in⇥out⇥next` → `in⇥out+next`（例: `kk⇥っ⇥k` → `kk⇥っk`）
- 入力・出力中の `{` `}` → `{lbracket}` `{rbracket}`
- 空行は捨てる。列が1つ、または4つ以上の行は `invalidLine`（1始まりの行番号）
- 有効な行が0なら `empty`

- [ ] **Step 1: `Package.swift` と `.gitignore` を作る**

この Task では `MomijiCore` と `MomijiCoreTests` だけを宣言する（ソースのないターゲットがあると `swift build` が失敗するため）。`MomijiCore` は依存なし。残りのターゲットは、そのソースを作る Task で追加する: `MomijiConverter` と `momiji-try`（Task 2）、`Momiji`（Task 9）。AzooKey に依存するターゲットは Global Constraints の revision と trait を使い、azooKey-Desktop と同じく `.interoperabilityMode(.Cxx)` を付ける。プラットフォームは macOS のみ。テストのリソースに `Tests/MomijiCoreTests/Fixtures` を `.copy` で入れる。Fixture は dvorakjp-roman-table（MIT）から取得する: `curl -sL https://raw.githubusercontent.com/shinespark/dvorakjp-roman-table/main/outputs/google_japanese_input/dvorak_jp.tsv -o Tests/MomijiCoreTests/Fixtures/dvorak_jp.tsv`

- [ ] **Step 2: 失敗するテストを書く**

```swift
@Test func twoColumns() throws { #expect(try RomajiTableImporter.convert(googleTSV: "ka\tか\n") == "ka\tか") }
@Test func threeColumnsAppendNext() throws { #expect(try RomajiTableImporter.convert(googleTSV: "kk\tっ\tk") == "kk\tっk") }
@Test func escapesBraces() throws { #expect(try RomajiTableImporter.convert(googleTSV: ";[\t{") == ";[\t{lbracket}") }
@Test func skipsBlankLines() throws { #expect(try RomajiTableImporter.convert(googleTSV: "a\tあ\n\n\ni\tい") == "a\tあ\ni\tい") }
@Test func invalidLine() { #expect(throws: RomajiTableImportError.invalidLine(lineNumber: 2)) { try RomajiTableImporter.convert(googleTSV: "a\tあ\nbad") } }
@Test func emptyTable() { #expect(throws: RomajiTableImportError.empty) { try RomajiTableImporter.convert(googleTSV: "\n\n") } }
@Test func dvorakFixture() throws {
    let tsv = try String(contentsOf: Bundle.module.url(forResource: "dvorak_jp", withExtension: "tsv", subdirectory: "Fixtures")!, encoding: .utf8)
    let lines = try RomajiTableImporter.convert(googleTSV: tsv).split(separator: "\n")
    #expect(lines.contains("cc\tっc"))
    #expect(lines.contains(";h\t←"))
    #expect(!lines.contains { $0.split(separator: "\t").count != 2 })
}
```

- [ ] **Step 3: `swift test --filter RomajiTableImporterTests` で失敗を確認**（`RomajiTableImporter` が未定義）
- [ ] **Step 4: `RomajiTableImporter.convert(googleTSV:)` を実装**
- [ ] **Step 5: `swift test --filter RomajiTableImporterTests` が PASS**
- [ ] **Step 6: Commit** `git commit -m "feat: Google日本語入力形式のローマ字テーブル変換を追加"`

---

### Task 2: 変換エンジンのラッパーと精度確認用 CLI（判断ポイント）

**Files:**
- Create: `Sources/MomijiCore/ConversionBackend.swift`, `Sources/MomijiConverter/AzooKeyBackend.swift`, `Sources/momiji-try/main.swift`, `scripts/fetch-zenzai-model.sh`
- Test: `Tests/MomijiConverterTests/AzooKeyBackendTests.swift`

**Interfaces:**
- Consumes: `RomajiTableImporter.convert(googleTSV:)`
- Produces（`MomijiCore`）:

```swift
public struct ConversionCandidate: Equatable, Sendable {
    public let text: String
    public let readingCount: Int        // この候補が消費する読み（ひらがな）の文字数
    public let id: Int                  // バックエンド内部の候補を引くための番号
}

public protocol ConversionBackend: AnyObject {
    var reading: String { get }                       // 未確定の読み（ひらがな）。末尾の n は ん にしない
    var romanInput: String { get }                    // 打った英字そのまま（英数変換用）
    var cursor: Int { get }                           // 読み上のカーソル。変換中は先頭文節の終わり
    func insert(_ text: String)
    func deleteBackward()
    func deleteForward()
    func moveCursor(by offset: Int)
    func moveCursorToStart()
    func moveCursorToEnd()
    func reset()
    func candidates() -> [ConversionCandidate]        // 先頭〜cursor の変換候補（Zenzai 設定に従う）
    func predictions(useZenzai: Bool) -> [ConversionCandidate]  // reading 全体の予測候補
    func commit(_ candidate: ConversionCandidate)     // 学習し、先頭 readingCount 文字を読みから取り除く
    func readingForConversion() -> String             // 末尾の n を ん にした読み（スペース変換時に使う）
}
```

- Produces（`MomijiConverter`）: `public final class AzooKeyBackend: ConversionBackend { public init(configuration: AzooKeyBackend.Configuration) }`、`public struct Configuration { var romajiTableTSV: String?; var zenzaiModelURL: URL?; var memoryDirectoryURL: URL }`。`romajiTableTSV` が nil なら `.roman2kana`、あれば `InputStyleManager.registerInputStyle(table:for: "dev.shinespark.Momiji.romaji")` で登録して `.mapped(id: .tableName(...))`。`zenzaiModelURL` が nil なら Zenzai オフ。`ConvertRequestOptions` は azooKey-Desktop の `SegmentsManager.options(...)` を手本にする（`learningType: .inputAndOutput`、`requireJapanesePrediction` は `predictions` のときだけ `.manualMix`）。変換モデルは azooKey-Desktop の `editSegment` / `prefixCandidateCommited` と同じ。

- [ ] **Step 1: 失敗するテストを書く**（Fixture のテーブルを使う）

```swift
@Test func dvorakTableReading() { let b = backend(table: dvorakFixture); b.insert("cana"); #expect(b.reading == "かな") }
@Test func semicolonSymbol() { let b = backend(table: dvorakFixture); b.insert(";h"); #expect(b.reading == "←") }
@Test func semicolonDiphthong() { let b = backend(table: dvorakFixture); b.insert("ch;neru"); #expect(b.reading == "ちゃんねる") }
@Test func trailingN() { let b = backend(table: nil); b.insert("kan"); #expect(b.readingForConversion() == "かん") }
@Test func convertsKanji() { let b = backend(table: nil); b.insert("kanji"); b.moveCursorToEnd(); #expect(b.candidates().contains { $0.text == "漢字" }) }
@Test func commitPrefixLeavesRest() {
    let b = backend(table: nil); b.insert("kanjihenkan"); b.moveCursorToStart(); b.moveCursor(by: 3)
    let c = b.candidates().first { $0.text == "漢字" }!; b.commit(c); #expect(b.reading == "へんかん")
}
@Test func predictionsExtendReading() { let b = backend(table: nil); b.insert("arigat"); #expect(b.predictions(useZenzai: false).contains { $0.text.hasPrefix("ありがとう") }) }
```

`Package.swift` に `MomijiConverter`、`MomijiConverterTests`、`momiji-try` を追加する。`backend(table:)` はテスト内のヘルパー。Fixture は `#filePath` から `../MomijiCoreTests/Fixtures/dvorak_jp.tsv` を読む。Zenzai はテストではオフ、学習ディレクトリは一時ディレクトリ。

- [ ] **Step 2: `swift test --filter AzooKeyBackendTests` で失敗を確認**
- [ ] **Step 3: `ConversionBackend` と `AzooKeyBackend` を実装**。`;` の例が通らない場合は azooKey 側の全角化や `{any character}` の扱いを疑う
- [ ] **Step 4: `swift test --filter AzooKeyBackendTests` が PASS**
- [ ] **Step 5: `scripts/fetch-zenzai-model.sh` と `momiji-try` を作る**

`momiji-try [--table <google形式TSV>] [--no-zenzai]`: 標準入力から1行ずつローマ字を読み、全体を1文節として変換した上位5候補を1行ずつ表示する。Zenzai モデルは `Resources/zenzai/ggml-model-Q5_K_M.gguf`。

- [ ] **Step 6: 動作確認**

Run: `scripts/fetch-zenzai-model.sh && echo "cyoudoiikanjinihenkansaretehoshii" | swift run momiji-try --table Tests/MomijiCoreTests/Fixtures/dvorak_jp.tsv`
Expected: 1行目に漢字かな混じりの変換結果が出る

- [ ] **Step 7: Commit** `git commit -m "feat: AzooKey変換ラッパーと精度確認用CLIを追加"`

- [ ] **Step 8: 判断ポイント — ここで止めてユーザーに精度を確認してもらう**

ユーザーに `swift run momiji-try --table <自分のTSV>` で普段の文章を試してもらう。Google日本語入力より精度が低ければ、手を打つ前に報告して相談する（設計書の「精度の判断」）。続行の合意が取れるまで Task 3 以降に進まない。

---

### Task 3: 選択キー

**Files:**
- Create: `Sources/MomijiCore/SelectionKeys.swift`
- Test: `Tests/MomijiCoreTests/SelectionKeysTests.swift`

**Interfaces:**
- Produces:
  - `public enum SelectionKeyLayout: String, Codable, CaseIterable, Sendable { case dvorak, qwerty }`
  - `public enum SelectionKeys { public static func labels(for layout: SelectionKeyLayout) -> [Character]; public static func index(of character: Character, layout: SelectionKeyLayout) -> Int? }` — `index` は選択キーと数字キーの両方を 0〜9 に対応させる。それ以外は nil

- [ ] **Step 1: 失敗するテストを書く**

```swift
@Test func dvorakLabels() { #expect(SelectionKeys.labels(for: .dvorak) == Array("aoeuidhtns")) }
@Test func qwertyLabels() { #expect(SelectionKeys.labels(for: .qwerty) == Array("asdfghjkl;")) }
@Test func dvorakIndex() { #expect(SelectionKeys.index(of: "s", layout: .dvorak) == 9); #expect(SelectionKeys.index(of: "f", layout: .dvorak) == nil) }
@Test func qwertySemicolon() { #expect(SelectionKeys.index(of: ";", layout: .qwerty) == 9) }
@Test func digits() { #expect(SelectionKeys.index(of: "1", layout: .dvorak) == 0); #expect(SelectionKeys.index(of: "0", layout: .qwerty) == 9) }
@Test func uppercaseIsNotSelection() { #expect(SelectionKeys.index(of: "A", layout: .dvorak) == nil) }
```

- [ ] **Step 2: 失敗を確認** `swift test --filter SelectionKeysTests`
- [ ] **Step 3: 実装**
- [ ] **Step 4: PASS を確認**
- [ ] **Step 5: Commit** `git commit -m "feat: ホームポジション選択キーを追加"`

---

### Task 4: キー入力とキー設定

**Files:**
- Create: `Sources/MomijiCore/KeyInput.swift`, `Sources/MomijiCore/Keymap.swift`
- Test: `Tests/MomijiCoreTests/KeymapTests.swift`

**Interfaces:**
- Produces:

```swift
public struct KeyInput: Equatable, Sendable {
    public enum Key: Equatable, Sendable { case character(Character), space, enter, escape, tab, backspace, delete, left, right, up, down, home, end, pageUp, pageDown, function(Int) }
    public struct Modifiers: OptionSet, Sendable { shift, control, option, command }
    public let key: Key
    public let modifiers: Modifiers
    public init(key: Key, modifiers: Modifiers = [])
    // keyCode で特殊キーを判定し、それ以外は charactersIgnoringModifiers の先頭文字を使う
    public static func make(keyCode: UInt16, charactersIgnoringModifiers: String?, modifiers: Modifiers) -> KeyInput?
}

public enum CharacterForm: Equatable, Sendable { case hiragana, fullKatakana, halfWidth, fullAlphanumeric, halfAlphanumeric }

public enum KeyAction: Equatable, Sendable {
    case convert, nextCandidate, prevCandidate, nextPage, prevPage, commit, cancel
    case backspace, delete, cursorLeft, cursorRight, cursorStart, cursorEnd
    case segmentShrink, segmentExpand, segmentFocusLeft, segmentFocusRight
    case predict, display(CharacterForm), insertFullSpace
}

public enum KeymapMode: Sendable { case composition, conversion }
public enum Keymap { public static func action(for input: KeyInput, mode: KeymapMode) -> KeyAction? }
```

`CharacterForm` は `Keymap.swift` に置く（変換処理は Task 5 の `CharacterForm.swift`）。`Keymap` は mozc の `src/data/keymap/kotoeri.tsv` の Composition 行と Conversion 行を移したもの。Prediction 行は `conversion` と同じ扱い。省く行: `IMEOn`/`IMEOff`/`ToggleAlphanumericMode`/`ReportBug`/`ConvertWithoutHistory`、`Virtual*`、Hankaku/Kanji/ON/OFF キー。`SegmentFocusLeft/Right` は azooKey モデルでは先頭文節を確定せず読みの境界を動かすだけなので、`segmentFocusLeft/Right` も `segmentShrink/Expand` と同じ境界移動として扱う（InputSession 側で処理）。

- [ ] **Step 1: 失敗するテストを書く**

```swift
@Test func optionXIsKatakanaInComposition() {
    let input = KeyInput.make(keyCode: 7, charactersIgnoringModifiers: "x", modifiers: .option)!
    #expect(Keymap.action(for: input, mode: .composition) == .display(.fullKatakana))
}
@Test func optionXIsKatakanaInConversion() { #expect(Keymap.action(for: .init(key: .character("x"), modifiers: .option), mode: .conversion) == .display(.fullKatakana)) }
@Test func shiftArrowsResizeSegment() {
    #expect(Keymap.action(for: .init(key: .left, modifiers: .shift), mode: .conversion) == .segmentShrink)
    #expect(Keymap.action(for: .init(key: .right, modifiers: .shift), mode: .conversion) == .segmentExpand)
}
@Test func spaceAndTab() {
    #expect(Keymap.action(for: .init(key: .space), mode: .composition) == .convert)
    #expect(Keymap.action(for: .init(key: .space), mode: .conversion) == .nextCandidate)
    #expect(Keymap.action(for: .init(key: .tab), mode: .composition) == .predict)
}
@Test func ctrlKAndF7() {
    #expect(Keymap.action(for: .init(key: .character("k"), modifiers: .control), mode: .composition) == .display(.fullKatakana))
    #expect(Keymap.action(for: .init(key: .function(7)), mode: .conversion) == .display(.fullKatakana))
}
@Test func plainLetterHasNoAction() { #expect(Keymap.action(for: .init(key: .character("a")), mode: .composition) == nil) }
@Test func makeSpecialKeys() { #expect(KeyInput.make(keyCode: 49, charactersIgnoringModifiers: " ", modifiers: [])?.key == .space) }
```

- [ ] **Step 2: 失敗を確認** `swift test --filter KeymapTests`
- [ ] **Step 3: 実装**（keyCode は Carbon の `kVK_*` の値を使う）
- [ ] **Step 4: PASS を確認**
- [ ] **Step 5: Commit** `git commit -m "feat: ことえり風キー設定を追加"`

---

### Task 5: 入力セッション — 入力・変換・確定・文字種変換

**Files:**
- Create: `Sources/MomijiCore/InputSession.swift`, `Sources/MomijiCore/SessionState.swift`, `Sources/MomijiCore/CharacterForm.swift`
- Test: `Tests/MomijiCoreTests/InputSessionTests.swift`, `Tests/MomijiCoreTests/FakeBackend.swift`, `Tests/MomijiCoreTests/CharacterFormTests.swift`

**Interfaces:**
- Consumes: `ConversionBackend`、`Keymap.action(for:mode:)`、`KeyInput`、`CharacterForm`
- Produces:

```swift
public struct MarkedSegment: Equatable, Sendable { public let text: String; public let isFocused: Bool }

public struct CandidateWindowModel: Equatable, Sendable {
    public let candidates: [String]      // 現在ページの候補（最大10）
    public let labels: [Character]       // 現在の選択キー配列の先頭 candidates.count 個
    public let selectedIndex: Int        // ページ内
    public let page: Int                 // 1始まり
    public let pageCount: Int
}

public struct SessionState: Equatable, Sendable {
    public var marked: [MarkedSegment]   // 空なら未確定文字列なし
    public var cursor: Int?              // 入力中のみ
    public var candidateWindow: CandidateWindowModel?
    public var suggestions: [String]     // 自動サジェスト（入力中のみ）
}

public struct SessionOptions: Equatable, Sendable {
    public var selectionKeyLayout: SelectionKeyLayout
    public var suggestionEnabled: Bool
}

public final class InputSession {
    public init(backend: any ConversionBackend, options: SessionOptions)
    public var options: SessionOptions
    public private(set) var state: SessionState
    public func handle(_ input: KeyInput) -> HandleResult
    public func commitAll() -> String?      // フォーカスが外れたときなど
}

public struct HandleResult: Equatable, Sendable { public let handled: Bool; public let commitText: String? }

public enum CharacterFormConverter { public static func convert(reading: String, romanInput: String, to form: CharacterForm) -> String }
```

ふるまい:
- 入力中に修飾なしの文字 → `backend.insert`。未確定文字列なしのときの非文字キーは `handled: false`
- Space（入力中）→ 変換中へ。読み全体を1文節（cursor を末尾）として候補を取る。最初の候補をフォーカス文節に表示。候補ウィンドウはまだ出さない
- Space（変換中・ウィンドウなし）→ 候補ウィンドウを出して2番目の候補を選ぶ
- Shift+← / Shift+→ → 先頭文節の境界を1文字動かし候補を取り直す。表示はフォーカス文節＋残りの読み（ひらがな）
- Enter（変換中）→ 全体確定: フォーカス候補を `commit`、残りの読みが空になるまで残りの先頭候補（cursor 末尾）を `commit` し、連結を `commitText` で返す
- Esc / Backspace（変換中）→ 入力中に戻す
- `display(form)` → フォーカス文節（入力中なら読み全体）を `CharacterFormConverter` の結果に置き換えた変換中状態にする。Enter で確定
- 変換中（候補ウィンドウなし）に修飾なしの文字 → 全体確定してからその文字を入力

- [ ] **Step 1: `FakeBackend` を書く** — 読みは `insert` された文字列をそのまま使い、`candidates()` は `[読み先頭cursor文字 → 候補文字列配列]` の辞書から返す
- [ ] **Step 2: 失敗するテストを書く**

```swift
@Test func spaceConvertsWithoutWindow()   // "かんじ" → Space → marked == [("漢字", focused)], candidateWindow == nil
@Test func secondSpaceOpensWindow()       // Space×2 → candidateWindow.selectedIndex == 1, page == 1
@Test func enterCommitsAll()              // "かんじへんかん" → Space → Shift+← ×4 → Enter → commitText == "漢字変換"
@Test func shiftLeftShrinksSegment()      // "かんじへんかん" → Space → Shift+← → marked.first == 先頭6文字の候補, marked[1].text == "ん"
@Test func optionXMakesKatakana()         // "かな" → Option+X → marked == [("カナ", focused)] → Enter → "カナ"
@Test func escapeReturnsToComposition()   // Space → Esc → marked == [("かんじ", false)], candidateWindow == nil
@Test func typingDuringConversionCommits()// Space → "a" → commitText == "漢字", marked == [("あ", false)]
@Test func halfAlphanumericUsesRoman()    // insert "kanji" → F10 → marked.first?.text == "kanji"
```

（各テストは上のコメントの操作と期待値をそのままアサーションにする）

- [ ] **Step 3: 失敗を確認** `swift test --filter InputSessionTests`
- [ ] **Step 4: 実装**
- [ ] **Step 5: PASS を確認**（`CharacterFormTests` も: `convert(reading: "かな", romanInput: "kana", to: .halfWidth) == "ｶﾅ"`、`.fullAlphanumeric` → `"ｋａｎａ"`）
- [ ] **Step 6: Commit** `git commit -m "feat: 入力セッションの変換と確定を追加"`

---

### Task 6: 入力セッション — 候補ウィンドウと選択キーで即確定

**Files:**
- Modify: `Sources/MomijiCore/InputSession.swift`
- Test: `Tests/MomijiCoreTests/InputSessionTests.swift`

**Interfaces:**
- Consumes: `SelectionKeys.index(of:layout:)`、`SelectionKeys.labels(for:)`、Task 5 の全体確定

ふるまい:
- 候補ウィンドウ表示中に `SelectionKeys.index` が非 nil の文字（修飾なし）→ 現在ページの該当候補をフォーカス文節に入れて全体確定。ページ内に該当候補がなければ何もしない（`handled: true`, `commitText: nil`）
- Space / ↓ → 次の候補（ページをまたぐ）。↑ / Shift+Space → 前の候補。PageDown / Shift+↓ → 次ページ、PageUp / Shift+↑ → 前ページ
- 表示中に選択キー・数字・操作キー以外の修飾なし文字 → 全体確定してからその文字を入力
- `labels` は `options.selectionKeyLayout` に従う。`options` を変えたら次のキー入力から反映

- [ ] **Step 1: 失敗するテストを書く**

```swift
@Test func dvorakHomeKeyCommits()        // 候補 ["効果","硬貨","高価"] → Space×2 → "e" → commitText == "高価", state.marked.isEmpty
@Test func digitCommits()                // 同 → "2" → commitText == "硬貨"
@Test func qwertyLayout()                // options.selectionKeyLayout = .qwerty → Space×2 → "d" → "高価"、labels == ["a","s","d"]
@Test func secondPageSelection()         // 候補25件 → Space×2 → PageDown → "a" → commitText == 候補[10]
@Test func outOfRangeKeyIgnored()        // 候補3件 → Space×2 → "s" → handled == true, commitText == nil, candidateWindow != nil
@Test func otherLetterCommitsThenTypes() // 候補ウィンドウ表示中 → "f"（Dvorak の選択キーではない）→ commitText == 選択中の候補, marked == [("f" を入力した読み, false)]
@Test func pageIndicator()               // 候補25件 → pageCount == 3
@Test func homeKeysTypeWhenNoWindow()    // 変換中（ウィンドウなし）→ "a" → 全体確定して "あ" を入力（Task 5 と同じ）
```

- [ ] **Step 2: 失敗を確認**
- [ ] **Step 3: 実装**
- [ ] **Step 4: PASS を確認** `swift test --filter InputSessionTests`
- [ ] **Step 5: Commit** `git commit -m "feat: 候補ウィンドウとホームポジション選択を追加"`

---

### Task 7: 入力セッション — Tab の予測変換と自動サジェスト

**Files:**
- Modify: `Sources/MomijiCore/InputSession.swift`
- Test: `Tests/MomijiCoreTests/InputSessionTests.swift`

**Interfaces:**
- Consumes: `backend.predictions(useZenzai:)`

ふるまい:
- `options.suggestionEnabled` が true なら、入力中の文字入力・削除のたびに `predictions(useZenzai: false)` の上位5件を `state.suggestions` に入れる。false なら常に空
- 入力中に Tab、またはサジェスト表示中に Tab / ↓ → 予測候補（`predictions(useZenzai: true)`）を候補ウィンドウに出す。ここから先は Task 6 と同じく選択キーで即確定（予測候補は読み全体を消費する）
- サジェスト表示中の `a` `o` `e` などは普通に文字入力

- [ ] **Step 1: 失敗するテストを書く**

```swift
@Test func suggestionsWhileTyping()       // FakeBackend の予測 ["ありがとう","ありがとうございます"] → "ありが" 入力 → suggestions == 両方
@Test func suggestionsDisabled()          // suggestionEnabled = false → suggestions.isEmpty
@Test func tabOpensPredictionWindow()     // "ありが" → Tab → candidateWindow?.candidates == ["ありがとう","ありがとうございます"]
@Test func downFromSuggestionOpensWindow()// suggestions 非空 → ↓ → candidateWindow != nil
@Test func homeKeyCommitsPrediction()     // Tab → "o" → commitText == "ありがとうございます"
@Test func homeKeyTypesDuringSuggestion() // suggestions 非空 → "a" → marked の読みに "a" が足される, commitText == nil
```

- [ ] **Step 2: 失敗を確認**
- [ ] **Step 3: 実装**
- [ ] **Step 4: PASS を確認** `swift test --filter InputSessionTests`
- [ ] **Step 5: Commit** `git commit -m "feat: 予測変換と自動サジェストを追加"`

---

### Task 8: 設定とローマ字テーブルの保存

**Files:**
- Create: `Sources/MomijiCore/MomijiSettings.swift`, `Sources/MomijiCore/RomajiTableStore.swift`
- Test: `Tests/MomijiCoreTests/SettingsTests.swift`

**Interfaces:**
- Consumes: `RomajiTableImporter.convert(googleTSV:)`、`SelectionKeyLayout`
- Produces:

```swift
public struct MomijiSettings: Codable, Equatable, Sendable {
    public var selectionKeyLayout: SelectionKeyLayout = .dvorak
    public var zenzaiEnabled: Bool = true
    public var suggestionEnabled: Bool = true
    public var romajiTableName: String? = nil      // 表示用（取り込んだファイル名）
    public static func load(from defaults: UserDefaults) -> MomijiSettings
    public func save(to defaults: UserDefaults)
}
public extension Notification.Name { static let momijiSettingsDidChange: Notification.Name }

public struct RomajiTableStore {
    public init(directory: URL)                        // 本番は Application Support/Momiji
    public func importTable(from fileURL: URL) throws -> String   // 変換して保存、表示名を返す。失敗時は既存の保存内容を変えない
    public func loadAzooKeyTSV() -> String?
    public func reset()                                // 標準に戻す（保存ファイルを消す）
}
```

- [ ] **Step 1: 失敗するテストを書く**

```swift
@Test func defaults()                 // 空の UserDefaults → selectionKeyLayout == .dvorak, zenzaiEnabled, suggestionEnabled
@Test func roundTrip()                // .qwerty で save → load == 同じ値
@Test func importCopiesTable()        // 一時ファイルに "ka\tか" → importTable → 元ファイル削除 → loadAzooKeyTSV() == "ka\tか"
@Test func failedImportKeepsOld()     // 正常に import 後、"bad" だけのファイルを import → throws、loadAzooKeyTSV() は前の内容
@Test func resetRemovesTable()        // reset → loadAzooKeyTSV() == nil
```

- [ ] **Step 2: 失敗を確認** `swift test --filter SettingsTests`
- [ ] **Step 3: 実装**（UserDefaults には JSON で1キーに保存）
- [ ] **Step 4: PASS を確認**
- [ ] **Step 5: Commit** `git commit -m "feat: 設定とローマ字テーブルの保存を追加"`

---

### Task 9: IME アプリ本体とインストール

**Files:**
- Create: `Sources/Momiji/main.swift`, `Sources/Momiji/MomijiInputController.swift`, `Sources/Momiji/KeyInput+NSEvent.swift`, `Resources/Info.plist`, `scripts/install.sh`

**Interfaces:**
- Consumes: `InputSession`、`AzooKeyBackend`、`MomijiSettings`、`RomajiTableStore`、`KeyInput.make(keyCode:charactersIgnoringModifiers:modifiers:)`
- Produces: `MomijiInputController.currentCaretRect() -> NSRect`（Task 10 のウィンドウ位置に使う）、`MomijiInputController.sessionStateDidChange(_ state: SessionState)`（Task 10 がここでパネルを更新する）

内容:
- `Package.swift` に実行ファイルターゲット `Momiji` を追加する
- `Info.plist` は azooKey-Desktop の `azooKeyMac/Info.plist` を手本に、入力モードを「ひらがな」1つにする。`InputMethodConnectionName`、`InputMethodServerControllerClass`（`Momiji.MomijiInputController`）、`TISIntendedLanguage` `ja`、`LSBackgroundOnly`
- `main.swift` で `IMKServer` を起動し `NSApplication.shared.run()`
- `MomijiInputController` は `handle(_:client:)` で `keyDown` だけを扱い、`InputSession.handle` の結果で `insertText` / `setMarkedText` を呼ぶ。フォーカス文節は太い下線、それ以外は細い下線。`commitComposition(_:)` と `deactivateServer` で `commitAll()`
- `AzooKeyBackend` はプロセスで1つ。設定変更通知でテーブルと Zenzai を差し替える（Zenzai モデルは `Bundle.main.resourceURL/zenzai/ggml-model-Q5_K_M.gguf`）。学習は `Application Support/Momiji/memory`
- `install.sh`: `swift build -c release` → `build/Momiji.app` を組み立て（実行ファイル、`Info.plist`、SwiftPM のリソースバンドル、Zenzai モデルを `Contents/Resources` へ）→ `codesign --force --deep --sign "Apple Development"` → `~/Library/Input Methods/Momiji.app` に置き換え → 実行中の Momiji を `killall` する

- [ ] **Step 1: 上記を実装**
- [ ] **Step 2: ビルドとインストール** Run: `scripts/install.sh` Expected: エラーなしで `~/Library/Input Methods/Momiji.app` ができ、`codesign --verify ~/Library/Input Methods/Momiji.app` が成功
- [ ] **Step 3: 手動確認（ユーザーに依頼）** ログインし直し、システム設定の入力ソースに Momiji を追加。テキストエディットで `kanji` → Space → Enter で「漢字」が入る。Ctrl+Space で ABC と切り替えられる
- [ ] **Step 4: Commit** `git commit -m "feat: InputMethodKitのアプリ本体とインストールスクリプトを追加"`

---

### Task 10: 候補ウィンドウとサジェストウィンドウ

**Files:**
- Create: `Sources/Momiji/CandidatePanel.swift`, `Sources/Momiji/SuggestionPanel.swift`
- Modify: `Sources/Momiji/MomijiInputController.swift`

**Interfaces:**
- Consumes: `CandidateWindowModel`、`SessionState.suggestions`、`currentCaretRect()`、`sessionStateDidChange(_:)`

内容:
- `CandidatePanel`: フォーカスを奪わない `NSPanel`（`.nonactivatingPanel`、最前面）。縦並び、行の左に `labels[i]` を等幅・アクセント色で表示、選択行をハイライト、右下に `page / pageCount`。見た目はブレインストーミングのモック A（`.superpowers/brainstorm/*/content/candidate-labels.html` の A）
- `SuggestionPanel`: 同じ作りで、ラベルなし・ハイライトなしの小さいリスト
- どちらもキャレットの下に出し、画面の下端にかかるときは上に出す
- `candidateWindow == nil` / `suggestions.isEmpty` で隠す

- [ ] **Step 1: 実装**
- [ ] **Step 2: `scripts/install.sh` で入れ直す**
- [ ] **Step 3: 手動確認（ユーザーに依頼）** `kouka` → Space → Space で縦並び・左に `a o e u i …` が出る。`e` で3番目が確定する。`arigat` と打つとサジェストが出て、Tab で選択キー付きの候補ウィンドウに変わる
- [ ] **Step 4: Commit** `git commit -m "feat: 候補ウィンドウとサジェストウィンドウを追加"`

---

### Task 11: 設定画面

**Files:**
- Create: `Sources/Momiji/SettingsWindow.swift`
- Modify: `Sources/Momiji/MomijiInputController.swift`

**Interfaces:**
- Consumes: `MomijiSettings`、`RomajiTableStore`、`Notification.Name.momijiSettingsDidChange`

内容:
- `MomijiInputController.menu()` に「設定…」を追加し、SwiftUI の設定ウィンドウを開く
- 項目: 選択キー（Dvorak / QWERTY のピッカー）、ローマ字テーブル（現在の名前・「ファイルから読み込む…」・「標準に戻す」）、Zenzai（トグル）、自動サジェスト（トグル）
- 変更したらすぐ保存し `momijiSettingsDidChange` を送る。読み込み失敗時は `RomajiTableImportError` の行番号をアラートで出す
- 次のキー入力から反映される（再起動不要）

- [ ] **Step 1: 実装**
- [ ] **Step 2: `scripts/install.sh` で入れ直す**
- [ ] **Step 3: 手動確認（ユーザーに依頼）** 入力メニュー → 設定… → `dvorak_jp.tsv` を読み込む → 元ファイルを別名にしても `cana` で「かな」が入る。選択キーを QWERTY にすると候補ウィンドウのラベルが `a s d f …` に変わる。Zenzai をオフにしても変換できる
- [ ] **Step 4: Commit** `git commit -m "feat: 設定画面を追加"`

---

## 設計書との差分（実装者向けメモ）

- 設計書の「選んだ候補を注目文節に入れて、未確定文字列全体を確定する」は、azooKey モデルでは「選んだ候補を確定し、残りの読みを先頭候補で順に確定する」で実現する（Task 5 の全体確定）
- `kotoeri.tsv` の文節移動（←→）は、azooKey モデルに「2番目以降の文節にフォーカスする」状態がないため、先頭文節の境界移動として扱う（Task 4）
