# M2: 入力UI コア

## 目的

試合中の入力UIを完成させる。3モード（クイック/スタンダード/詳細）切替、コートタップ + クイックボタンのハイブリッド、ラリータイムライン、アンドゥ、自/相手切替、Hapticフィードバックなど、Recorderの最重要機能群。

## 完了条件（DoD）

- [ ] Rally / Play モデル定義済み・SwiftData永続化動作
- [ ] RallyTimelineモジュールがラリーの時系列管理を担う
- [ ] MatchInputFeature が試合中の状態管理として動作
- [ ] コートタップUIで自陣9マス・相手陣9マスをタップで選択可能
- [ ] 選手選択UIで自チーム選手・相手背番号を切替えて選択可能
- [ ] プレー種別ボタン群（サーブ/レセプ/アタック/ブロック/ディグ/セット/ミス）
- [ ] 評価4段階ボタン（信号機メタファー）が動作
- [ ] ラリータイムラインがプレー追加に応じてリアルタイム更新
- [ ] 3モード（クイック/スタンダード/詳細）が切替可能
- [ ] アンドゥが最大5ステップまで動作
- [ ] 直前ラリー全体の編集モードが動作
- [ ] 自/相手切替が1タップで動作
- [ ] タイムアウト入力（自/相手・1セット2回上限のUI制限）
- [ ] 選手交代入力（4回/セット・3人/回・再交代制限のUI制限）
- [ ] 評価ごとに違うHapticフィードバック

## 関連ドキュメント

- `docs/02_FEATURE_SPEC.md` — F-1.0.4 〜 F-1.0.7
- `docs/04_UI_DESIGN.md` — 6.2 入力画面ワイヤー、7.1 Hapticフィードバック仕様
- `docs/03_DOMAIN_MODEL.md` — Rally / Play エンティティ
- `docs/05_TECH_ARCHITECTURE.md` — TCA Reducer設計

## タスク一覧

| ID | タスク | 完了条件 |
|---|---|---|
| M2-T1 | Rally/Play モデル定義 | SwiftData @Model、評価Enum、サーブ種別・レセプション品質等のEnum |
| M2-T2 | RallyTimelineモジュール | プレー追加・並び替え・終了判定の純粋ロジック |
| M2-T3 | MatchInputFeature 骨格 | 試合中State・主要Action・Reducer骨格 |
| M2-T4 | コートタップUI | 自陣・相手陣9マス、タップ位置をState反映、ピンチでズーム |
| M2-T5 | 選手選択UI | 自チーム選手リスト・相手背番号入力フィールド・切替 |
| M2-T6 | プレー種別ボタン群 | 7種ボタンが選択時にハイライト |
| M2-T7 | 評価4段階ボタン（信号機メタファー） | ◎○△× の4色・アイコン・タップで評価セット |
| M2-T8 | ラリータイムライン表示 | プレーカードを縦に並べる、サブテキストで詳細 |
| M2-T9 | クイックモード | 「誰がサーブ・誰が決め・誰がミス」の最低限のみ |
| M2-T10 | スタンダードモード（デフォルト） | サーブ種別・レセプション品質・評価まで |
| M2-T11 | 詳細モード | アタックコース・サーブコース等を追加 |
| M2-T12 | アンドゥロジック（5ステップ） | プレー単位で取り消し、State履歴を5件保持 |
| M2-T13 | 直前ラリー編集UI | 1ラリー分のプレーを編集・順番変更・削除 |
| M2-T14 | 自/相手切替 | 1タップ切替、相手プレー時は背番号入力モードへ |
| M2-T15 | タイムアウト入力 | 1タップ・スコア自動取得・1セット2回上限制限 |
| M2-T16 | 選手交代入力 | 入る選手・出る選手選択、4回/セット・3人/回制限・再交代制限 |
| M2-T17 | Hapticフィードバック | 評価別の SensoryFeedback 実装 |

## 実装メモ

