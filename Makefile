SHELL := /bin/bash

# Lumi 開発タスク
# 主要なコマンドをまとめた Makefile。`make help` で一覧。

XCODE_DEVELOPER ?= /Applications/Xcode-26.5.0-Beta.3.app/Contents/Developer
DESTINATION ?= platform=iOS Simulator,name=iPad Pro 13-inch (M5)
SCHEME ?= Lumi
PROJECT ?= Lumi.xcodeproj

.PHONY: help
help: ## 各 target の説明を表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ────────────────────────────────────────────────
# Swift / Xcode
# ────────────────────────────────────────────────
.PHONY: build
build: ## iPad Simulator 向けに Xcode ビルド
	DEVELOPER_DIR=$(XCODE_DEVELOPER) xcodebuild build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO

.PHONY: spm-build
spm-build: ## Swift Package Manager のみで build
	DEVELOPER_DIR=$(XCODE_DEVELOPER) swift build

.PHONY: test
test: ## SPM 全テスト実行
	DEVELOPER_DIR=$(XCODE_DEVELOPER) swift test

.PHONY: test-xcode
test-xcode: ## Xcode 経由テスト (iPad Sim)
	DEVELOPER_DIR=$(XCODE_DEVELOPER) xcodebuild test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO

.PHONY: test-snapshots
test-snapshots: ## SnapshotTests のみ iPad Sim で実行 (LumiKit-Package scheme)
	DEVELOPER_DIR=$(XCODE_DEVELOPER) xcodebuild test \
		-workspace . -scheme LumiKit-Package \
		-destination '$(DESTINATION)' \
		-only-testing:SnapshotTests \
		-skipMacroValidation

.PHONY: clean
clean: ## .build / DerivedData をクリア
	rm -rf .build
	rm -rf ~/Library/Developer/Xcode/DerivedData/Lumi-*

.PHONY: resolve
resolve: ## SPM 依存解決
	DEVELOPER_DIR=$(XCODE_DEVELOPER) swift package resolve

.PHONY: format
format: ## swift-format で整形 (必要時)
	@which swift-format > /dev/null || (echo "swift-format not installed" && exit 1)
	swift-format -i -r Sources Tests

# ────────────────────────────────────────────────
# Supabase
# ────────────────────────────────────────────────
.PHONY: db-start
db-start: ## ローカル Supabase 起動
	supabase start

.PHONY: db-stop
db-stop: ## ローカル Supabase 停止
	supabase stop

.PHONY: db-reset
db-reset: ## ローカル DB を migrations + seed で初期化
	supabase db reset

.PHONY: db-push
db-push: ## migrations をリモートに適用
	supabase db push

.PHONY: db-diff
db-diff: ## ローカル変更を migration として書き出し
	supabase db diff -f new_migration

.PHONY: functions-serve
functions-serve: ## Edge Functions をローカル起動
	supabase functions serve

.PHONY: functions-deploy
functions-deploy: ## Edge Functions を本番デプロイ
	supabase functions deploy viewer-session
	supabase functions deploy cleanup-expired-codes --no-verify-jwt
	supabase functions deploy delete-account

.PHONY: db-lint
db-lint: ## SQL マイグレーションを lint (SQLFluff があれば)
	@which sqlfluff > /dev/null && sqlfluff lint supabase/migrations/ --dialect postgres || echo "sqlfluff not installed - skipping"

# ────────────────────────────────────────────────
# 公開リポ対策
# ────────────────────────────────────────────────
.PHONY: secrets-scan
secrets-scan: ## リポジトリ内に秘匿情報が含まれていないか確認
	@echo "Checking for likely secrets..."
	@! git grep -nE 'sk_live_|pk_live_|eyJ[A-Za-z0-9_-]{20,}|supabase_anon_key\s*=\s*"[^"]+"|sentry\.io/[0-9]+' -- ':!*.md' ':!Makefile' || (echo "Possible secret detected" && exit 1)
	@echo "No obvious secrets found"

.PHONY: gitignore-check
gitignore-check: ## Config.swift / .env が誤コミットされていないか確認
	@! git ls-files | grep -E '^(Lumi/Config\.swift|\.env)$$' || (echo "Secret file tracked!" && exit 1)
	@echo "OK"

# ────────────────────────────────────────────────
# Bootstrap
# ────────────────────────────────────────────────
.PHONY: bootstrap
bootstrap: ## 初回セットアップ (Config.local.xcconfig コピー、SPM resolve)
	@if [ ! -f Config.local.xcconfig ]; then \
		cp Config.local.xcconfig.template Config.local.xcconfig; \
		echo "Created Config.local.xcconfig — fill in your secrets (.gitignore 済み)"; \
	else \
		echo "Config.local.xcconfig already exists"; \
	fi
	$(MAKE) resolve
	@echo "Bootstrap complete. Run 'make build' next."
