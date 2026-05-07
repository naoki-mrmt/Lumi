# 仕様書: M2 — 入力UI コア

**Status**: draft
**作成日**: 2026-05-04
**関連**: `docs/03_DOMAIN_MODEL.md`, `docs/04_UI_DESIGN.md`, `docs/tasks/M2_input_core.md`

---

## 1. 目的

試合中の Recorder 入力UIの実装。コートタップ + クイックボタンのハイブリッド、3モード切替、ラリータイムライン、アンドゥ、自/相手切替、Hapticフィードバック。

## 2. スコープ

| 層 | モジュール | 役割 |
|---|---|---|
| Domain | `Models` | Play 構造体・各種 enum を追加。Rally に `plays: [Play]` を追加 |
| Domain | `RallyTimeline` | Rally 内 Play 管理の純粋ロジック |
| Feature | `MatchInputFeature` | 試合中の State + Reducer + View 一式 |
| Core | `DesignSystem` | Evaluation 拡張（色・アイコン・Haptic） |

## 3. データモデル拡張

### 3.1 Play

```swift
public struct Play: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var rallyId: UUID
    public var sequenceInRally: Int
    public var playTeam: Team.ServingSide
    public var playerId: UUID?
    public var opponentJersey: Int?
    public var playType: PlayType
    public var evaluation: Evaluation
    public var serveType: ServeType?
    public var serveAttempt: ServeAttempt?
    public var receptionQuality: ReceptionQuality?
    public var attackCourse: AttackCourse?
    public var serveCourse: Int?            // 1..9
    public var blockCount: Int?             // 1/2/3
    public var errorType: ErrorType?
    public var courtZone: CourtZone?        // ボール着地点 (0..8)
    public var timestamp: Date
    public var videoOffsetSeconds: Double?
    public var isAssist: Bool
}
```

### 3.2 Enum 群

```swift
public enum PlayType: String, Codable, CaseIterable, Sendable {
    case serve, reception, set, attack, block, dig, error
}

public enum Evaluation: String, Codable, CaseIterable, Sendable {
    case excellent  // ◎
    case good       // ○
    case normal     // △
    case error      // ×
}

public enum ServeType: String, Codable, CaseIterable, Sendable {
    case float, jump, jumpFloat
}

public enum ServeAttempt: String, Codable, CaseIterable, Sendable {
    case first, second   // 9人制サーブ2本制
}

public enum ReceptionQuality: String, Codable, CaseIterable, Sendable {
    case aPass, bPass, cPass, dPass
}

public enum AttackCourse: String, Codable, CaseIterable, Sendable {
    case cross, straight, inner, feint, other
}

public enum ErrorType: String, Codable, CaseIterable, Sendable {
    case dribble, overTimes, touchNet, fourHits, footFault, netInServe, other
}

public struct CourtZone: Equatable, Hashable, Codable, Sendable {
    public var row: Int   // 0..2
    public var col: Int   // 0..2
    public var side: Side // own / opponent
    public enum Side: String, Codable, Sendable { case own, opponent }
}
```

### 3.3 Rally 拡張

`Rally` 構造体に `plays: [Play]` フィールドを追加（M1 から後方互換、デフォルト `[]`）。

## 4. RallyTimeline モジュール

```swift
public struct RallyTimeline: Sendable {
    public init()

    /// Play を sequenceInRally の末尾に追加。timestamp と sequence を自動採番
    public func append(_ play: Play, to rally: Rally) -> Rally

    /// Play を id で削除し、後続の sequenceInRally を詰める
    public func remove(playId: UUID, from rally: Rally) -> Rally

    /// 指定 index にプレーを移動（sequenceInRally 再計算）
    public func move(playId: UUID, toIndex: Int, in rally: Rally) -> Rally

    /// ラリー終了処理: winner / endedAt を設定し、アシスト計算を行う
    public func endRally(_ rally: Rally, winner: Team.ServingSide, endedAt: Date) -> Rally

    /// 自軍 attack-excellent の直前にある自軍 set があれば isAssist=true
    public func computeAssists(in rally: Rally) -> Rally
}
```

## 5. MatchInputFeature

### 5.1 State

```swift
@ObservableState
public struct State: Equatable {
    public var match: Match
    public var currentSetId: UUID
    public var currentRallyId: UUID?
    public var inputMode: InputMode = .standard

    // 入力中バッファ
    public var draftSelectedTeam: Team.ServingSide = .own
    public var draftSelectedPlayer: Player?
    public var draftOpponentJersey: Int?
    public var draftPlayType: PlayType?
    public var draftCourtZone: CourtZone?

    // UI状態
    public var presentingTimeoutSheet: Bool = false
    public var presentingSubstitutionSheet: Bool = false
    public var errorMessage: String?

    // アンドゥ履歴 (最大5件)
    fileprivate var stateHistory: [Snapshot] = []
}

public enum InputMode: String, Codable, CaseIterable, Sendable {
    case quick, standard, detailed
}
```

### 5.2 主要 Action

