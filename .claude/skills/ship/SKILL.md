# ship

変更をコミットし、PR を作成する。verify を事前に実行して品質を確認する。

## Trigger
- `/ship` でコミット + PR 作成
- `/ship commit` でコミットのみ

## Hooks
- `ship-warn.sh` — verify 未実行時に警告
- `test-reminder.sh` — テスト追加のリマインド

## Input
- コミットメッセージ (省略時は自動生成)

## Output
- git commit
- PR 作成 (GitHub MCP tools 経由)
