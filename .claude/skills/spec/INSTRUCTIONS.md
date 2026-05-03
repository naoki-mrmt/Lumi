# spec Instructions

## 事前読み込み

1. 設計ドキュメントを読む:
   - `docs/DESIGN.md` — アーキテクチャ、技術選定
   - `docs/ROADMAP.md` — フェーズ計画
   - 関連する `docs/tasks/phase{N}.md`
2. 既存の仕様書を確認: `docs/specs/` 内の既存仕様
3. テンプレートを読む: `.claude/skills/spec/assets/spec-template.md`
4. 既存コードを確認:
   - `Packages/CalameKit/Sources/Domain/` — 既存プロトコル
   - `Packages/CalameKit/Sources/Features/` — 既存 Feature
   - `Packages/CalameKit/Sources/Persistence/` — 既存モデル

## 仕様書作成フロー

### 1. 要件整理
- ユーザーストーリー / ゴールを明確化
- DESIGN.md との整合性を確認
- 対象プラットフォーム (macOS / iOS / 両方 / KeyboardExtension)

### 2. 設計
- **State**: 画面が持つ状態を定義
- **Action**: ユーザーアクションと内部イベント
- **Effect**: 副作用 (音声認識、DB操作、LLM推論)
- **DependencyKey**: 外部依存の抽象化
- **SwiftData Model**: 永続化が必要なデータ
- **Domain Protocol**: ビジネスロジックの抽象化

### 3. UI 設計
- 画面構成 (Figma / 文字ベース)
- macOS / iOS のプラットフォーム差異
- アクセシビリティ要件

### 4. テスト戦略
- TestStore で検証する主要フロー
- モック化する依存 (WhisperKit, llama.cpp, SwiftData)
- Edge case

## 出力
- テンプレートに基づいて `docs/specs/{feature-name}.md` を生成
- ファイル名はケバブケース

## チェックリスト (完了前)
- [ ] DESIGN.md のアーキテクチャに沿っているか
- [ ] 対象モジュール (Core/Domain/Persistence/Features) が明確か
- [ ] State / Action / Effect が網羅されているか
- [ ] DependencyKey の設計が適切か
- [ ] テスト戦略があるか
- [ ] プラットフォーム差異が考慮されているか