```swift
case onAppear
case modeChanged(InputMode)
case teamSwitched(Team.ServingSide)
case playerSelected(Player)
case opponentJerseyChanged(Int?)
case playTypeSelected(PlayType)
case courtZoneTapped(CourtZone)
case evaluationSelected(Evaluation)            // ← Play 確定 + アンドゥスナップ
case rallyEndTapped(winner: Team.ServingSide)
case undoTapped
case timeoutRequested(Team.ServingSide)
case substitutionRequested([(playerOut: UUID, playerIn: UUID)])
case errorDismissed
```

### 5.3 アンドゥ実装

State 変更を引き起こす Action（特に `evaluationSelected`, `rallyEndTapped`, `timeoutRequested`, `substitutionRequested`）の実行直前に Snapshot を `stateHistory` に push（最大5件、超えたら FIFO で先頭を破棄）。

`undoTapped` で末尾を pop し、State を復元する。

```swift
fileprivate struct Snapshot: Equatable, Sendable {
    let match: Match
    let currentRallyId: UUID?
}
```

### 5.4 評価 → Haptic マッピング (DesignSystem)

```swift
public extension Evaluation {
    var color: Color { /* Lumi.excellent / good / average / poor */ }
    var icon: String  // SF Symbols
    var hapticFeedback: SensoryFeedback // success / impact(.light) / selection / warning
    var symbol: String   // ◎ / ○ / △ / ×
}
```

### 5.5 バリデーション

- 評価 selected したが PlayType / Player(自軍時) / OpponentJersey(相手時) が未選択 → `errorMessage` セット
- TimeoutRequested:
  - 自軍 TO 既に2回 → `errorMessage`
  - 相手 TO 既に2回 → 同上
- Substitution:
  - 1セット 5回目 → reject
  - 1回 4人以上 → reject
  - 同 ServiceOrderEntry の交代3回目 → reject
  - すべて ServiceOrderEngine の error 経由

### 5.6 Rally 生成

- `currentRallyId == nil` の状態で最初の Play を確定したら、新しい Rally を生成。
- `rallyEndTapped` で Rally に winner/endedAt をセットし、closing。次の Play 入力時にまた新しい Rally を作る。

## 6. View

### 6.1 レイアウト (iPad 横)

```
┌────────────────────────────────────────┐
│ Set1 自12-10 相手 [TO] [交代] [モード] │
├────────────────────────────────────────┤
│ 左: スタメン9人 + 自/相手切替           │
│ 右: コート(自陣9マス + 相手陣9マス)      │
├────────────────────────────────────────┤
│ プレー種別ボタン (7) / 評価ボタン (4) │
│ ラリータイムライン                      │
│ [アンドゥ] [編集] [ラリー終了]          │
└────────────────────────────────────────┘
```

### 6.2 入力モード差分

| モード | 必須項目 | 任意項目 |
|--------|----------|----------|
| quick  | playType + evaluation + (player or jersey) | - |
| standard | + 適用時 ServeType / ReceptionQuality | - |
| detailed | + AttackCourse / ServeCourse / CourtZone | - |

`Play` 確定時、入力モードに応じて optional フィールドを必須/任意で扱う。

## 7. テスト戦略

### 7.1 ModelsTests
- Play / 各 enum の Codable round-trip
- Rally の plays フィールド追加後も後方互換

### 7.2 RallyTimelineTests
- append: sequence 採番が単調増加
- remove: 後続 sequence が詰められる
- move: 任意 index 移動
- endRally: winner と endedAt 設定
- computeAssists:
  - 自軍 attack-excellent 直前の自軍 set が isAssist=true
  - 相手プレーの後ろに自軍 attack の場合 isAssist=false
  - 連続 attack の場合は最後の attack のみアシスト判定対象

### 7.3 MatchInputFeatureTests (TestStore)
- mode 切替で state.inputMode 変化
- teamSwitched で draftSelectedTeam 変化
- playerSelected → playTypeSelected → evaluationSelected: rally に Play 追加
- undo: 直前の Play 追加を取り消し
- 5回 undo 後、6回目は no-op
- timeoutRequested(.own) を3回呼ぶと3回目はエラー

## 8. 完了判定

- [ ] Models 拡張 (Play 追加 / Rally.plays)
- [ ] RallyTimeline 全メソッドのテスト緑
- [ ] MatchInputFeature TestStore テスト緑
- [ ] iPad シミュレータでビルド成功・基本入力フローが動作
- [ ] Hapticフィードバックが各評価で発火 (動作確認は手動)

## 9. 段取り

1. Models: Play / 各 enum / Rally.plays 追加 (Codable round-trip テスト)
2. RallyTimeline 純粋関数 + テスト (アシスト計算が肝)
3. MatchInputFeature Reducer 骨格 + アンドゥ + 主要 Action テスト
4. View: コート / プレーボタン / 評価ボタン / タイムライン / TO / 交代 / モード切替
5. AppFeature から起動できるよう連結

## 10. 未決事項

- M2 段階では「相手アタックコース」「相手選手番号別の集計」は最小限 (M3 のKPIで活かす)
- 直前ラリー全体編集 (T13) は最初は「未確定の現在ラリーの編集」のみサポート。完了済みラリーの編集はバッファダイアログで実現
