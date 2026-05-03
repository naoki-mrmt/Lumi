# M3: KPI計算・リアルタイム表示

## 目的

入力されたプレーデータからKPI（決定率・効果率・レセプションA率等）を計算するStatsEngineと、それをリアルタイム表示するベンチ閲覧画面（MatchViewerFeature）を完成させる。Data Volley準拠の正確な計算定義を実装する。

## 完了条件（DoD）

- [ ] StatsEngine がアタック・レセプション・サーブ・ブロック・ディグ・セットの全KPIを計算可能
- [ ] アシスト自動計算ロジックが動作（決定打の直前のセットを判定）
- [ ] 連続得点判定（3点以上ハイライト）が動作
- [ ] MatchViewerFeature がリアルタイムKPI表示を担う
- [ ] KPIダッシュボードUIが動作（自/相手両側、選手別/セット別/フォーメーション別フィルタ）
- [ ] 得点推移グラフがTOマーカー・連続得点ハイライト含めて表示
- [ ] StatsEngineTests がカバレッジ90%以上
- [ ] 主要画面のスナップショットテストが緑

## 関連ドキュメント

- `docs/02_FEATURE_SPEC.md` — F-1.0.8, F-1.0.9
- `docs/03_DOMAIN_MODEL.md` — 2.3 集計指標の計算式・2.4 アシスト自動計算ロジック
- `docs/04_UI_DESIGN.md` — 6.3 ベンチ閲覧画面ワイヤー
- `docs/08_NON_FUNCTIONAL.md` — テスト戦略（StatsEngine 90%以上）

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M3-T1 | StatsEngine（アタック決定率/効果率） | Data Volley準拠の定義で実装 |
| M3-T2 | StatsEngine（レセプション） | A率・返球率の計算 |
| M3-T3 | StatsEngine（サーブ統計） | 得点・効率（エフィシェンシー） |
| M3-T4 | StatsEngine（ブロック・ディグ・セット） | 各種カウント・成功率 |
| M3-T5 | アシスト自動計算 | 決定打の直前のセットを判定する純粋関数 |
| M3-T6 | 連続得点判定（3点以上ハイライト） | RallyのリストからRunを抽出する純粋関数 |
| M3-T7 | MatchViewerFeature 骨格 | TCA Feature、KPI再計算ロジック |
| M3-T8 | KPIダッシュボードUI | 自/相手ペア表示、Tabular Numsで揃える |
| M3-T9 | 得点推移グラフ | Swift Charts、TOマーカー、連続得点ハイライト |
| M3-T10 | 選手別/セット別/フォーメーション別フィルタ | プルダウンでフィルタ切替 |
| M3-T11 | StatsEngineTests（90%カバレッジ） | 境界値・全種類のKPI・レアケース網羅 |

## 実装メモ

### StatsEngine の API 設計

純粋関数。Models のみに依存。

```swift
public struct StatsEngine {
  /// チーム全体のKPI
  public func teamStats(for match: Match, scope: StatsScope) -> TeamStats
  
  /// 選手別KPI
  public func playerStats(for player: Player, in match: Match, scope: StatsScope) -> PlayerStats
  
  /// 連続得点のRunsを抽出
  public func consecutiveRuns(in set: Set, threshold: Int = 3) -> [ConsecutiveRun]
  
  /// アシスト判定（プレーリストから決定打→直前セットをマーク）
  public func computeAssists(in rally: Rally) -> [Play]
}

public enum StatsScope {
  case wholeMatch
  case set(Int)
  case formation(Formation)
}
```

### KPI計算式（再掲・docs/03_DOMAIN_MODEL.md 2.3より）

```
attack_kill_rate = (excellent数) / (打数) × 100
attack_efficiency = (excellent数 - error数) / (打数) × 100

reception_a_rate = (a_pass数) / (全レセプション数) × 100
reception_return_rate = (a_pass + b_pass + c_pass) / (全レセプション数) × 100

serve_efficiency = (サービスエース - サービスミス) / (全サーブ数) × 100
```

