# ship-ios

iOS / macOS アプリを App Store Connect にアップロードする。アーカイブ → エクスポート → アップロードの自動化。

## Trigger
- `/ship-ios` でリリースビルド + アップロード
- `/ship-ios archive` でアーカイブのみ
- `/ship-ios upload` でアップロードのみ

## Input
- なし (config.json から設定を読み込み)

## Output
- .xcarchive ファイル
- .ipa エクスポート
- App Store Connect へのアップロード結果
