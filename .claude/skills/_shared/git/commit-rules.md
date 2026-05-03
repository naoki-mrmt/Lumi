# コミットメッセージ規約

## フォーマット

Conventional Commits に従う。

```
<type>(<scope>): <description>
```

## type 一覧

| type | 用途 |
|---|---|
| `feat` | 新機能追加 |
| `fix` | バグ修正 |
| `test` | テストの追加・修正 |
| `docs` | ドキュメントの追加・修正 |
| `refactor` | リファクタリング（機能変更なし） |
| `chore` | ビルド・設定・依存関係等 |

## scope 一覧

| scope | 対象 |
|---|---|
| `mac` | macOS アプリ (App/macOS/) |
| `ios` | iOS アプリ (App/iOS/, App/KeyboardExtension/) |
| `kit` | CalameKit パッケージ (Packages/CalameKit/) |

scope は省略可能（プロジェクト横断の変更等）。

## 例

```
feat(kit): add WhisperService protocol and WhisperKit implementation
feat(kit): implement LLM refinement pipeline
feat(mac): add menubar popover with recording controls
fix(kit): resolve audio session interruption crash
test(kit): add TextProcessor filler removal tests
feat(ios): implement keyboard extension basic UI
docs: add phase 0 completion notes
chore: configure GitHub Actions CI
refactor(kit): extract audio engine to separate module
```

## ルール

- description は英語で書く
- 先頭小文字、末尾にピリオドをつけない
- 命令形で書く（add, fix, update, remove, refactor）
- 1コミット1責務
