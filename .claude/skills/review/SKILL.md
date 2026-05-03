# review

コードレビューを実施する。TCA + SwiftUI + SwiftData のベストプラクティスに基づいてフィードバックする。

## Trigger
- `/review` または `/review <path>` でレビュー依頼されたとき
- PR レビューの依頼

## Input
- レビュー対象のファイルパス、または git diff

## Output
- レビューコメント (問題点、改善提案)
- 重要度: 🔴 must-fix / 🟡 should-fix / 🟢 nit
