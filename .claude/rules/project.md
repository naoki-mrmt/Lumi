# プロジェクト共通ルール

## 言語
- コード・変数名・コミットメッセージ: 英語
- ドキュメント・UI・コメント: 日本語
- 型定義・スキーマ: 英語

## TDD原則 (必須)
すべての実装はテスト駆動で進める。例外なし。

1. **Red**: 失敗するテストを先に書く
2. **Green**: テストを通す最小限の実装
3. **Refactor**: コードを改善 (テストは通ったまま)

### テスト対象
- Domain層テスト（最重要・最多）: XCTest、Protocol準拠テスト
- TCA Feature テスト: TestStore + @Dependency モック
- Persistence テスト: インメモリModelContainer

### テストを書かなくて良いもの
- 純粋なView (SwiftUI Preview で確認)
- 外部ライブラリの薄いラッパー

## ドキュメントファースト
実装前に必ず `/spec` で仕様書を `docs/specs/` に作成する。
仕様書なしの実装開始は禁止。

## コミット規約
Conventional Commits + スコープ:
- `feat(mac):` / `feat(ios):` / `feat(kit):`
- `fix(mac):` / `test(kit):` / `docs:` / `refactor:` / `chore:`

## ブランチ戦略
- `main` — 本番
- `develop` — 開発統合
- `feature/xxx` — 機能開発
- `fix/xxx` — バグ修正

## エラーハンドリング
- Swift Result型 + async/await
- 日本語エラーメッセージ（ユーザー向け）

## セキュリティ
- APIキーはクライアントに露出させない
- シークレットはリポジトリにコミットしない
- パスワードフィールド検出時は音声入力を自動無効化

## ビルド & テスト
```bash
# Primary dev loop (fast)
cd Packages/CalameKit && swift test

# Full project build
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' build

# Full project test
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' test
```
