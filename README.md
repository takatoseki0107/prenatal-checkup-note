# 妊婦健診ノート（仮称）

> 開発中です。実際に使う妻の反応を受けて、要件定義を簡単版（v0.4）に作り直しました（[ADR 0005](docs/adr/0005-simplify-to-v0.4.md)）。v0.3 の試作はタグ `v0.3-prototype` に残しています。段階 A（保存の土台）、段階 B（画面）、段階 C（お知らせ）、段階 D（検索・共有・サンプルデータ）、段階 E（健診後メモの写真）まで作り、確かめました（[段階 B](docs/verification/stage-b.md)、[段階 C](docs/verification/stage-c.md)、[段階 D](docs/verification/stage-d.md)、[段階 E](docs/verification/stage-e.md)）。最初に、無料の個人チームで実機に入れて必要な機能が動くことを確かめました（[結果](docs/verification/device-check.md)）。

妊婦健診で聞きたいことを書き留め、診察では一覧を見ながら聞き、先生の答えと説明を「健診後メモ」に残して、あとで見返せる iPhone アプリです。次の健診の日付・持ち物・前日の夜のお知らせも扱います。データは iPhone の中に保存し、アプリ独自のサーバーへの送信やクラウド同期はしません。

## 動かし方

- 必要なもの：Xcode 27、iOS 26 以降のシミュレーターまたは実機
- `PrenatalCheckupNote.xcodeproj` を開き、スキーム `PrenatalCheckupNote` を選んで実行します。
- テストは Xcode で ⌘U、またはターミナルで次のコマンドを実行します（シミュレーター名は手元の環境に合わせてください）。

```sh
xcodebuild test \
  -project PrenatalCheckupNote.xcodeproj \
  -scheme PrenatalCheckupNote \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

## 使っている技術

- Swift 6（言語モード 6、厳格な並行性チェック）
- SwiftUI
- SwiftData（段階 A 以降）
- Swift Testing（ロジックのテスト）、XCUITest（画面のテスト）
- GitHub Actions（プルリクエストごとにビルドとテストを実行）

## 進め方

- 機能ごとに Issue とプルリクエストを作り、プルリクエストには変更内容と判断の理由を書きます。
- 技術選定などの重要な判断は [docs/adr](docs/adr) に記録します。
- 実機での確認や技術検証の結果は [docs/verification](docs/verification) に記録します。
- 設計とコードのレビュー、実装の補助に AI（Claude・ChatGPT）を使っています。取り込む内容は、開発者が動作を確かめ、説明できる状態にしています。
- アプリのアイコンは、開発者が ChatGPT（画像の生成）で作りました。
