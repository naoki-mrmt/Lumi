# M1: チーム・試合・サービス順

## 目的

ドメインの心臓部である「9人制のサービス順管理」と、その前提となるチーム・選手・試合のデータモデル・基本UIを実装する。9人制ルールに完全準拠したロジックを純粋関数として作り上げる。

## 完了条件（DoD）

- [ ] Team / Player / Match / Set / MatchMember のデータモデルが Models モジュールに定義済み
- [ ] SwiftData での永続化が動作（CRUD可能）
- [ ] ServiceOrderEngine が9人制ルールに完全準拠（テスト全緑）
  - [ ] 連続得点時に同一サーバーが続く
  - [ ] セット間引き継ぎが正しい（前セット最終サーバーの次）
  - [ ] 選手交代時にサービス順を引き継ぐ
  - [ ] 再交代制限（同セット1回のみ）が機能
- [ ] チームマスタ画面で選手15人まで登録可能
- [ ] 試合作成画面で完全なセットアップが可能（試合タイプ・会場含む）
- [ ] 「前回スタメンコピー」機能が動作
- [ ] ServiceOrderEngineTests がカバレッジ95%以上

## 関連ドキュメント

- `docs/03_DOMAIN_MODEL.md` — データモデル定義・9人制ルール詳細・サービス順ルール
- `docs/02_FEATURE_SPEC.md` — F-1.0.1, F-1.0.2, F-1.0.3
- `docs/04_UI_DESIGN.md` — 6.1 試合作成画面のワイヤー
- `docs/08_NON_FUNCTIONAL.md` — テスト戦略（ServiceOrderEngineは95%）

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M1-T1 | Team/Player モデル定義 | SwiftData @Model + Equatable・Codable準拠 |
| M1-T2 | Match/Set/MatchMember モデル定義 | 同上、リレーションシップ含む |
| M1-T3 | ServiceOrderEngine ロジック実装 | 純粋関数、Models のみに依存 |
| M1-T4 | 選手交代時の順番引継ぎロジック | 1回最大3人、4回/セット制限を含む |
| M1-T5 | 再交代制限ロジック | 同セット1回のみ・先発↔交代の往復可 |
| M1-T6 | セット間引き継ぎロジック | 前セット最終サーバーの「次」が初手 |
| M1-T7 | TeamManagementFeature（選手15人マスタ） | TCA Feature として動作、選手追加・編集・削除 |
| M1-T8 | MatchSetupFeature（試合作成） | スタメン9人選択・サービス順並び替え・フォーメーション選択 |
| M1-T9 | 前回スタメンコピー機能 | 直近試合のスタメンとサービス順を1タップ流用 |
| M1-T10 | ServiceOrderEngineTests（厚く） | 境界値・バグりやすいケース網羅、95%以上カバレッジ |

## 実装メモ

### ServiceOrderEngine のインターフェース案

```swift
public struct ServiceOrderEngine {
  /// 現在のサーバーを返す
  public func currentServer(in match: Match) -> Player?
  
  /// 得点後のサービス順更新（サイドアウトなら相手側に切替、継続なら同一）
  public func advance(after rally: Rally, in match: Match) -> Match
  
  /// 選手交代を反映
  public func substitute(
    in match: Match,
    setId: UUID,
    playerOut: Player,
    playerIn: Player
  ) throws -> Match
  
  /// 新セット開始時のサービス順初期化
  public func initializeForNewSet(
    in match: Match,
    setNumber: Int
  ) -> Match
  
  /// 同セット内の再交代が可能か判定
  public func canSubstituteAgain(
    in match: Match,
    setId: UUID,
    player: Player
  ) -> Bool
}
```

### テストすべきケース（M1-T10）

```
- セット1開始：1番目の選手がサーバー
- 自軍得点継続：同じ選手がサーブ続行
- サイドアウト：相手にサーブ権、自軍は次のサーブ順を準備
- 自軍に再びサーブ権：「次の選手」が打つ（前回最終サーバーの次）
- セット2開始：前セット最終サーバーの次が初手
- 選手交代：入った選手が出た選手のサービス順を引き継ぐ
- 同セット内で先発選手 → 交代選手 → 先発選手の再交代：OK
- 同セット内でさらに2回目の再交代：NG（エラー）
- 1回の選手交代で4人同時交代：NG（最大3人）
- 1セット5回目の選手交代：NG（最大4回）
```

### Match モデルの試合タイプ

```swift
public enum MatchType: String, Codable, CaseIterable {
  case official      // 公式戦
  case practice      // 練習試合
  case trainingCamp  // 合宿
}
```

### 前回スタメンコピー機能

直近試合のスタメンとサービス順を「ボタン1タップで」コピー。微調整は通常のUI上で行う。

### TeamManagementFeatureの構造

```swift
@Reducer
public struct TeamManagementFeature {
  @ObservableState
  public struct State: Equatable {
    var team: Team?
    var players: [Player] = []
    @Presents var editingPlayer: PlayerEditFeature.State?
  }
  
  public enum Action {
    case onAppear
    case playersLoaded([Player])
    case addPlayerTapped
    case playerSelected(Player)
    case editingPlayer(PresentationAction<PlayerEditFeature.Action>)
    // ...
  }
  
  @Dependency(\.localStore) var localStore
  
  // ...
}
```

## CC に渡すプロンプト雛形

```
M1 を進めてほしい。
docs/progress.json で M0 が completed であることを確認、
docs/03_DOMAIN_MODEL.md の9人制ルールとデータモデル仕様を熟読してから、
docs/tasks/M1_team_match_setup.md の M1-T1 から順に着手。

特に M1-T3 〜 M1-T6 のサービス順ロジックは、
docs/03_DOMAIN_MODEL.md の 1.4 サービス順ルール の各条文を
明確にカバーする実装にし、M1-T10 でテストを95%以上書き切ること。

各タスク完了ごとに progress.json を更新。
```
