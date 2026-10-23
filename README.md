# 妊婦健診ノート（仮称）

> 開発中です。いまは共通の準備（プロジェクト設定と自動テスト）を終え、段階1（画面の試作）と段階2（データの核）に進むところです。

妊婦健診で聞きたいことを整理し、診察中に確認し、回答と次回への持ち越しまで残せる iPhone アプリです。健康記録は端末の中だけに保存し、外部には送信しません。

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
- SwiftData（段階2以降）
- Swift Testing（ロジックのテスト）、XCUITest（画面のテスト）
- GitHub Actions（プルリクエストごとにビルドとテストを実行）

## 進め方

- 機能ごとに Issue とプルリクエストを作り、プルリクエストには変更内容と判断の理由を書きます。
- 技術選定などの重要な判断は [docs/adr](docs/adr) に記録します。
- 設計とコードのレビュー、実装の補助に AI（Claude・ChatGPT）を使っています。取り込む内容は、開発者が動作を確かめ、説明できる状態にしています。
