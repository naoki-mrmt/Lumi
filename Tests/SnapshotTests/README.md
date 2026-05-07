# SnapshotTests

主要画面 (AppView / MatchInputView / MatchViewerView / ReviewView / ReportView) の
**ライト + ダーク モード Snapshot Tests**。`swift-snapshot-testing` を利用、iPad Pro 12.9" レイアウト。

## 実行方法

iOS シミュレータ専用 (`UIHostingController` + `UIScreen` 依存)。すべてのテストファイルは
`#if os(iOS) && canImport(UIKit)` でガードされており、`swift test` (macOS host) では
何も実行されない。実行は SPM の auto-generated scheme 経由で xcodebuild を使う:

```bash
make test-snapshots
# = DEVELOPER_DIR=$XCODE xcodebuild test \
#       -workspace . -scheme LumiKit-Package \
#       -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
#       -only-testing:SnapshotTests -skipMacroValidation
```

## 初回 / 意図的な再記録

差分が「正当な UI 変更」によるものなら、環境変数で recording モードを有効にする:

```bash
SNAPSHOT_TESTING_RECORD=missing make test-snapshots   # 不足ファイルだけ記録
SNAPSHOT_TESTING_RECORD=all     make test-snapshots   # 全件強制再記録
```

記録された `__Snapshots__/<TestSuite>/<test>.<n>.png` を `git add` してコミット。

## CI

`.github/workflows/ci.yml` の `snapshot-tests` job が macOS-15 + iPad Pro 13" (M5)
シミュレータで自動実行する。public repo はフリー枠 (実行時間無制限) なので追加課金なし。
PR 上で snapshot 差分が出た場合、CI ログに失敗詳細とハッシュ差分が出る。

## 既知の制限

- iPad Pro 13" (M5) は swift-snapshot-testing にプリセットがないため
  `.iPadPro12_9` 設定で代用 (画素・ポイントレイアウトは概ね同じ)。
- AppView は localStore を `.inMemory()` 上書きしないと findInProgressMatch で
  fatalError するため、テスト内で `withDependencies` 経由で渡している。
