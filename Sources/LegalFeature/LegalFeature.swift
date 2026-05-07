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
            return Self.termsOfService
        case .privacyPolicy:
            return Self.privacyPolicy
        }
    }

    static let termsOfService = """
    # Lumi 利用規約

    本利用規約 (以下「本規約」) は、開発者 (以下「当方」) が提供するアプリケーション「Lumi」(以下「本アプリ」) の利用条件を定めるものです。本アプリをご利用される前に必ずお読みください。

    ## 第1条 (適用)
    本規約は、利用者と当方との間の本アプリの利用に関わる一切の関係に適用されます。

    ## 第2条 (利用登録)
    1. 利用者は Sign in with Apple またはメール認証によりアカウントを登録できます。
    2. 13 歳未満の方は保護者の同意のもとで利用してください。

    ## 第3条 (利用料金)
    本アプリの基本機能は無料で提供されます。Phase 2.4 以降、追加機能の一部は App Store 経由のアプリ内課金となる予定です。

    ## 第4条 (禁止事項)
    利用者は本アプリの利用にあたり、以下の行為をしてはなりません。
    1. 法令または公序良俗に違反する行為
    2. 他者の権利・プライバシーを侵害する行為
    3. リバースエンジニアリング・改変行為
    4. 自動化ツールを用いた大量アクセス
    5. 他者の試合データを許可なく取得・転載・公開する行為

    ## 第5条 (本アプリの提供の停止等)
    当方は、以下の場合には事前通知なく本アプリの全部または一部の提供を停止または中断できます。
    1. システム保守・更新
    2. 地震・落雷・火災等の不可抗力
    3. その他、当方が停止または中断を必要と判断した場合

    ## 第6条 (著作権)
    本アプリ自体の著作権は当方に帰属します。利用者が本アプリに入力した試合データの著作権は利用者に帰属します。

    ## 第7条 (免責事項)
    1. 当方は、本アプリに関して、その正確性・完全性・有用性等を保証しません。
    2. 本アプリの利用によって利用者に生じたあらゆる損害について、当方は責任を負いません。

    ## 第8条 (サービス内容の変更)
    当方は、利用者への事前通知なく本アプリのサービス内容を変更・追加・廃止することがあります。

    ## 第9条 (利用規約の変更)
    当方は必要と判断した場合、利用者への事前通知なく本規約を変更できます。変更後の規約は本画面に掲示された時点で効力を生じます。

    ## 第10条 (準拠法・裁判管轄)
    本規約の解釈は日本法に従います。本アプリに関して紛争が生じた場合、当方の所在地を管轄する裁判所を専属的合意管轄とします。

    ## 第11条 (お問い合わせ)
    本規約に関するお問い合わせは muramoto@swooo.net までご連絡ください。

    最終更新日: 2026-05-07
    """

    static let privacyPolicy = """
    # Lumi プライバシーポリシー

    開発者 (以下「当方」) は、本アプリ「Lumi」(以下「本アプリ」) における利用者の個人情報の取扱いについて、以下のとおりプライバシーポリシー (以下「本ポリシー」) を定めます。

    ## 第1条 (個人情報)
    「個人情報」とは、個人情報保護法にいう「個人情報」を指し、生存する個人に関する情報であって、当該情報に含まれる氏名、メールアドレス、その他の記述等により特定の個人を識別できるものを指します。

    ## 第2条 (取得する情報)
    本アプリは以下の情報を取得します。
    1. **Apple ID 識別子** (Sign in with Apple 利用時): Apple が発行する不可逆なユーザー識別子。メールアドレスは Apple の Private Relay 機能を介する場合があります。
    2. **メールアドレス** (メール認証利用時のみ): サインインおよびパスワードリセットの目的で使用。
    3. **試合データ**: 利用者が記録する試合・選手・得点・KPI 等。匿名加工した相手チーム名 (マスキング機能) も含む。
    4. **クラッシュ情報**: Sentry SDK が自動取得 (スタックトレース・OS バージョン・端末モデル等)。個人情報は `beforeSend` で除去済み。
    5. **デバイス情報**: バッテリー状態 (試合中の警告用)、ネットワーク状態 (オフライン同期用)。

    ## 第3条 (利用目的)
    取得した情報は以下の目的で利用します。
    1. 試合データの保存・同期 (Supabase 経由)
    2. 利用者の本人確認
    3. サービス改善・新機能開発
    4. クラッシュ・障害の特定と修正

    ## 第4条 (第三者への提供)
    利用者の事前同意なく個人情報を第三者に提供することはありません。ただし以下のサービスを利用しているため、規定情報がそれぞれの事業者に送信されます。
    - **Supabase, Inc.** (米国): 試合データ・認証情報の保存
    - **Functional Software, Inc. (Sentry)** (米国): クラッシュレポート (PII は除去済み)
    - **Apple Inc.**: Sign in with Apple 経由の認証

    ## 第5条 (個人情報の保管)
    1. 認証情報 (アクセストークン): 端末の Keychain に SDK が暗号化保管。
    2. 試合データ: 端末ローカルの SwiftData + Supabase クラウド (TLS 1.2 以上で送受信)。
    3. Row Level Security (RLS): 試合データは作成者本人のみ参照・編集可能。

    ## 第6条 (個人情報の開示・訂正・削除)
    利用者は当方に対し、以下を請求できます。
    1. 取得済み個人情報の開示
    2. 個人情報の訂正・追加・削除
    3. アプリ内「アカウント削除」メニューからの即時削除 (関連データすべて消去)

    請求は muramoto@swooo.net までメールでご連絡ください。

    ## 第7条 (Cookie / 解析ツール)
    本アプリではブラウザ Cookie は使用しません。Sentry SDK によるエラー解析のみ行います。

    ## 第8条 (児童のプライバシー)
    13 歳未満の利用者については、保護者の同意のもとで利用していただくものとします。

    ## 第9条 (プライバシーポリシーの変更)
    本ポリシーの内容は、利用者への事前通知なく変更されることがあります。変更後の本ポリシーは本画面に掲示された時点で効力を生じます。

    ## 第10条 (お問い合わせ)
    本ポリシーに関するお問い合わせは muramoto@swooo.net までご連絡ください。

    最終更新日: 2026-05-07
    """
}
