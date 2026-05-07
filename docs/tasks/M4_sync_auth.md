# M4: 同期・認証

## 目的

Recorder/Viewer の リアルタイム同期、認証（Sign in with Apple）、試合コードによるViewer参加、オフライン耐性の中核を実装する。Supabase Realtime と接続し、ネット切断時のバッファリングと自動再送、クラッシュ時のリカバリも組み込む。

## 完了条件（DoD）

- [ ] Supabase 全テーブルのスキーマ定義・マイグレーションSQLが用意済み
- [ ] Row Level Security ポリシーが正しく動作（自チーム外データはアクセス不可）
- [ ] AuthFeature で Sign in with Apple ログインが完了
- [ ] SyncEngine がプレー単位の push と subscribe を実装
- [ ] ローカルバッファリングが動作（送信失敗時に保留・復帰時に再送）
- [ ] NetworkMonitor がオンライン/オフライン状態を検知
- [ ] 指数バックオフ再送が動作（1→2→4→8→16秒）
- [ ] Viewer が Supabase Realtime で試合データを購読
- [ ] 試合コード生成・検証が動作（6桁・24時間有効）
- [ ] Recorder衝突防止が動作（後参加端末は自動Viewer）
- [ ] 10秒ごとの State スナップショットが保存
- [ ] 起動時に「中断中の試合を復元しますか？」ダイアログ

## 関連ドキュメント

- `docs/06_DATA_SYNC.md` — 同期戦略・スキーマ・RLS
- `docs/07_AUTH.md` — Sign in with Apple実装・試合コード設計
- `docs/02_FEATURE_SPEC.md` — F-1.0.10 〜 F-1.0.14
- `docs/05_TECH_ARCHITECTURE.md` — Supabase連携の設計

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M4-T1 | Supabaseスキーマ定義（マイグレーション） | docs/06_DATA_SYNC.md 4.1 のSQL全部 |
| M4-T2 | Row Level Security 設定 | 自チーム外データはアクセス不可をテストで確認 |
| M4-T3 | AuthFeature（Sign in with Apple） | nonce生成・ID Token受領・Supabase連携 |
| M4-T4 | SyncEngine 実装 | push/subscribe APIをモック可能に設計 |
| M4-T5 | ローカルバッファリング | SwiftData に PendingPlay テーブル、送信成功時に削除 |
| M4-T6 | オフライン検知（NetworkMonitor） | NWPathMonitor で監視、State に反映 |
| M4-T7 | 指数バックオフ再送 | 1→2→4→8→16→60秒、最大5回失敗で手動リトライ表示 |
| M4-T8 | Realtime購読（Viewer） | Supabase Realtime で plays/rallies/sets テーブルを購読 |
| M4-T9 | 試合コード生成・検証 | 32文字セットから6桁、Supabase で重複チェック |
| M4-T10 | Recorder衝突防止 | current_recorder_device_id を Supabase で管理 |
| M4-T11 | 10秒ごとState スナップショット | TCA Effect で定期実行、SwiftData に保存 |
| M4-T12 | 起動時クラッシュ復元ダイアログ | status='in_progress' の試合を検知してプロンプト |

## 実装メモ

### Supabase スキーマ設定の流れ

1. Supabase Dashboard でプロジェクト作成
2. SQL Editor で `docs/06_DATA_SYNC.md` 4.1 のSQLを実行
3. Authentication > Providers > Apple を有効化
4. Realtime > 該当テーブルに有効化
5. Row Level Security をすべてのテーブルで有効化

### マイグレーション管理

`supabase/migrations/` ディレクトリに連番付きSQLファイル：

```
Supabase/
├── migrations/
│   ├── 0001_initial_schema.sql      ← 全テーブル定義
│   ├── 0002_rls_policies.sql        ← RLS設定
│   ├── 0003_indexes.sql             ← インデックス
│   └── 0004_realtime_publication.sql
```

ローカル開発時：`supabase migration up` で適用。

### Sign in with Apple ＋ Supabase Auth

```swift
// AuthFeature 内
case .signInWithAppleButtonTapped:
  return .run { send in
    let nonce = randomNonce()
    let hashedNonce = sha256(nonce)
    
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = hashedNonce
    
    // ASAuthorizationController で結果取得
    // 結果から idToken を抽出
    
    try await SupabaseClient.shared.auth.signInWithIdToken(
      credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
    )
    
    await send(.signInSucceeded)
  }
```

### SyncEngine インターフェース

