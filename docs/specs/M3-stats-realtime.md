# 仕様書: M3 — KPI計算・リアルタイム表示

**Status**: draft
**作成日**: 2026-05-04
**関連**: `docs/03_DOMAIN_MODEL.md`, `docs/04_UI_DESIGN.md`, `docs/tasks/M3_stats_realtime.md`

---

## 1. 目的

入力されたプレーデータから KPI を計算する `StatsEngine` と、それをリアルタイム表示する `MatchViewerFeature` を完成させる。

## 2. スコープ

| 層 | モジュール | 役割 |
|---|---|---|
| Domain | `StatsEngine` | チーム集計 / 選手別 / 連続得点 / アシスト判定 (純粋関数) |
| Feature | `MatchViewerFeature` | KPI ダッシュボード / 得点推移グラフ / フィルタ |

## 3. StatsEngine API

```swift
public struct StatsEngine: Sendable {
    public init()

    /// チーム全体集計 (own / opponent)
    public func teamStats(in match: Match, scope: StatsScope, side: Team.ServingSide) -> TeamStats

    /// 選手別集計 (自軍のみ)
    public func playerStats(playerId: UUID, in match: Match, scope: StatsScope) -> PlayerStats

    /// 連続得点ラン抽出 (3点以上)
    public func consecutiveRuns(in set: MatchSet, threshold: Int = 3) -> [ConsecutiveRun]
}

public enum StatsScope: Equatable, Sendable {
    case wholeMatch
    case set(Int)
    case formation(Formation)
}

public struct TeamStats: Equatable, Sendable {
    // アタック
    public var attackAttempts: Int
    public var attackKills: Int
    public var attackErrors: Int
    public var attackKillRate: Double      // % (0..100)
    public var attackEfficiency: Double    // %
    // レセプション
    public var receptionAttempts: Int
    public var receptionAPasses: Int
    public var receptionBPasses: Int
    public var receptionCPasses: Int
    public var receptionDPasses: Int
    public var receptionAPassRate: Double  // %
    public var receptionReturnRate: Double // %
    // サーブ
    public var serveAttempts: Int
    public var serveAces: Int          // excellent
    public var serveErrors: Int        // error
    public var serveEfficiency: Double // %
    // ブロック / ディグ / セット
    public var blocks: Int
    public var blockKills: Int        // excellent
    public var digs: Int
    public var sets: Int
    public var assists: Int
}

public struct PlayerStats: Equatable, Sendable {
    public var playerId: UUID
    // チームと同じ計算群を選手別に
    public var attackAttempts: Int
    public var attackKills: Int
    public var attackKillRate: Double
    public var attackEfficiency: Double
    public var receptionAttempts: Int
    public var receptionAPassRate: Double
    public var serveAttempts: Int
    public var serveAces: Int
    public var assists: Int
    public var blockKills: Int
    public var digs: Int
}

public struct ConsecutiveRun: Equatable, Hashable, Sendable {
    public let team: Team.ServingSide
    public let count: Int
    public let startRallyNumber: Int
    public let endRallyNumber: Int
}
```

## 4. KPI 計算式 (docs/03_DOMAIN_MODEL.md 2.3)

```
attack_kill_rate = excellent / attempts * 100
attack_efficiency = (excellent - error) / attempts * 100
reception_a_rate = a_pass / attempts * 100
reception_return_rate = (a_pass + b_pass + c_pass) / attempts * 100
serve_efficiency = (aces - errors) / attempts * 100
```

attempts == 0 のとき割合は **0.0**（NaN ではなく）。

## 5. アシスト計算

`RallyTimeline.computeAssists` (M2 で実装済み) と同じロジック。`StatsEngine.teamStats` 計算前に各 Rally の plays に対してアシスト判定が反映されている前提（永続化時にすでに `isAssist` セット済み）。集計は `play.isAssist == true` の数を数える。

## 6. 連続得点

```
- ラリーを `setNumber` 順 → `rallyNumber` 順に並べる
- winner が同じ連続区間を1つの run として抽出
- run.count >= threshold (デフォルト3) のものだけ返す
```

## 7. MatchViewerFeature

### 7.1 State

```swift
@ObservableState
public struct State: Equatable {
    public var match: Match
    public var scope: StatsScope = .wholeMatch
    public var selectedPlayerId: UUID? = nil
    public var ownStats: TeamStats = .empty
    public var opponentStats: TeamStats = .empty
    public var playerStats: PlayerStats? = nil
    public var consecutiveRuns: [ConsecutiveRun] = []
}
```

### 7.2 主要 Action

```swift
case onAppear
case scopeChanged(StatsScope)
case playerSelected(UUID?)
case statsRecomputed(own: TeamStats, opp: TeamStats, player: PlayerStats?, runs: [ConsecutiveRun])
case matchUpdated(Match)
```

`onAppear` / `scopeChanged` / `playerSelected` / `matchUpdated` 時に Effect で再計算 → `statsRecomputed` で State 反映。

### 7.3 View レイアウト

`docs/04_UI_DESIGN.md` 6.3 に準拠。
- 上部: スコア + LIVE 表示
- 中段左: 自軍 KPI / 中段右: 相手 KPI
- 下段: 得点推移グラフ (Swift Charts) + フィルタ Picker
- 全数値 `.monospacedDigit()`

## 8. テスト戦略

### 8.1 StatsEngineTests (M3-T11、目標 90% 行カバレッジ)

| ケース | 検証 |
|---|---|
| 0打数 | 全 KPI = 0.0 |
| 1打数 1決定 | killRate=100, efficiency=100 |
| 1打数 1ミス | killRate=0, efficiency=-100 |
| 自/相手両方 | プレーチームでフィルタされること |
| scope=wholeMatch / set(N) / formation(F) | 期待件数 |
| アシスト | rally.plays に既に isAssist=true のものが集計される |
| 連続得点 | 3 連続以上で run、2 連続以下は除外、winner 切替で run 区切り |
| 選手別 | playerId が一致する Play のみカウント |

### 8.2 MatchViewerFeatureTests
- TestStore で onAppear → statsRecomputed 確認
- playerSelected で playerStats 計算

## 9. 完了判定

- [ ] StatsEngine 全関数が定義通りに動作 (Tests 緑)
- [ ] MatchViewerFeature の TestStore テスト緑
- [ ] iPad iOS 26 ビルド SUCCEEDED
- [ ] 簡易な Viewer 画面が AppFeature 経由で起動できる

## 10. 段取り

1. StatsEngine データ型定義 (TeamStats / PlayerStats / ConsecutiveRun / StatsScope)
2. テスト先書き → KPI 計算実装
3. consecutiveRuns 実装
4. MatchViewerFeature Reducer + View
5. AppFeature に Viewer 起動を追加
