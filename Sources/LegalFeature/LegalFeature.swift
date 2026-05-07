// LegalFeature — Phase 2.4 利用規約 / プライバシーポリシー

import ComposableArchitecture
import DesignSystem
import Foundation
import SwiftUI

@Reducer
public struct LegalFeature: Sendable {
    public enum Document: String, CaseIterable, Sendable, Equatable {
        case termsOfService = "利用規約"
        case privacyPolicy = "プライバシーポリシー"
    }

    @ObservableState
    public struct State: Equatable {
        public var selected: Document = .termsOfService
        public var hasAcceptedTerms: Bool = false
        public init() {}
    }

    public enum Action: Equatable {
        case selected(Document)
        case acceptTapped
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selected(d):
                state.selected = d
                return .none
            case .acceptTapped:
                state.hasAcceptedTerms = true
                return .none
            }
        }
    }
}

public struct LegalView: View {
    @Bindable public var store: StoreOf<LegalFeature>

    public init(store: StoreOf<LegalFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 16) {
            Picker("文書", selection: Binding(
                get: { store.selected },
                set: { store.send(.selected($0)) }
            )) {
                ForEach(LegalFeature.Document.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                Text(content(for: store.selected))
                    .font(.Lumi.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }

            if !store.hasAcceptedTerms {
                Button("同意する") {
                    store.send(.acceptTapped)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                Text("✓ 同意済み")
                    .foregroundStyle(Color.Lumi.excellent)
            }
        }
        .padding(16)
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
    }

    private func content(for d: LegalFeature.Document) -> String {
        switch d {
        case .termsOfService:
            return """
            # 利用規約

            このアプリ「Lumi」(以下「本アプリ」) を利用される前に、以下の規約をお読みください。

            ## 1. 利用許諾
            本アプリの著作権はすべて開発者に帰属します。利用者は本アプリを個人利用の範囲で使用することができます。

            ## 2. 禁止事項
            - 他者の試合データを許可なく取得・転載すること
            - リバースエンジニアリング
            - 本アプリを違法な目的で使用すること

            ## 3. 免責事項
            本アプリの利用によって生じたいかなる損害についても、開発者は責任を負いません。

            ## 4. データ保管
            試合データは Supabase 上に保管されます。詳細は別途プライバシーポリシーを参照してください。

            ## 5. 変更
            本規約は予告なく変更されることがあります。最新版は常に本画面で確認できます。

            最終更新日: 2026-05-05
            """
        case .privacyPolicy:
            return """
            # プライバシーポリシー

            「Lumi」(以下「本アプリ」) は、利用者のプライバシーを尊重します。

            ## 1. 取得する情報
            - Apple ID (Sign in with Apple 経由のユーザー識別子のみ。メールは Private Relay 可)
            - メールアドレス (任意、メール認証時のみ)
            - 試合データ (利用者が入力したもの)

            ## 2. 利用目的
            - 試合データの保存・同期
            - サービス改善
            - クラッシュ・エラーの解析 (Sentry)

            ## 3. 第三者提供
            利用者の同意なく第三者に提供することはありません。
            ただし以下の情報は外部サービスに送信されます:
            - Supabase: 試合データ、認証情報
            - Sentry: クラッシュレポート (個人情報はマスク済)

            ## 4. データ削除
            アカウント削除時、関連データはすべて消去されます。

            ## 5. 個人情報保護法対応
            開示・訂正・削除のリクエストは muramoto@swooo.net までご連絡ください。

            最終更新日: 2026-05-05
            """
        }
    }
}
