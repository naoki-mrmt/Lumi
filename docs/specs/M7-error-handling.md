# 仕様書: M7 — エラーハンドリング・障害時UX

**Status**: draft
**作成日**: 2026-05-05

---

## 1. 目的

「試合中に絶対に止まらない」アプリにする。10種のエラーパターンに対応 UI を整備。

## 2. スコープ

| モジュール | 役割 |
|---|---|
| `Models` 拡張 | `AppError` enum + `Severity` enum |
| (新規) `Validators` | 試合・セット・選手交代等のドメイン制約検証 (純粋関数) |
| `DesignSystem` 拡張 | エラーバナー / トースト / モーダル の SwiftUI コンポーネント |
| (新規) `BatteryMonitor` | バッテリー監視 (Phase 1 はプロトコル + Mock) |
| `AppFeature` 拡張 | error / batteryWarning State 追加 |

## 3. AppError

```swift
public enum AppError: Error, Equatable, Identifiable, Sendable {
    case network(NetworkErrorKind)
    case auth(AuthErrorKind)
    case sync(SyncErrorKind)
    case validation(ValidationErrorKind)
    case dataInconsistency(reason: String)
    case migration(reason: String)
    case unknown(message: String)

    public var id: String { /* "kind.detail" */ }
    public var userMessage: String { /* 日本語 */ }
    public var severity: Severity { /* minor/moderate/severe/critical */ }
}

public enum Severity: String, Sendable {
    case minor       // バナー (5秒で消える)
    case moderate    // トースト
    case severe      // モーダル
    case critical    // 起動時ダイアログ (試合データ整合性等)
}
```

## 4. Validators

純粋関数で `Match` / `MatchSet` / `Substitution` の整合性を検証:
- スコア >= 0
- スタメン9人ぴったり
- 交代回数上限
- 選手 ID 重複なし

## 5. UI コンポーネント

`DesignSystem` に `ErrorBanner`, `ErrorToast`, `ErrorModal` の View を追加。

## 6. テスト戦略

- `AppErrorTests`: severity / userMessage マッピング
- `ValidatorsTests`: 各ルールの境界値
- `AppFeatureTests`: errorReceived → state.error 反映、severity に応じた UI 切替

## 7. 完了判定

- [ ] AppError + Severity 定義
- [ ] Validators モジュール + テスト
- [ ] AppFeature に error 状態
- [ ] iPad iOS 26 ビルド緑

## 8. Phase 2 へ持ち越し

- BatteryMonitor の Live 実装 (UIDevice.batteryLevel) は iOS 限定実装、Phase 2 で安定化
- SwiftData VersionedSchema は実機での動作確認が必要なので Phase 2.x で本格運用
