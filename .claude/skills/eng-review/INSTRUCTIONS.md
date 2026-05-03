# eng-review Instructions

## スキャン対象

```
Packages/CalameKit/Sources/
Packages/CalameKit/Tests/
App/macOS/
App/iOS/
App/KeyboardExtension/
```

## 評価軸

### 1. SPM モジュール設計 (重要度: 高)

**チェック項目:**
- モジュール間の依存方向が正しいか:
  - `Core` ← `Domain` ← `Persistence` ← `Features` ← App targets
  - 逆方向の依存がないか
- 各モジュールの責務が明確か
- モジュール間のインターフェースが Protocol で抽象化されているか
- 循環依存がないか

**確認方法:**
```bash
# Package.swift の依存関係を確認
cat Packages/CalameKit/Package.swift

# import 文の確認
grep -r "^import " Packages/CalameKit/Sources/ | sort
```

### 2. Domain / Features 分離 (重要度: 高)

**チェック項目:**
- Domain 層にUIの依存がないか (SwiftUI, TCA の import がないか)
- Features 層が Domain Protocol に依存しているか (具体実装に依存していないか)
- ビジネスロジックが Feature (Reducer) に漏れていないか

### 3. TCA 依存設計 (重要度: 高)

**チェック項目:**
- すべての外部依存が DependencyKey で抽象化されているか
- testValue が定義されているか
- live/test/preview の3値が揃っているか (preview は任意)
- Effect 内での副作用が適切に管理されているか

### 4. SwiftData モデル設計 (重要度: 中)

**チェック項目:**
- `@Model` クラスの設計が適切か
- Relationship の設定 (cascade, inverse)
- マイグレーション戦略
- ModelContainer の初期化が1回のみか
- Background context の使い方

### 5. WhisperKit / llama.cpp 統合 (重要度: 中)

**チェック項目:**
- C/Swift ブリッジの安全性
- メモリ管理 (特にモデルのロード/アンロード)
- エラーハンドリング
- Keyboard Extension のメモリ制限内か
- DependencyKey で抽象化されているか

### 6. macOS / iOS デュアルプラットフォーム (重要度: 中)

**チェック項目:**
- プラットフォーム固有コードが App/ 層に分離されているか
- CalameKit がプラットフォーム非依存か
- `#if os(macOS)` / `#if os(iOS)` の使い方が適切か
- メニューバーアプリ (macOS) と通常アプリ (iOS) の UX 差異

### 7. テスト品質 (重要度: 中)

**チェック項目:**
- テストカバレッジ (Feature ごとに TestStore テストがあるか)
- テストの独立性 (依存がモック化されているか)
- Edge case のカバー
- テスト命名の一貫性

## 出力フォーマット

```markdown
## Engineering Review

### スコアサマリー
| 評価軸 | スコア | 状態 |
|--------|-------|------|
| SPM モジュール設計 | {A-F} | {概要} |
| Domain/Features 分離 | {A-F} | {概要} |
| TCA 依存設計 | {A-F} | {概要} |
| SwiftData モデル | {A-F} | {概要} |
| WhisperKit/llama.cpp | {A-F} | {概要} |
| デュアルプラットフォーム | {A-F} | {概要} |
| テスト品質 | {A-F} | {概要} |

### 詳細フィードバック

#### {評価軸}
**スコア: {A-F}**
- 👍 {良い点}
- ⚠️ {改善点}
- 修正提案: {具体的な修正方法}

### 改善プライオリティ
1. 🔴 {最優先の改善点}
2. 🟡 {次に改善すべき点}
3. 🟢 {余裕があれば改善}
```
