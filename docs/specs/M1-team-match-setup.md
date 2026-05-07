# 仕様書: M1 — チーム・試合・サービス順

**Status**: draft
**作成日**: 2026-05-03
**関連**: `docs/03_DOMAIN_MODEL.md`, `docs/tasks/M1_team_match_setup.md`

---

## 1. 目的

9人制の心臓部である「サービス順管理」と前提となるドメインモデル（チーム・選手・試合）を実装する。
ロジックは純粋関数として作り、Feature 層から TCA 経由で呼び出す。

## 2. スコープ

### 2.1 対象モジュール

| 層 | モジュール | 役割 |
|---|---|---|
| Domain | `Models` | 純粋 Swift の値型（struct/enum）。Equatable + Codable + Sendable |
| Domain | `ServiceOrderEngine` | サービス順純粋関数。Models のみに依存 |
| Infrastructure | `LocalStore` | SwiftData `@Model` クラス + Models との変換 |
| Feature | `TeamManagementFeature` | 選手15人マスタ |
| Feature | `MatchSetupFeature` | 試合作成 + 前回スタメンコピー |

### 2.2 対象外（M1）

- 試合中の入力 UI（M2）
- KPI計算（M3）
- Supabase同期（M4）
- 認証（M4）

## 3. データモデル設計（Models 層）

すべて `struct` で値型。`Equatable, Hashable, Codable, Sendable, Identifiable` を実装。

### 3.1 Player

```swift
public struct Player: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var teamId: UUID
    public var jerseyNumber: Int
    public var name: String
    public var positionTendency: PositionTendency?
    public var isActive: Bool
    public let createdAt: Date
}

public enum PositionTendency: String, Codable, CaseIterable, Sendable {
    case fl, fc, fr, hl, hc, hr, bl, bc, br, custom
}
```

### 3.2 Team

```swift
public struct Team: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var ownerId: UUID
    public var name: String
    public let createdAt: Date
    public var updatedAt: Date
}
```

### 3.3 Match

```swift
public struct Match: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var teamId: UUID
    public var recorderId: UUID
    public var matchCode: String
    public var matchCodeExpiresAt: Date
    public var date: Date
    public var startTime: Date
    public var endTime: Date?
    public var opponentTeamName: String
    public var tournamentName: String?
    public var matchType: MatchType
    public var venue: String?
    public var status: MatchStatus
    public var members: [MatchMember]
    public var serviceOrders: [ServiceOrderEntry]
    public var sets: [MatchSet]
    public let createdAt: Date
    public var updatedAt: Date
}

public enum MatchType: String, Codable, CaseIterable, Sendable {
    case official, practice, trainingCamp
}

public enum MatchStatus: String, Codable, CaseIterable, Sendable {
    case preparing, inProgress, finished, abandoned
}
```

### 3.4 MatchMember

```swift
public struct MatchMember: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var matchId: UUID
    public var playerId: UUID
    public var isStarter: Bool
}
```

### 3.5 ServiceOrderEntry

```swift
public struct ServiceOrderEntry: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var matchId: UUID
    public var order: Int               // 1〜9
    public var startingPlayerId: UUID
    public var currentPlayerId: UUID
}
```

### 3.6 MatchSet

```swift
public struct MatchSet: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var matchId: UUID
    public var setNumber: Int
    public var formation: Formation
    public var customFormation: String?
    public var ourScoreFinal: Int?
    public var opponentScoreFinal: Int?
    public var startedAt: Date
    public var endedAt: Date?
    public var substitutions: [Substitution]
    public var lastServingOrder: Int?    // セット最終サーバーの順位（次セット初手算出用）
    public var lastServingTeam: Team.ServingSide?
}

public enum Formation: String, Codable, CaseIterable, Sendable {
    case f5_1_3 = "5-1-3"
    case f6_3 = "6-3"
    case f4_2_3 = "4-2-3"
    case f3_3_3 = "3-3-3"
    case custom
}

extension Team {
    public enum ServingSide: String, Codable, Sendable {
        case own, opponent
    }
}
```

### 3.7 Substitution

```swift
public struct Substitution: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var setId: UUID
    public var ourScore: Int
    public var opponentScore: Int
    public var playerInId: UUID
    public var playerOutId: UUID
    public var serviceOrderId: UUID
    public var substitutionCountInSet: Int   // セット内何回目
    public var timestamp: Date
}
```

> 注：M1 では Rally / Play / Timeout は最小限の構造のみ宣言。詳細は M2 で拡張。

## 4. ServiceOrderEngine 仕様

`Models` のみに依存。純粋関数（state を変更せず新しい state を返す）。

### 4.1 公開API

