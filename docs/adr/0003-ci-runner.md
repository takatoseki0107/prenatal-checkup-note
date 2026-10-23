# ADR 0003: CI は GitHub Actions の Xcode 27 イメージで動かす

- 状態：採用
- 日付：2026-10-23

## 状況

プロジェクトは Xcode 27 の形式（`objectVersion = 110`）で作られています。GitHub Actions の `macos-26` イメージの既定は Xcode 26.6 で、Xcode 27 は `xcode-27` ラベルのイメージに入っています（2026 年 10 月時点で public preview）。費用はできるだけかけない前提です。

## 決定

- `runs-on: xcode-27`（標準サイズ）で、プルリクエストと `main` への push のたびにビルドとテストを実行します。
- テストを動かす iPhone シミュレーターは、イメージにあるものから自動で選びます。名前は固定しません。
- シミュレーター向けなので署名はしません（`CODE_SIGNING_ALLOWED=NO`）。

## 理由

- 古い Xcode では、新しい形式のプロジェクトを開けないおそれがあります。
- 公開リポジトリでは、標準サイズの GitHub ホストランナーは無料の範囲で使えます。大きいサイズ（`-xlarge`）は使いません。
- シミュレーターの名前は、イメージの更新で変わることがあります。

## 影響とリスク

- preview のため、動作が不安定だったり、待ち時間が長かったりする可能性があります。
- Xcode 27 が通常の macOS イメージ（`macos-26` など）の既定になったら、そちらに移ります。
- 最初の実行のあとに、GitHub の Billing で料金が発生していないことを確かめます。

## 参考

- [actions/runner-images: Xcode 27 is now available as a public preview](https://github.com/actions/runner-images/issues/14404)
