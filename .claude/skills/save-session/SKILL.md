# save-session

現在のセッション状態を保存する。作業の中断時に進捗・コンテキストを記録し、再開時に復元できるようにする。

## Trigger
- `/save-session` でセッション保存
- 長時間作業の中断時

## Input
- なし (現在の状態を自動収集)

## Output
- `.claude/sessions/{date}-{summary}.md` — セッションファイル
