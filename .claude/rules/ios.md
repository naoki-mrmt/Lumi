# iOS開発ルール

## 技術スタック
- SwiftUI + TCA (Composable Architecture) 1.25.x
- SPMマルチモジュール構成 (CalameKit)
- Swift 6.x strict concurrency (async/await, Actor)
- SwiftData (single source of truth)
- WhisperKit (STT) + llama.cpp (LLM)
- 最低 macOS 26+ / iOS 26+

## SPMモジュール構成 (Packages/CalameKit/)
```
Sources/
  Core/         — Models/, Extensions/, Constants.swift
  Domain/       — AudioEngine/, WhisperService/, LLMService/, TextOutputService/,
                  ContextService/, DictionaryService/, TextProcessor/
  Persistence/  — SwiftDataModels/, Repository/, Migration/
  Features/     — App/, Recording/, Settings/, Dictionary/, Profiles/, History/
  SharedUI/     — FloatingPreview/, WaveformView/, Components/
Tests/
  DomainTests/, PersistenceTests/, FeatureTests/
```

## TCA規約
- Feature = Reducer + View のペア
- DependencyKey で外部依存を注入
- テストでは TestStore + override で検証
- Effect内のエラーは Action で伝播、View側で表示
- Domain層はTCA非依存 — Protocol で抽象化

## サービス設計
- LLMServiceProtocol: EmbeddedLLMService (llama.cpp) / OllamaLLMService (HTTP) / CloudLLMService (将来)
- WhisperServiceProtocol: WhisperKitService
- TextOutputServiceProtocol: クリップボード + AXUIElement
- 全サービスは Protocol-first で設計

## SwiftUI gotchas
- NavigationStack使用 (NavigationView非推奨)
- @Observable (iOS 17+) を使用、@ObservedObject は使わない
- List内のForEachには安定したidを使う
- .task {} でasync処理、onAppearでasyncは使わない
- Preview用モックデータを必ず用意

## SwiftData gotchas
- @Model classは actor-isolated ではない、MainActor上で操作
- SwiftDataが唯一のデータ永続化手段（UserDefaults, CoreData不使用）
- ModelContainerはApp起動時に1回だけ生成

## Concurrency gotchas
- @MainActor を View と ViewModel (Reducer) に付与
- Sendable 準拠を意識、non-Sendable型をactor境界で渡さない
- TaskGroupで並列処理する際はキャンセレーション対応必須
