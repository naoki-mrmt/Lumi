# verify Instructions

## スコープ判定

変更されたファイルからビルド・テストのスコープを自動判定する。

```bash
# 変更ファイルの取得
git diff --name-only HEAD
git diff --name-only --cached
```

### スコープルール
| 変更パス | スコープ | ビルド・テスト |
|---------|---------|-------------|
| `Packages/CalameKit/` | kit | SPM test |
| `App/macOS/` | mac | xcodebuild macOS |
| `App/iOS/` | ios | xcodebuild iOS |
| `App/KeyboardExtension/` | ios | xcodebuild iOS |
| `docs/` | docs | なし (スキップ) |
| `.claude/` | config | なし (スキップ) |

## 実行フロー

### 1. kit スコープ (CalameKit パッケージ)

```bash
# ビルド
cd Packages/CalameKit && swift build 2>&1 | tee /tmp/calame-verify-build.log

# テスト
cd Packages/CalameKit && swift test 2>&1 | tee /tmp/calame-verify-test.log
```

**失敗時の対応:**
- コンパイルエラー: エラーメッセージを確認し、該当ファイルを修正
- テスト失敗: 失敗したテストの詳細を確認

### 2. mac スコープ (macOS アプリ)

```bash
# ビルド
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' build 2>&1 | tee /tmp/calame-verify-mac-build.log

# テスト
xcodebuild -project Calame.xcodeproj -scheme Calame-macOS -destination 'platform=macOS' test 2>&1 | tee /tmp/calame-verify-mac-test.log
```

### 3. ios スコープ (iOS アプリ + Keyboard Extension)

```bash
# ビルド
xcodebuild -project Calame.xcodeproj -scheme Calame-iOS -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tee /tmp/calame-verify-ios-build.log

# テスト
xcodebuild -project Calame.xcodeproj -scheme Calame-iOS -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tee /tmp/calame-verify-ios-test.log
```

### 4. 全スコープ (複数スコープにまたがる変更)

kit → mac → ios の順で実行。kit が失敗したら後続はスキップ。

## 結果判定

### 成功条件
- ビルドが 0 エラーで完了
- 全テストが pass (warning は許容)

### 失敗時
1. エラーメッセージを抽出
2. 該当ファイルと行番号を特定
3. 修正を提案 (自動修正はしない)

## ログ保存

```bash
# ログをスキルディレクトリに保存
cp /tmp/calame-verify-*.log .claude/skills/verify/logs/
```

## 出力フォーマット

```markdown
## Verify 結果

### スコープ: {kit / mac / ios}

| ステップ | 結果 | 詳細 |
|---------|------|------|
| ビルド | ✅ / ❌ | {エラー数 / 警告数} |
| テスト | ✅ / ❌ | {pass数 / fail数 / skip数} |

### エラー詳細 (失敗時)
{エラーメッセージ}
```