```swift
public struct ServiceOrderEngine: Sendable {
    public init()

    /// 現在のサーバー（自軍がサーブ権を持っている場合）
    public func currentServer(in match: Match, set: MatchSet) -> ServiceOrderEntry?

    /// 新セット開始時のサービス順初期化
    /// - 第1セット: order=1 が初手
    /// - 第2セット以降: 前セット最終サーバーの「次」の order が初手
    public func initializeForNewSet(
        match: Match,
        setNumber: Int,
        startingPlayers: [(order: Int, playerId: UUID)]
    ) throws -> Match

    /// ラリー終了後のサービス順更新
    /// - winner=own の場合: そのまま（同一サーバー連続）
    /// - winner=opponent の場合: サイドアウト、自軍は次のサーブ順を準備
    public func advance(after rally: Rally, in match: Match, set: MatchSet) -> MatchSet

    /// 選手交代を反映
    /// 制約:
    ///   - 1セット最大4回
    ///   - 1回最大3人
    ///   - 同一選手の再交代は同セット1回まで
    /// 効果:
    ///   - 該当する ServiceOrderEntry の currentPlayerId を更新
    public func substitute(
        in match: Match,
        setId: UUID,
        substitutions: [(playerOut: UUID, playerIn: UUID)],
        atOurScore: Int,
        atOpponentScore: Int,
        timestamp: Date
    ) throws -> Match

    /// 再交代可能か判定
    public func canSubstituteAgain(
        in match: Match,
        setId: UUID,
        playerId: UUID
    ) -> Bool
}
```

### 4.2 エラー

```swift
public enum ServiceOrderError: Error, Equatable, Sendable {
    case substitutionLimitExceeded(setId: UUID, currentCount: Int)
    case tooManyPlayersAtOnce(requested: Int, max: Int)
    case playerNotInOrder(playerId: UUID)
    case alreadyResubstituted(playerId: UUID)
    case invalidStartingPlayers(reason: String)
    case previousSetNotFinished(setNumber: Int)
}
```

### 4.3 ロジック詳細

#### 4.3.1 初期化（initializeForNewSet）

- `setNumber == 1`：最初の `order=1` がサーバー候補。`startingPlayers` から `ServiceOrderEntry` を9件生成。
- `setNumber > 1`：前セット（`setNumber-1`）の `lastServingOrder` を参照。
  - 前セット自軍が最終サーバー（`lastServingTeam == .own`）なら、`lastServingOrder + 1`（9なら1にラップ）が新セット初手の order。
  - 前セット相手が最終サーバーなら、自軍がサイドアウトを取った時点で進めていた次の順番。**保守的解釈**: 前セット内で最後に自軍が打った順番の次。
  - 簡略化のため、`lastServingOrder` には「前セット最終的に自軍がサーブ権を保持していた最終 order」を保存し、`lastServingTeam == .own` の場合のみ次の order に進める。
  - 相手最終の場合: 前セットの `lastOwnServingOrder`（自軍が最後にサーブを打った順番）の次から始める。
- バリデーション: `startingPlayers.count == 9`、order が 1..9 ですべて埋まっている、playerId 重複なし。

#### 4.3.2 ラリー後更新（advance）

- `rally.winner == .own && rally.servingTeam == .own`: 何も変えない（連続サーブ）
- `rally.winner == .own && rally.servingTeam == .opponent`: 自軍に切替（サイドアウト）。自軍の次サーバーは「直近で自軍が最後にサーブを打った order の次」。最初の自軍サーブの場合は `order=1`（または初期化時に決定したサーバー）。
- `rally.winner == .opponent`: 相手にサーブ権、自軍の現在の order をそのまま記録（次に自軍に戻ってきたとき同じ order がサーブ）
- `MatchSet.lastServingOrder`, `lastServingTeam` を更新。

#### 4.3.3 選手交代（substitute）

- バリデーション:
  - `set.substitutions.count + 1 <= 4`（4回制限）
  - `substitutions.count <= 3`（3人制限）
  - 各 `playerOut` が現在 `serviceOrders` の `currentPlayerId` に存在
  - 各 `playerOut` が再交代でない、または `canSubstituteAgain == true`
- 効果:
  - 該当 `ServiceOrderEntry.currentPlayerId` を `playerIn` に更新
  - `MatchSet.substitutions` に追記（`substitutionCountInSet` インクリメント）

#### 4.3.4 再交代判定（canSubstituteAgain）

- 同セット内で以下の履歴があれば再交代不可：
  - スタメン A → 交代 B → 再びスタメン A → さらに交代 B（または別の選手）
- 簡略化: 該当 `ServiceOrderEntry` を見て、`currentPlayerId == startingPlayerId` に「戻った」回数が 0 のとき可、1 のとき不可。
- 別解釈: 同セット内のその `serviceOrderId` についての交代履歴の長さで判定（スタメン → 控え → スタメン → 控え = 3回目以降禁止）。
- **採用**: 「同 ServiceOrderEntry に対する Substitution が 2 回以下なら可」。これにより「先発 → 交代 → 先発」の往復までが可能。

