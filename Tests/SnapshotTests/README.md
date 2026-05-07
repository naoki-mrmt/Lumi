# SnapshotTests

主要画面 (AppView / MatchInputView / MatchViewerView / ReviewView / ReportView) の
**ライト + ダーク モード Snapshot Tests**。`swift-snapshot-testing` を利用。

## 実行環境

- iOS シミュレータ専用 (`UIHostingController` + `UIScreen` 依存)。
- すべてのテストファイルは `#if os(iOS) && canImport(UIKit)` でガードされており、
  `swift test` (macOS host) では何も実行されない。
- 実行するには `xcodebuild test` を iPad Pro 13" シミュレータに対して実行。

```bash
make test-xcode
# = DEVELOPER_DIR=$XCODE xcodebuild test -project Lumi.xcodeproj -scheme Lumi \
#       -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' ...
```

## 初回 (記録モード)

各 `@Suite(... .disabled("..."))` から `.disabled(...)` を一旦外し、
ファイル先頭で `withSnapshotTesting(record: .all)` を有効にして実行。

例:

```swift
@MainActor
@Suite("AppView Snapshots")
struct AppViewSnapshotTests {
    init() { isRecording = true }   // 初回のみ
    @Test func appView_light() { ... }
}
```

または `assertSnapshot(of: host, as: .image(on: .iPadPro13), record: true)` を一時的に指定。

実行すると Tests/SnapshotTests/__Snapshots__/<TestSuite>/<test>.png が生成される。
コミット後、`record` フラグを外して再度テストすると差分検証になる。

## CI

CI は `swift test` をデフォルトとし、Snapshot Tests は手動 (`make test-xcode`) で
回す方針。Snapshot 差分を PR で確認したい場合は GitHub Actions で xcodebuild を
追加するワークフローを別途用意。