```swift
public protocol SyncEngine {
  func push(_ play: Play) async throws
  func push(_ rally: Rally) async throws
  func push(_ timeout: Timeout) async throws
  func push(_ substitution: Substitution) async throws
  
  func subscribe(to matchId: UUID) -> AsyncStream<MatchUpdate>
  func unsubscribe()
  
  func flush() async throws  // バッファ全送信
}

public enum MatchUpdate {
  case playAdded(Play)
  case rallyEnded(Rally)
  case timeoutCalled(Timeout)
  case substitutionMade(Substitution)
  case scoreChanged(score: (us: Int, opp: Int))
}
```

### ローカルバッファ

```swift
@Model
final class PendingPlay {
  @Attribute(.unique) var id: UUID
  var matchId: UUID
  var rallyId: UUID
  var playJSON: String  // Play を JSON エンコード
  var attemptCount: Int
  var lastAttemptAt: Date
  var nextRetryAt: Date
}
```

送信成功 → 削除。失敗 → `attemptCount += 1`、`nextRetryAt = now + backoff(attemptCount)`。

### 指数バックオフ計算

```swift
func backoffDelay(attemptCount: Int) -> TimeInterval {
  switch attemptCount {
  case 0: return 1
  case 1: return 2
  case 2: return 4
  case 3: return 8
  case 4: return 16
  default: return 60  // 5回以上は60秒間隔
  }
}
```

5回失敗したら手動リトライボタンを表示。

### Realtime購読の例

```swift
let channel = SupabaseClient.shared.realtime.channel("match-\(matchId)")

channel.onPostgresChange(
  AnyAction.self,
  schema: "public",
  table: "plays",
  filter: "rally_id=in.(\(rallyIds))"
) { payload in
  // payload を MatchUpdate に変換して送出
}

await channel.subscribe()
```

### 試合コード生成

```swift
public struct MatchCodeGenerator {
  private static let charset: [Character] = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
  
  public static func generate() -> String {
    String((0..<6).map { _ in charset.randomElement()! })
  }
}

// 重複チェック付きで生成（Supabase に問い合わせて未使用を確認）
func generateUniqueMatchCode() async throws -> String {
  for _ in 0..<10 {
    let code = MatchCodeGenerator.generate()
    let exists = try await checkExists(code: code)
    if !exists { return code }
  }
  throw AuthError.failedToGenerateUniqueCode
}
```

### Recorder衝突防止

`matches.current_recorder_device_id` カラム + 各端末の `UIDevice.current.identifierForVendor`：

```swift
func tryBecomeRecorder(matchId: UUID) async throws -> RecorderResult {
  let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
  
  let response = try await SupabaseClient.shared
    .from("matches")
    .update(["current_recorder_device_id": deviceId])
    .eq("id", value: matchId)
    .eq("recorder_id", value: currentUserId)  // 自分の試合のみ
    .or("current_recorder_device_id.is.null,current_recorder_device_id.eq.\(deviceId)")
    .select()
    .single()
    .execute()
  
  if response.value != nil {
    return .recorder
  } else {
    return .viewer  // 他端末がRecorder中
  }
}
```

### 10秒ごとスナップショット

```swift
@Reducer
public struct MatchInputFeature {
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      // ...
    }
    
    Reduce { state, action in
      switch action {
      case .startSnapshotting:
        return .run { send in
          for await _ in Timer.publish(every: 10, on: .main, in: .default).autoconnect().values {
            await send(.snapshotRequested)
          }
        }
        .cancellable(id: "snapshot")
      
      case .snapshotRequested:
        // SwiftData に State をシリアライズして保存
        return .run { [match = state.match, currentRally = state.currentRally] _ in
          try await localStore.saveSnapshot(match: match, currentRally: currentRally)
        }
      // ...
      }
    }
  }
}
```

### 起動時のリカバリ

```swift
// AppFeature.onAppear
case .onAppear:
  return .run { send in
    let pendingMatch = try await localStore.findInProgressMatch()
    if let match = pendingMatch {
      await send(.recoveryDialogPresented(match))
    }
  }
```

## CC に渡すプロンプト雛形

```
M4 を進めてほしい。
docs/progress.json で M3 が completed であることを確認。
docs/06_DATA_SYNC.md と docs/07_AUTH.md を熟読の上、
docs/tasks/M4_sync_auth.md の M4-T1 から順に実装。

特に：
- M4-T1: docs/06_DATA_SYNC.md 4.1 のSQLを正確に再現。Supabase Dashboard で実行
- M4-T2: RLS は「自チーム外のデータが見えない」ことをテストで証明
- M4-T3: nonce生成・ハッシュ化は docs/07_AUTH.md 2.2 のサンプル参照
- M4-T7: 指数バックオフは正確に1→2→4→8→16→60秒
- M4-T11: スナップショットは TCA Effect の Timer.publish で実装

各タスク完了ごとに progress.json 更新。
M4 はインフラ寄りで重い、各タスクを丁寧に。
```
