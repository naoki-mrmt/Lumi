# verify

ビルドとテストを実行し、変更が正しく動作することを確認する。

## Trigger
- `/verify` で手動実行
- ship スキルから自動呼び出し
- コミット前の確認

## Hooks
- `pre-push-warn.sh` — push 前に verify 未実行を警告

## Input
- なし (変更されたファイルから自動判定)

## Output
- ビルド結果 (成功/失敗)
- テスト結果 (成功/失敗/スキップ)
- ログファイル: `.claude/skills/verify/logs/`
