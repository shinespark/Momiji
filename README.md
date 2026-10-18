# Momiji

Dvorak 配列で使うための、自分用の macOS 日本語 IME。

変換候補をホームポジションのキーで選んで、その場で確定できる。
選択キーは Dvorak（`a o e u i d h t n s`）と QWERTY（`a s d f g h j k l ;`）を切り替えられる。
変換エンジンには [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter) と Zenzai（ニューラル変換）を使っている。

自分だけが使う前提で作っているので、配布や公証（notarization）はしていない。

## 特徴

- ホームポジションのキーで候補を選んで即確定する。数字キー `1`〜`0` でも選べる
- Google 日本語入力形式のローマ字テーブル（[dvorakjp-roman-table](https://github.com/shinespark/dvorakjp-roman-table) の `dvorak_jp.tsv` など）を読み込める
- 操作は mozc の [ことえり風キー設定](https://github.com/google/mozc/blob/master/src/data/keymap/kotoeri.tsv) にならう
- ライブ変換はせず、Space で変換する
- Tab で予測変換を出せる。入力中は予測候補を自動でサジェストする

Momiji はひらがなの入力モードだけを持つ。
英字は OS の入力ソースを ABC などに切り替えて打つ。

## インストール

Xcode と、Apple Development の署名用証明書（Personal Team でよい）が必要。

```bash
scripts/install.sh
```

`install.sh` は次の順に処理する。

1. Zenzai のモデルを Hugging Face から `Resources/zenzai/` に取得する（すでにあればスキップ）
2. release ビルドして `build/Momiji.app` を作り、署名する
3. 動いている Momiji を止めて、`~/Library/Input Methods/Momiji.app` に配置する

初回は、ログインし直してから「システム設定 > キーボード > 入力ソース」に Momiji を追加する。

### 新しいバージョンに入れ直す

main を最新にして `scripts/install.sh` を実行し直す。
入れ直した後は、いったん別の入力ソースに切り替えてから Momiji に戻すと新しいバージョンが起動する。
アイコンや `Info.plist` の変更は macOS にキャッシュされることがあるので、反映されなければログインし直す。

## 使い方

| キー | 動作 |
| --- | --- |
| Space | 変換。変換中にもう一度押すと候補ウィンドウを出す |
| 選択キー / `1`〜`0` | 候補ウィンドウの候補で即確定する |
| Tab | 予測変換の候補ウィンドウを出す |
| Enter | 確定 |
| Esc | 取り消し |
| Shift+← / Shift+→ | 文節の区切り直し |
| Option+Z / Ctrl+J / F6 | ひらがな |
| Option+X / Ctrl+K / F7 | 全角カタカナ |
| Option+A / Ctrl+; / F8 | 半角 |
| Option+C / Ctrl+L / F9 | 全角英数 |
| Option+S / F10 | 半角英数 |

選択キーは候補ウィンドウが出ている間だけ候補の選択に使われる。
それ以外のときは普通の文字として入力される。

### 設定

入力メニューの「設定…」から開く。

- 選択キー: Dvorak / QWERTY
- ローマ字テーブル: Google 日本語入力形式の TSV の読み込みと、標準のテーブルへの戻し
- Zenzai: オン / オフ
- 自動サジェスト: オン / オフ

読み込んだローマ字テーブルと変換の学習データは `~/Library/Application Support/Momiji/` に保存する。
読み込んだ後は元の TSV を消しても使い続けられる。

## 開発

```bash
swift build
swift test
```

変換精度だけを確かめたいときは `momiji-try` を使う。
標準入力から 1 行ずつ読みを渡すと、変換候補を 5 件まで出力する。

```bash
scripts/fetch-zenzai-model.sh
echo "kanji" | swift run momiji-try
```

`--table <TSV>` を付けると Google 日本語入力形式のローマ字テーブルを使い、`--no-zenzai` を付けると Zenzai を使わずに変換する。

| ディレクトリ | 内容 |
| --- | --- |
| `Sources/MomijiCore` | 入力セッションの状態遷移、キー設定、ローマ字テーブルの変換、設定 |
| `Sources/MomijiConverter` | AzooKeyKanaKanjiConverter のラッパー |
| `Sources/Momiji` | InputMethodKit のアプリ本体、候補ウィンドウ、設定画面 |
| `Sources/momiji-try` | 精度確認用の CLI |
| `docs/superpowers` | 設計書と実装計画 |