## 5. LocalStore 仕様（SwiftData）

`@Model` クラスを別途定義し、`Models` の値型と相互変換する。

### 5.1 設計方針

- SwiftData `@Model` クラスは LocalStore モジュールに閉じる。Feature 層は値型のみ扱う。
- Repository パターン:
  - `TeamRepository`, `PlayerRepository`, `MatchRepository`
  - `liveValue` / `testValue`（インメモリ ModelContainer） / `previewValue`
- `@Dependency(\.localStore)` で TCA から注入

### 5.2 主要 @Model（M1範囲）

- `TeamRecord`, `PlayerRecord`, `MatchRecord`, `MatchMemberRecord`, `ServiceOrderRecord`, `MatchSetRecord`, `SubstitutionRecord`
- `cascade` 削除リレーションシップ

### 5.3 LocalStore Dependency

```swift
public struct LocalStore: Sendable {
    public var fetchTeams: @Sendable () async throws -> [Team]
    public var saveTeam: @Sendable (Team) async throws -> Void
    public var fetchPlayers: @Sendable (Team.ID) async throws -> [Player]
    public var savePlayer: @Sendable (Player) async throws -> Void
    public var deletePlayer: @Sendable (Player.ID) async throws -> Void
    public var fetchMatches: @Sendable (Team.ID) async throws -> [Match]
    public var saveMatch: @Sendable (Match) async throws -> Void
    public var fetchLastMatch: @Sendable (Team.ID) async throws -> Match?
}
```

> M1 ではこの形のシム関数群で先にスタブを切り、機能ごとに live 実装を埋めていく。

## 6. Feature 層

### 6.1 TeamManagementFeature

- 選手リスト表示、追加、編集、削除（在籍中フラグ切替）
- 「最大15人」を超える場合はエラーアラート

### 6.2 MatchSetupFeature

- 試合基本情報入力（対戦相手・大会名・試合タイプ・会場・日時）
- スタメン9人選択（在籍中の選手から）
- サービス順並び替え（ドラッグで順序変更）
- フォーメーション選択
- 「前回スタメンコピー」ボタン → 直近試合の `MatchMember(starter)` と `ServiceOrderEntry` を引き継ぐ

## 7. テスト戦略

### 7.1 ServiceOrderEngineTests（M1-T10、95%目標）

| ケース | 期待 |
|---|---|
| セット1初期化 | order=1 のスタメンがサーバー候補 |
| 自軍得点継続 | 同じ order、同じ player |
| サイドアウト→自軍復帰 | 次の order がサーブ |
| サイドアウト中も自軍 currentServingOrder は据え置き |
| セット2初期化 | 前セット最終自軍 serving order + 1（1〜9でラップ） |
| 選手交代1回 | currentPlayerId が更新、startingPlayerId は不変 |
| 同セット5回目交代 | error: substitutionLimitExceeded |
| 1回4人交代 | error: tooManyPlayersAtOnce |
| 先発↔交代の再交代 | OK |
| 再々交代（3回目） | error: alreadyResubstituted |
| 不在選手の交代 | error: playerNotInOrder |
| startingPlayers 8人 | error: invalidStartingPlayers |
| startingPlayers 重複 | error: invalidStartingPlayers |
| order が 1..9 を網羅していない | error: invalidStartingPlayers |

### 7.2 ModelsTests

- Codable round-trip
- 値型の equality

### 7.3 Feature テスト（M1-T7, T8）

- TestStore で「選手追加 → fetch → state 更新」フロー
- 「前回スタメンコピー」アクションで state にスタメン9人とサービス順がセットされる

## 8. 完了判定

- [ ] Models / LocalStore / ServiceOrderEngine / TeamManagementFeature / MatchSetupFeature の全モジュールビルド成功
- [ ] `swift test` または `xcodebuild test` で全テスト緑
- [ ] ServiceOrderEngineTests の網羅: 上記7.1のケース全カバー
- [ ] iPad シミュレータ起動 + 試合作成画面で 9 人選択・サービス順並び替えが動作（手動確認）

## 9. 未決事項

- 試合コード生成ロジック（M4 に持ち越し）
- match_code_expires_at の設定（M4 で確定）
- Supabase 同期に必要な追加メタフィールド（M4 で追加）

## 10. 段取り

1. Models スタブ（純粋値型のみ） → ModelsTests
2. ServiceOrderEngine API シグネチャ → 失敗するテスト → 実装 → リファクタ
3. LocalStore @Model 定義 → in-memory テスト
4. TeamManagementFeature TCA 雛形 → TestStore
5. MatchSetupFeature TCA 雛形 → 前回スタメンコピー
6. iPad シミュレータで手動確認
