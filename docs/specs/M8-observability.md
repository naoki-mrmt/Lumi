# 仕様書: M8 — 観測性・クラッシュレポート

**Status**: draft
**作成日**: 2026-05-05

---

## 1. 目的

Sentry + OSLog で本番運用時のクラッシュ・エラー・パフォーマンス問題を検知。

## 2. スコープ

| 領域 | 内容 |
|---|---|
| Sentry | options.dsn / environment / tracesSampleRate, beforeSend で PII マスク |
| OSLog | sync / input / auth / stats / pdf / video / ui の 7 カテゴリ |
| Breadcrumbs | 重要操作 (プレー記録・試合切替・認証) を Sentry に追加 |
| Performance | sync.push / stats.compute を transaction 計測 |
| PII | 選手名・チーム名・メールはマスク |

## 3. Telemetry モジュール拡張

```swift
public enum Telemetry {
    public static func start(dsn: String, environment: String, tracesSampleRate: Double)

    /// breadcrumb 追加 (PII を含めないこと)
    public static func breadcrumb(category: BreadcrumbCategory, message: String, data: [String: String]?)

    /// 計測ブロック
    public static func measure<T>(_ name: String, op: String, block: () async throws -> T) async rethrows -> T
}

public enum BreadcrumbCategory: String, Sendable {
    case match, input, sync, auth, stats, ui
}
```

## 4. OSLog カテゴリ

`Telemetry` モジュール内で公開:
```swift
extension Logger {
    public static let sync = Logger(subsystem: "com.muramoto-co.lumi", category: "sync")
    public static let input = Logger(subsystem: "com.muramoto-co.lumi", category: "input")
    public static let auth = Logger(subsystem: "com.muramoto-co.lumi", category: "auth")
    public static let stats = Logger(subsystem: "com.muramoto-co.lumi", category: "stats")
    public static let pdf = Logger(subsystem: "com.muramoto-co.lumi", category: "pdf")
    public static let video = Logger(subsystem: "com.muramoto-co.lumi", category: "video")
    public static let ui = Logger(subsystem: "com.muramoto-co.lumi", category: "ui")
}
```

## 5. PII サニタイズ

`beforeSend` フックで以下を null/マスクに:
- event.user.email
- event.user.username
- contexts.match.opponent_team_name
- contexts.player.name

## 6. テスト戦略

- `TelemetryTests`: breadcrumb / measure の API 呼び出しがクラッシュしない
- 実際の Sentry 到達は本番環境セットアップ後に手動確認

## 7. 完了判定

- [ ] Telemetry 拡張 API
- [ ] OSLog カテゴリ 7 種
- [ ] AppFeature / MatchInputFeature の主要アクションで breadcrumb
- [ ] iPad iOS 26 ビルド緑

## 8. Phase 2 / 環境依存

- 実 Sentry ダッシュボードへの到達確認は本番セットアップ後
- `SentrySDK.crash()` を呼ぶデバッグメニューは Phase 2 で追加
