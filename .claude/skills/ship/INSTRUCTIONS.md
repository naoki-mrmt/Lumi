# ship Instructions

## 事前チェック

### 1. verify 実行確認
- `/verify` が直近で実行されているか確認
- 未実行の場合は `/verify` を先に実行

### 2. 変更内容の確認
```bash
git status
git diff --cached
git diff
```

## コミットフロー

### 1. スコープ判定

変更ファイルのパスからスコープを自動判定:

| パス | スコープ |
|------|---------|
| `Packages/CalameKit/Sources/Core/` | kit(core) |
| `Packages/CalameKit/Sources/Domain/` | kit(domain) |
| `Packages/CalameKit/Sources/Persistence/` | kit(persistence) |
| `Packages/CalameKit/Sources/Features/` | kit(feature) |
| `Packages/CalameKit/Sources/SharedUI/` | kit(ui) |
| `Packages/CalameKit/Tests/` | kit(test) |
| `App/macOS/` | mac |
| `App/iOS/` | ios |
| `App/KeyboardExtension/` | ios(keyboard) |
| `docs/` | docs |
| `.claude/` | chore |

複数スコープにまたがる場合は主要な変更のスコープを使用。

### 2. コミットメッセージ

フォーマット:
```
{type}({scope}): {summary}

{body - optional}
```

Type: feat / fix / refactor / test / docs / chore
Scope: mac / ios / kit / docs

例:
```
feat(kit): WhisperKit音声認識クライアントを追加

- WhisperKitClient DependencyKey を定義
- 録音開始/停止/結果取得のインターフェース
- TestStore 用の testValue を実装
```

### 3. ステージングとコミット
```bash
# 変更をステージング (ファイルを明示的に指定)
git add <files>

# コミット
git commit -m "{message}"
```

## PR 作成フロー

### 1. ブランチ確認
```bash
git branch --show-current
git log --oneline main..HEAD
```

### 2. PR 作成

GitHub MCP tools を使用して PR を作成する。
MCP tools が利用できない場合は、PR の内容を出力してユーザーに手動作成を案内する。

### PR テンプレート

```markdown
## Summary
{変更の概要 - 1〜3行}

## Changes
- {変更点1}
- {変更点2}

## Related
- Phase: docs/tasks/phase{N}.md
- Spec: docs/specs/{feature}.md (あれば)

## Test
- [ ] `cd Packages/CalameKit && swift test` pass
- [ ] ビルド確認 (macOS / iOS)
```

## 注意事項
- `main` ブランチに直接コミットしない
- 大きな変更は複数コミットに分割
- WIP コミットは squash 前提で OK
- `.env`, 秘密鍵などの機密ファイルをコミットしない
