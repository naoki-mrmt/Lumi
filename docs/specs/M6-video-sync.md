# 仕様書: M6 — 動画後付け同期

**Status**: draft
**作成日**: 2026-05-05

---

## 1. 目的 (Phase 1 簡易版)

別撮りした試合動画を取り込み、各プレーから動画の該当シーンに大雑把にジャンプ。

## 2. スコープ

| モジュール | 役割 |
|---|---|
| `Models` | `Match.videoStartOffsetSeconds` / `Match.videoLocalURL` 追加 |
| `VideoSync` | `videoOffsetForPlay(:match:)` 純粋関数 |
| (UI) `ReviewFeature` 拡張 | 動画選択・開始時刻マーク・プレーから seek 再生 (簡易) |

## 3. データモデル拡張

```swift
extension Match {
    public var videoStartOffsetSeconds: Double?   // 動画上での「試合開始」秒
    public var videoLocalPath: String?            // Documents 配下の相対パス
}
```

## 4. VideoSync ロジック

```swift
public enum VideoSync: Sendable {
    public static func videoOffset(forPlay play: Play, match: Match) -> TimeInterval? {
        guard let videoStart = match.videoStartOffsetSeconds else { return nil }
        let elapsed = play.timestamp.timeIntervalSince(match.startTime)
        return videoStart + elapsed
    }
}
```

純粋関数。プレー以外 (タイムアウト等) も同じ計算で適用可能。

## 5. UI (Phase 1 範囲)

`ReviewFeature` に動画タブを追加し、以下を実装:

- ファイル選択 (`fileImporter`)
- 試合開始時刻マーク UI (現在再生位置を `videoStartOffsetSeconds` に保存)
- プレー一覧から該当 offset へ seek

実装は AVKit の `VideoPlayer` を使う。**iOS のみ動作**、macOS テストはコンパイル可能性のみ確認。

## 6. テスト戦略

- `VideoSyncTests`:
  - 動画未同期 (offset nil) → nil
  - 試合開始 + 0 秒 + プレー時刻 30 秒 → 30 秒
  - 動画開始 + 60 秒 + プレー時刻 30 秒 → 90 秒
  - プレーが試合開始前 (負の elapsed) でも値を返す

## 7. 完了判定

- [ ] Match 拡張
- [ ] VideoSync + テスト
- [ ] iPad iOS 26 ビルド緑
- [ ] (UI は Phase 2.2 で再評価)
