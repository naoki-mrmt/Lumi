# plan Instructions

## 事前読み込み

1. 設計ドキュメントを読む:
   - `docs/DESIGN.md` — アーキテクチャ、技術選定、設計思想
   - `docs/ROADMAP.md` — フェーズ計画、マイルストーン
   - `docs/tasks/phase{0-3}.md` — 各フェーズの詳細タスク

2. 現在のコード構造を確認:
   - `Packages/CalameKit/Sources/` のモジュール構成
   - `App/macOS/`, `App/iOS/`, `App/KeyboardExtension/` のターゲット構成

## 計画策定フロー

### 1. 現状把握
- ROADMAP.md の現在フェーズを確認
- 完了済みタスクと未着手タスクを整理
- 既存コードの実装状況を確認

### 2. 設計整合性チェック
- DESIGN.md のアーキテクチャ方針との整合性
- SPM モジュール依存関係の妥当性:
  - `Core` ← `Domain` ← `Persistence` ← `Features` ← App targets
  - 逆方向の依存がないか
- TCA の設計パターンとの整合性:
  - Feature 間の結合度
  - DependencyKey の設計
  - Navigation 設計
- Domain プロトコル設計の妥当性:
  - Protocol → Implementation の分離
  - テスタビリティ

### 3. タスク分割
- 1タスク = 1 Reducer + View、または 1 Domain プロトコル + 実装
- 依存関係を明確化 (Domain → Features → App の順)
- 各タスクの見積もりと優先順位

### 4. リスク評価
- WhisperKit / llama.cpp 統合のリスク
- macOS / iOS のプラットフォーム差異
- Keyboard Extension の制約 (メモリ、ネットワーク制限)
- SwiftData のパフォーマンス (大量の入力ログ)

## 出力フォーマット

```markdown
## 計画: {機能名}

### 背景
- なぜこの機能が必要か
- ROADMAP.md のどのフェーズに該当するか

### 設計方針
- アーキテクチャ上の位置づけ
- モジュール依存関係

### タスク分割
1. [ ] タスク1 — 概要 (見積: S/M/L)
2. [ ] タスク2 — 概要 (見積: S/M/L)
   - 依存: タスク1

### リスク・懸念事項
- リスク1: 内容 → 対策
```

## 注意事項
- DESIGN.md の設計思想を変更する提案をする場合、根拠を明確にする
- プラットフォーム固有の機能は App/ 層に、共通ロジックは CalameKit に
- Keyboard Extension は App Extension の制約を常に考慮
