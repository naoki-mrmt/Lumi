# retro Instructions

## データ収集

### 1. git ログ分析

```bash
# 期間内のコミット
git log --oneline --since="{start-date}" --until="{end-date}"

# ファイル変更統計
git log --stat --since="{start-date}" --until="{end-date}"

# 著者別
git shortlog -sn --since="{start-date}"
```

### 2. エリアバランス分析

変更されたファイルのパスからエリア別の作業量を算出:

| エリア | パス | 変更行数 |
|--------|------|---------|
| CalameKit | `Packages/CalameKit/` | {行数} |
| macOS App | `App/macOS/` | {行数} |
| iOS App | `App/iOS/` | {行数} |
| Keyboard Extension | `App/KeyboardExtension/` | {行数} |
| ドキュメント | `docs/` | {行数} |
| テスト | `*/Tests/` | {行数} |

```bash
# エリア別の変更行数
git log --numstat --since="{start-date}" | awk '{print $3}' | sort | uniq -c | sort -rn
```

### 3. ROADMAP 進捗

`docs/ROADMAP.md` を読み込み:
- 計画タスクの完了率
- 遅延しているタスク
- 前倒しで完了したタスク

### 4. コード品質の傾向

```bash
# テスト数の推移
find Packages/CalameKit/Tests -name "*.swift" | xargs grep -c "func test" | awk -F: '{sum += $2} END {print sum}'

# TODO/FIXME の数
grep -r "TODO\|FIXME" Packages/CalameKit/Sources/ App/ | wc -l
```

## 分析

### Good (うまくいったこと)
- 計画通りに進んだタスク
- 品質の高い実装
- 効果的なパターンの発見

### Problem (課題)
- 遅延したタスク・その原因
- 技術的負債の蓄積
- エリアバランスの偏り

### Try (次のスプリントで試すこと)
- 改善アクション
- 新しいアプローチ
- 優先度の調整

## 出力フォーマット

```markdown
## Retro: {期間}

### サマリー
- コミット数: {N}
- 変更ファイル数: {N}
- 完了タスク: {N}/{total}

### エリアバランス
| エリア | 変更行数 | 割合 |
|--------|---------|------|
| CalameKit | {N} | {%} |
| macOS App | {N} | {%} |
| iOS App | {N} | {%} |
| docs | {N} | {%} |

### ROADMAP 進捗
- Phase {N}: {完了率}%
- 注目タスク: {詳細}

### Good 👍
1. {良かった点}

### Problem ⚠️
1. {課題}

### Try 🔄
1. {次に試すこと}
```
