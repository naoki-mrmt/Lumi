# save-session Instructions

## 収集する情報

### 1. 現在の状態
```bash
# ブランチ・コミット
git branch --show-current
git log --oneline -5

# 変更状況
git status
git diff --stat
```

### 2. 作業コンテキスト
- 何をしていたか (実装中の機能、調査中のバグ等)
- 次にやるべきこと
- ブロッカー・未解決の問題

### 3. 関連ファイル
- 編集中のファイル一覧
- 参照していた仕様書・ドキュメント

### 4. ROADMAP の進捗
- `docs/ROADMAP.md` の現在位置
- 完了したタスク
- 進行中のタスク

## セッションファイルの保存

### ファイル名
```
.claude/sessions/{YYYY-MM-DD}-{summary-in-kebab-case}.md
```

### テンプレート

```markdown
# Session: {summary}
Date: {YYYY-MM-DD}
Branch: {branch-name}

## 作業内容
{何をしていたかの概要}

## 完了したこと
- {完了タスク1}
- {完了タスク2}

## 進行中
- {進行中タスク} — {状態・残作業}

## 次にやること
1. {次のタスク1}
2. {次のタスク2}

## ブロッカー・メモ
- {未解決の問題やメモ}

## 関連ファイル
- {ファイルパス1} — {説明}
- {ファイルパス2} — {説明}

## git 状態
```
{git status の出力}
```
```

## 注意事項
- セッションファイルは `.claude/sessions/` に保存
- ディレクトリがなければ作成
- 機密情報 (API キー等) を含めない