### 評価4段階のEnum

```swift
public enum Evaluation: String, Codable, CaseIterable {
  case excellent  // ◎ 決定・好プレー
  case good       // ○ 及第点
  case normal     // △ 継続中
  case error      // × 失点
  
  var color: Color { /* DesignSystem経由 */ }
  var icon: String { /* SF Symbols */ }
  var hapticFeedback: SensoryFeedback { /* iOS 26 API */ }
}
```

### 入力モード切替

```swift
public enum InputMode: String, Codable, CaseIterable {
  case quick     // 最低限（得点経緯のみ）
  case standard  // 標準（デフォルト）
  case detailed  // 詳細（コース等）
}
```

### コートタップ座標系

- 自陣9マス・相手陣9マスを 0-8 のインデックスで表現
- タップ位置を `(row: 0..2, col: 0..2)` で取得
- フリーポジション前提なので、選手を「マスに固定」しない（マスは「ボール着地点」）

### ラリータイムライン構造

```
┌──────────────────────────────┐
│ Rally #12 (自10 - 9 相手)    │
├──────────────────────────────┤
│ 1. 自#7 サーブ ジャンプ ◎     │  ← 自軍プレー
│ 2. 相手 #11 アタック ストレート ×│  ← 相手プレー
│ 3. 自#3 ディグ ○             │
│ 4. 自#4 セット ◎             │
│ 5. 自#7 アタック クロス ◎     │ ← 自軍決定
│ ─                            │
│ → 自軍得点（ラリー終了）       │
└──────────────────────────────┘
```

### アンドゥ実装方針

TCA の State スナップショット履歴を5件保持。`undo` Action で1つ戻す。

```swift
@ObservableState
public struct State: Equatable {
  var match: Match
  var currentRally: Rally?
  var inputMode: InputMode = .standard
  var stateHistory: [StateSnapshot] = []  // 最大5件、FIFO
  // ...
}
```

### Hapticフィードバック (iOS 26)

```swift
import SwiftUI

struct EvaluationButton: View {
  let evaluation: Evaluation
  @State private var trigger: Bool = false
  
  var body: some View {
    Button { trigger.toggle() } label: { /* ... */ }
      .sensoryFeedback(evaluation.hapticFeedback, trigger: trigger)
  }
}

extension Evaluation {
  var hapticFeedback: SensoryFeedback {
    switch self {
    case .excellent: return .success
    case .good:      return .impact(weight: .light)
    case .normal:    return .selection
    case .error:     return .warning
    }
  }
}
```

### 選手交代UIのバリデーション

- セット内交代回数が4を超える → 「上限に達しました」アラート
- 1回の交代で同時に4人以上 → 「最大3人まで」アラート
- 同セット内で再交代を2回目しようとした → 「再交代は1回のみ」アラート

### タイムアウトUIのバリデーション

- 自軍TOが既に2回 → ボタン無効化
- 相手TOが既に2回 → 相手TOボタンも無効化（相手が誤要求しないよう）

## CC に渡すプロンプト雛形

```
M2 を進めてほしい。
docs/progress.json で M1 が completed であることを確認。
docs/04_UI_DESIGN.md の入力画面ワイヤー（6.2）、
docs/03_DOMAIN_MODEL.md の Rally/Play エンティティ仕様を確認の上、
docs/tasks/M2_input_core.md の M2-T1 から順に進めてほしい。

特に：
- M2-T7（評価ボタン）は信号機メタファー（◎緑/○水色/△黄/×赤）を厳守
- M2-T17（Haptic）は iOS 26 の SensoryFeedback API を使用
- M2-T12（アンドゥ）は最大5ステップを正確に守る
- 各モード切替時のUI差分は明確に（クイックは2-3タップ、詳細は10タップ程度）

各タスク完了ごとに progress.json 更新。
M2 全体は2-3週かかる想定なので、タスクごとに細かく報告してほしい。
```
