# investigate Instructions

## 調査フロー

### 1. 問題の整理
- 症状を明確化
- 再現条件を特定 (macOS / iOS / KeyboardExtension)
- 期待される動作と実際の動作の差

### 2. 情報収集

#### コード調査
```bash
# 関連ファイルの検索
grep -r "keyword" Packages/CalameKit/Sources/
grep -r "keyword" App/

# git blame で変更履歴
git blame <file>
git log --oneline --follow <file>

# 最近の変更
git log --oneline -20
git diff HEAD~5
```

#### ビルドエラーの場合
```bash
# SPM ビルド
cd Packages/CalameKit && swift build 2>&1

# Xcode ビルド
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' build 2>&1

# テスト
cd Packages/CalameKit && swift test 2>&1
```

#### ランタイムエラーの場合
- クラッシュログの確認
- Console.app のログ確認手順を案内
- Xcode Instruments の使用を提案

### 3. 原因分析

#### よくある原因カテゴリ
- **TCA**: Effect の未処理、State の不整合、Navigation state のミスマッチ
- **SwiftUI**: View のライフサイクル問題、@State の初期化タイミング
- **SwiftData**: ModelContext のスレッド違反、マイグレーション失敗
- **Concurrency**: Actor isolation 違反、データ競合、デッドロック
- **WhisperKit**: モデルロード失敗、音声入力権限、メモリ不足
- **llama.cpp**: モデルファイル不正、推論エラー、メモリ制限
- **KeyboardExtension**: メモリ制限 (60MB)、ネットワーク制限、権限不足

### 4. 影響範囲の特定
- 問題のあるコードを参照している箇所を検索
- 関連する Feature / Domain を特定
- プラットフォーム固有か共通かを判断

### 5. 修正方針の提案
- 最小限の修正案
- 根本解決案 (リファクタリングが必要な場合)
- テストの追加方針

## 出力フォーマット

```markdown
## 調査結果: {問題の概要}

### 症状
{問題の説明}

### 原因
{特定した原因}

### 根拠
- {ファイル}:{行} — {問題のあるコード}
- {関連する設定・状態}

### 影響範囲
- {影響を受ける Feature / 画面}

### 修正方針
1. {修正案1} — {メリット/デメリット}
2. {修正案2} — {メリット/デメリット}

### 推奨
{推奨する修正案とその理由}
```

## デバッグツール

### Swift / Xcode
- `po` (LLDB) — オブジェクトの出力
- `swift test --filter` — 特定テストの実行
- Xcode Memory Graph — メモリリーク調査
- Instruments — パフォーマンスプロファイリング

### TCA 固有
- `._printChanges()` — Reducer の state 変化をログ出力
- `withDependencies` — テストでの依存注入
- `TestStore.exhaustivity = .off` — 部分的テスト

### SwiftData
- `-com.apple.CoreData.SQLDebug 1` — SQL ログ出力
- `modelContext.undoManager` — 操作の追跡
