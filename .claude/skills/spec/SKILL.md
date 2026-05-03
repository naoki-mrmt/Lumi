# spec

機能仕様書を作成する。実装前に設計を固め、レビュー可能な仕様書を生成する。

## Trigger
- `/spec <機能名>` または仕様書作成の依頼
- 新機能の設計フェーズ

## Input
- 機能名・概要
- 関連する DESIGN.md / ROADMAP.md のセクション

## Output
- `docs/specs/{feature-name}.md` — 仕様書
- State / Action / Effect の設計
- DependencyKey の設計
- SwiftData モデル設計 (必要な場合)
