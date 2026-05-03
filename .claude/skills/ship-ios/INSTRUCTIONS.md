# ship-ios Instructions

## 事前準備

1. 設定ファイルを読む: `.claude/skills/ship-ios/config.json`
2. 事前チェック:
   - `/verify` が成功していること
   - git working tree がクリーンであること
   - 証明書・プロビジョニングプロファイルが有効であること

## リリースフロー

### 1. バージョン確認

```bash
# Info.plist からバージョン確認
xcodebuild -project Calame.xcodeproj -scheme Calame-iOS -showBuildSettings | grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION'
```

### 2. アーカイブ

```bash
xcodebuild archive \
  -project Calame.xcodeproj \
  -scheme Calame-iOS \
  -destination 'generic/platform=iOS' \
  -archivePath build/Calame.xcarchive \
  CODE_SIGN_STYLE=Automatic \
  2>&1 | tee /tmp/calame-archive.log
```

### 3. エクスポート

ExportOptions.plist を生成:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath build/Calame.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  2>&1 | tee /tmp/calame-export.log
```

### 4. App Store Connect アップロード

```bash
xcrun altool --upload-app \
  -f build/export/Calame.ipa \
  -t ios \
  --apiKey {API_KEY_ID} \
  --apiIssuer {API_ISSUER_ID} \
  2>&1 | tee /tmp/calame-upload.log
```

または `xcrun notarytool` / Transporter を使用。

## macOS アプリのリリース

```bash
# macOS アーカイブ
xcodebuild archive \
  -project Calame.xcodeproj \
  -scheme Calame-macOS \
  -archivePath build/Calame-macOS.xcarchive \
  2>&1 | tee /tmp/calame-mac-archive.log
```

## エラー対応

### コード署名エラー
- 証明書の有効期限を確認
- プロビジョニングプロファイルの更新
- `security find-identity -v -p codesigning` で証明書一覧確認

### アップロードエラー
- ネットワーク接続を確認
- API キーの有効性を確認
- バージョン番号が既存と重複していないか確認

## 出力フォーマット

```markdown
## Ship iOS 結果

| ステップ | 結果 | 詳細 |
|---------|------|------|
| アーカイブ | ✅ / ❌ | {アーカイブパス} |
| エクスポート | ✅ / ❌ | {IPA パス} |
| アップロード | ✅ / ❌ | {結果} |

### バージョン情報
- Version: {MARKETING_VERSION}
- Build: {CURRENT_PROJECT_VERSION}
```
