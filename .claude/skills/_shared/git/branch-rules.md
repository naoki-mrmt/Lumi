# ブランチ命名規約

## フォーマット

```
<type>/<feature-name>
```

## type 一覧

| type | 用途 |
|---|---|
| `feature` | 機能開発 |
| `fix` | バグ修正 |
| `refactor` | リファクタリング |
| `chore` | 設定・依存関係等 |

## 例

```
feature/project-setup
feature/whisperkit-integration
feature/menubar-ui
fix/audio-engine-crash
refactor/tca-dependencies
chore/ci-setup
```

## ルール

- 英語小文字 + ハイフン区切り
- 短く具体的に (最大3単語程度)
- main / develop に直接コミットしない
