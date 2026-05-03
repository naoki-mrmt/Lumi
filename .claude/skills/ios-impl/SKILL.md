# ios-impl

iOS/macOS 実装スキル。仕様書に基づき TCA + SwiftUI + SPM で実装する。

## Trigger
- `/ios-impl <spec-path>` または仕様書を指定して実装依頼されたとき
- iOS/macOS 機能の実装タスク

## Input
- 仕様書パス (docs/specs/*.md)
- または実装する機能の説明

## Output
- TCA Reducer + SwiftUI View
- DependencyKey 定義
- TestStore を使ったユニットテスト
- 必要に応じて Domain 層のプロトコル・実装