### アシスト自動計算アルゴリズム

```swift
func computeAssists(in rally: Rally) -> [Play] {
  var plays = rally.plays
  
  // 決定打を探す
  guard let killIndex = plays.firstIndex(where: {
    $0.playType == .attack &&
    $0.evaluation == .excellent &&
    $0.playTeam == .own
  }) else { return plays }
  
  // 直前のセット（同チーム・同ラリー内）を探す
  let candidateSetIndex = plays[..<killIndex].lastIndex(where: {
    $0.playType == .set && $0.playTeam == .own
  })
  
  if let setIndex = candidateSetIndex {
    plays[setIndex].isAssist = true
  }
  
  return plays
}
```

### 連続得点判定アルゴリズム

```swift
public struct ConsecutiveRun: Equatable {
  public let team: Team           // own / opponent
  public let startScoreUs: Int
  public let startScoreOpp: Int
  public let count: Int           // 連続数
  public let rallies: [Rally]
}

func consecutiveRuns(in set: Set, threshold: Int = 3) -> [ConsecutiveRun] {
  // ラリーを順序通り見て、winner が変わるたびに区切る
  // count >= threshold のものだけ返す
}
```

### KPIダッシュボードのレイアウト原則

`docs/04_UI_DESIGN.md` 6.3 のワイヤーに準拠：

- 左：自チーム / 右：相手
- 各セクションを縦に並べる（アタック・レセプション・サーブ・ブロック等）
- すべての数値で `.monospacedDigit()` 必須
- ライト/ダーク両対応のスナップショットテスト

### 得点推移グラフ

Swift Charts を使用：

```swift
import Charts

Chart {
  ForEach(rallies) { rally in
    LineMark(
      x: .value("Rally", rally.rallyNumber),
      y: .value("Our Score", rally.ourScoreAfter),
      series: .value("Team", "我々")
    )
    LineMark(
      x: .value("Rally", rally.rallyNumber),
      y: .value("Opp Score", rally.oppScoreAfter),
      series: .value("Team", "相手")
    )
  }
  
  // TOマーカー
  ForEach(timeouts) { to in
    PointMark(
      x: .value("Rally", to.rallyNumber),
      y: .value("Score", to.score)
    )
    .symbol(.cross)
  }
  
  // 連続得点ハイライト
  ForEach(consecutiveRuns) { run in
    RectangleMark(
      xStart: .value("From", run.startRally),
      xEnd: .value("To", run.endRally),
      yStart: 0,
      yEnd: 25
    )
    .opacity(0.2)
    .foregroundStyle(run.team == .own ? .green : .red)
  }
}
```

### スナップショットテストすべき画面

```
KPIダッシュボード（ライト/ダーク × 自/相手）
得点推移グラフ（連続得点あり/なし）
選手別フィルタ適用時
セット別フィルタ適用時
```

### KPI再計算のパフォーマンス

- 1ラリー追加されるたび、State 内のキャッシュを更新
- 全試合分の再計算は最初の1回のみ
- パフォーマンス目標：200ms以内（非機能要件）

## CC に渡すプロンプト雛形

```
M3 を進めてほしい。
docs/progress.json で M2 が completed であることを確認。
docs/03_DOMAIN_MODEL.md の 2.3 集計指標の計算式 を厳密に守って
StatsEngine を実装してほしい。

特に：
- M3-T1: アタック決定率と効果率は別物。両方表示できるようにする
- M3-T5: アシスト自動計算は決定打の直前のセットを判定する。docs/03_DOMAIN_MODEL.md 2.4 のロジックに従う
- M3-T6: 連続得点は3点以上で「ハイライト対象」とマーク
- M3-T11: テストカバレッジ90%以上厳守、境界値（0打数等）も網羅

UI（M3-T8, T9）は docs/04_UI_DESIGN.md の哲学（データが主役・Tabular Nums）を遵守。
ライト/ダーク両方のスナップショットテストを必ず作成。
```
