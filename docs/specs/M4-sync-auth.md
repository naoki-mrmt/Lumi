# 仕様書: M4 — 同期・認証

**Status**: draft
**作成日**: 2026-05-04
**関連**: `docs/06_DATA_SYNC.md`, `docs/07_AUTH.md`, `docs/tasks/M4_sync_auth.md`

---

## 1. 目的

Recorder/Viewer の リアルタイム同期、認証 (Sign in with Apple)、試合コードによる Viewer 参加、オフライン耐性。

## 2. スコープ

| 層 | モジュール | 役割 |
|---|---|---|
| Data | `supabase/migrations/` | テーブル定義 + RLS + Realtime publication |
| Infrastructure | `SupabaseClient` | Supabase SDK ラッパー、AppConfig |
| Infrastructure | `Sync` | `SyncEngine` 抽象 + Live / Mock 実装、Pending バッファ、NetworkMonitor、Backoff |
| Feature | `AuthFeature` | Sign in with Apple フロー |
| Feature (拡張) | `MatchInputFeature` | 10秒スナップショット Effect |
| Feature (拡張) | `AppFeature` | 起動時クラッシュ復元ダイアログ |
| Util | `MatchCodeGenerator` | 6桁コード生成 (純粋関数) |

## 3. 非ビルド成果物 (実環境セットアップ)

実 Supabase との結合テストはローカル CI では不可。**M4 の DoD のうち以下はコード/SQL の整備で代替**し、本番投入時にユーザー側で適用する:

- Supabase Dashboard でのプロジェクト作成・Apple Provider 有効化
- マイグレーション実行 (`supabase migration up`)
- Realtime 有効化

これらは `docs/specs/M4-sync-auth.md` で明示し、`supabase/README.md` に手順を残す。

## 4. SQL マイグレーション

`supabase/migrations/` に以下のファイルを作成:

```
0001_initial_schema.sql        — 全テーブル DDL
0002_rls_policies.sql          — RLS ON + ポリシー
0003_indexes.sql               — 検索用 index
0004_realtime_publication.sql  — supabase_realtime publication 追加
```

`docs/06_DATA_SYNC.md` の SQL を正確に転写。

## 5. SyncEngine

```swift
public protocol SyncEngine: Sendable {
    func push(_ play: Play) async throws
    func push(_ rally: Rally) async throws
    func push(_ timeout: Timeout) async throws
    func push(_ substitution: Substitution) async throws
    func push(_ match: Match) async throws

    func subscribe(matchId: UUID) -> AsyncStream<MatchUpdate>
    func unsubscribe()

    func flush() async throws
}

public enum MatchUpdate: Equatable, Sendable {
    case playAdded(Play)
    case rallyEnded(Rally)
    case timeoutCalled(Timeout)
    case substitutionMade(Substitution)
    case scoreChanged(us: Int, opp: Int)
}
```

具象:
- `LiveSyncEngine`: Supabase SDK 経由 (実機・本番)
- `MockSyncEngine`: 何もしない (テスト・Preview)
- `BufferedSyncEngine`: ローカルキューで保留→ flush で送信 (オフライン対応)

## 6. PendingPlay バッファ

```swift
public actor PendingBuffer {
    private var entries: [PendingEntry] = []
    public func enqueue(_ entry: PendingEntry)
    public func dequeue() -> PendingEntry?
    public func snapshot() -> [PendingEntry]
}

public struct PendingEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let payload: Payload
    public var attemptCount: Int
    public var lastAttemptAt: Date?
    public var nextRetryAt: Date

    public enum Payload: Equatable, Sendable {
        case play(Play)
        case rally(Rally)
        case timeout(Timeout)
        case substitution(Substitution)
        case match(Match)
    }
}
```

## 7. NetworkMonitor

```swift
public protocol NetworkMonitor: Sendable {
    var isOnline: Bool { get async }
    func observe() -> AsyncStream<Bool>
}

// Live: NWPathMonitor をラップ
// Mock: 任意の値を返す
```

## 8. Backoff

純粋関数。

```swift
public enum BackoffSchedule {
    /// 指数バックオフ (1→2→4→8→16→60秒、最大60秒)
    public static func delay(forAttempt attempt: Int) -> TimeInterval {
        switch attempt {
        case 0: return 1
        case 1: return 2
        case 2: return 4
        case 3: return 8
        case 4: return 16
        default: return 60
        }
    }

    /// 5回失敗で手動リトライへ
    public static let maxAutoAttempts = 5
}
```

## 9. MatchCodeGenerator

純粋関数。紛らわしい文字 (`0/O, 1/I/L`) を除外。

```swift
public enum MatchCodeGenerator {
    static let charset: [Character] = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    public static let codeLength = 6
    public static func generate(using rng: inout some RandomNumberGenerator) -> String
    public static func isValid(_ code: String) -> Bool   // 形式検証
}
```

`generate(using:)` を `inout` で受け取ることで決定論的テストが可能。

## 10. AuthFeature

State + 主要 Action:
```swift
public enum Action {
    case signInWithAppleTapped
    case signInSucceeded(userId: UUID, email: String?)
    case signInFailed(String)
    case signOutTapped
    case signedOut
}
```

iOS の `ASAuthorizationAppleIDProvider` 連携は `AppleSignInClient` プロトコルで抽象化。

```swift
public protocol AppleSignInClient: Sendable {
    func authorize(nonce: String) async throws -> AppleCredentials
}

public struct AppleCredentials: Equatable, Sendable {
    public let userId: String
    public let identityToken: String
    public let email: String?
    public let fullName: PersonNameComponents?
}
```

`SupabaseAuthClient` も同様に抽象化:

```swift
public protocol SupabaseAuthClient: Sendable {
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    func signOut() async throws
    var currentSession: AuthSession? { get async }
}
```

## 11. 10秒スナップショット (M4-T11)

`MatchInputFeature` に専用 Effect:
```swift
case .startSnapshotting:
    return .run { send in
        for await _ in clock.timer(interval: .seconds(10)) {
            await send(.snapshotRequested)
        }
    }
    .cancellable(id: SnapshotID.self)
```

`@Dependency(\.continuousClock)` 経由で `TestClock` 注入可能に。

## 12. クラッシュ復元 (M4-T12)

`AppFeature.onAppear` で `LocalStore.findInProgressMatch()` を呼び、結果が non-nil なら復元ダイアログを提示。

## 13. テスト戦略

- `BackoffScheduleTests`: 数値検証
- `MatchCodeGeneratorTests`: 形式・文字セット・isValid
- `PendingBufferTests`: enqueue/dequeue 順序、actor 並行性
- `NetworkMonitorTests`: モック注入で AsyncStream 動作
- `AuthFeatureTests`: TestStore + AppleSignInClient/SupabaseAuthClient モック
- `SyncEngineTests`: MockSyncEngine 動作 + BufferedSyncEngine の retry ロジック

## 14. 完了判定

- [ ] `supabase/migrations/*.sql` 4ファイル
- [ ] `Sync` モジュール: SyncEngine 抽象 + Live + Mock + Buffered
- [ ] PendingBuffer / NetworkMonitor / BackoffSchedule
- [ ] MatchCodeGenerator + テスト
- [ ] AuthFeature + Sign in with Apple クライアント抽象
- [ ] MatchInputFeature に 10秒 snapshot Effect
- [ ] AppFeature に クラッシュ復元ダイアログ
- [ ] ビルド SUCCEEDED / 全テスト緑

## 15. 未対応 (将来 / 環境依存)

- 実 Supabase での RLS 動作確認は本番セットアップ後
- Sign in with Apple は Apple Developer アカウントの設定が必要
