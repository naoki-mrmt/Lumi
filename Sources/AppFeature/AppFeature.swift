// AppFeature — ルートTCA Reducer

import AuthFeature
import ComposableArchitecture
import Dependencies
import EmailAuthFeature
import Foundation
import LegalFeature
import LocalStore
import MatchInputFeature
import MatchSetupFeature
import MatchViewerFeature
import Models
import OpponentDatabaseFeature
import PlayerPageFeature
import ReportFeature
import ReviewFeature
import SwiftUI
import TeamManagementFeature
import TeamSwitcherFeature
import VideoReviewFeature
import VideoStreamFeature

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var team: Team?
        public var allMatches: [Match] = []

        // 認証 (M4 + Auth ガード)
        public var session: AuthSession?
        /// Live Supabase が設定済みなら認証必須。Mock のローカル開発時は false
        public var isAuthRequired: Bool

        public var teamManagement: TeamManagementFeature.State?
        public var matchSetup: MatchSetupFeature.State?
        public var matchInput: MatchInputFeature.State?
        public var matchViewer: MatchViewerFeature.State?
        public var review: ReviewFeature.State?

        // Phase 2
        public var report: ReportFeature.State?
        public var opponentDB: OpponentDatabaseFeature.State?
        public var videoReview: VideoReviewFeature.State?
        public var playerPage: PlayerPageFeature.State?
        public var videoStream: VideoStreamFeature.State?
        public var emailAuth: EmailAuthFeature.State?
        public var teamSwitcher: TeamSwitcherFeature.State?
        public var legal: LegalFeature.State?

        public var errorMessage: String?
        public var recoverableMatch: Match?
        public var presentingDeleteAccountConfirm: Bool = false

        public init(isAuthRequired: Bool = false) {
            self.isAuthRequired = isAuthRequired
        }

        /// 認証ガードを表示すべきかどうか
        public var shouldShowAuthGate: Bool {
            isAuthRequired && session == nil
        }
    }

    public enum Action: Equatable {
        case onAppear
        case sessionLoaded(AuthSession?)
        case signOutTapped
        case signedOut
        case deleteAccountTapped
        case deleteAccountConfirmed
        case deleteAccountCancelled
        case accountDeleted
        case teamLoaded(Team?)
        case matchesLoaded([Match])
        case loadFailed(String)
        case createDefaultTeamTapped
        case openTeamManagement
        case openMatchSetup
        case openMatchInput(Match)
        case openMatchViewer(Match)
        case openReview(Match)
        // Phase 2
        case openReport
        case openOpponentDB
        case openVideoReview(Match)
        case openPlayerPage(UUID)
        case openVideoStream
        case openEmailAuth
        case openTeamSwitcher
        case openLegal
        case closeChild
        case recoveryFound(Match)
        case recoveryAccepted
        case recoveryDismissed

        case teamManagement(TeamManagementFeature.Action)
        case matchSetup(MatchSetupFeature.Action)
        case matchInput(MatchInputFeature.Action)
        case matchViewer(MatchViewerFeature.Action)
        case review(ReviewFeature.Action)
        case report(ReportFeature.Action)
        case opponentDB(OpponentDatabaseFeature.Action)
        case videoReview(VideoReviewFeature.Action)
        case playerPage(PlayerPageFeature.Action)
        case videoStream(VideoStreamFeature.Action)
        case emailAuth(EmailAuthFeature.Action)
        case teamSwitcher(TeamSwitcherFeature.Action)
        case legal(LegalFeature.Action)
    }

    @Dependency(\.localStore) var localStore
    @Dependency(\.supabaseAuthClient) var supabaseAuth

    public init() {}

    public var body: some ReducerOf<Self> {
        // 子 Reducer を先に走らせ、親はその後の post-process でだけ state を nil にする
        // (ifLet 側の "child action while state was nil" 警告を避けるため)
        Phase1Children()
        Phase2Children()
        Phase2bChildren()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // セッション読み込みを並行で開始
                    async let sessionTask = supabaseAuth.currentSession()
                    do {
                        async let teamsTask = localStore.fetchTeams()
                        async let recoveryTask = localStore.findInProgressMatch()
                        let (teams, recovery, session) = try await (teamsTask, recoveryTask, sessionTask)
                        await send(.sessionLoaded(session))
                        await send(.teamLoaded(teams.first))
                        if let team = teams.first {
                            let matches = try await localStore.fetchMatches(team.id)
                            await send(.matchesLoaded(matches))
                        }
                        if let match = recovery {
                            await send(.recoveryFound(match))
                        }
                    } catch {
                        let session = await sessionTask
                        await send(.sessionLoaded(session))
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .sessionLoaded(session):
                state.session = session
                // 認証必須かつ未サインインなら EmailAuth を提示
                if state.isAuthRequired && session == nil && state.emailAuth == nil {
                    state.emailAuth = EmailAuthFeature.State()
                }
                return .none

            case .signOutTapped:
                return .run { send in
                    try? await supabaseAuth.signOut()
                    await send(.signedOut)
                }

            case .signedOut:
                state.session = nil
                if state.isAuthRequired {
                    state.emailAuth = EmailAuthFeature.State()
                }
                return .none

            case .deleteAccountTapped:
                state.presentingDeleteAccountConfirm = true
                return .none

            case .deleteAccountCancelled:
                state.presentingDeleteAccountConfirm = false
                return .none

            case .deleteAccountConfirmed:
                state.presentingDeleteAccountConfirm = false
                return .run { send in
                    do {
                        try await supabaseAuth.deleteAccount()
                    } catch {
                        // Edge Function 失敗時はサインアウトのみで続行 (ユーザは削除リクエストできた状態)
                        try? await supabaseAuth.signOut()
                    }
                    await send(.accountDeleted)
                }

            case .accountDeleted:
                state.session = nil
                state.team = nil
                state.allMatches = []
                if state.isAuthRequired {
                    state.emailAuth = EmailAuthFeature.State()
                }
                return .none

            case let .teamLoaded(team):
                state.team = team
                return .none

            case let .matchesLoaded(matches):
                state.allMatches = matches
                return .none

            case let .loadFailed(msg):
                state.errorMessage = msg
                return .none

            case let .recoveryFound(match):
                state.recoverableMatch = match
                return .none

            case .recoveryAccepted:
                guard let match = state.recoverableMatch else { return .none }
                state.recoverableMatch = nil
                state.matchInput = MatchInputFeature.State(match: match, currentSetId: match.sets[0].id)
                return .none

            case .recoveryDismissed:
                state.recoverableMatch = nil
                return .none

            case .createDefaultTeamTapped:
                let team = Team(ownerId: UUID(), name: "Lumi Volley")
                state.team = team
                return .run { send in
                    do {
                        try await localStore.saveTeam(team)
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .openTeamManagement:
                guard let team = state.team else { return .none }
                state.teamManagement = TeamManagementFeature.State(team: team)
                return .none

            case .openMatchSetup:
                guard let team = state.team else { return .none }
                state.matchSetup = MatchSetupFeature.State(team: team)
                return .none

            case let .openMatchInput(match):
                guard let setId = match.sets.first?.id else { return .none }
                state.matchInput = MatchInputFeature.State(match: match, currentSetId: setId)
                return .none

            case let .openMatchViewer(match):
                state.matchViewer = MatchViewerFeature.State(match: match)
                return .none

            case let .openReview(match):
                state.review = ReviewFeature.State(match: match)
                return .none

            case .openReport:
                state.report = ReportFeature.State(matches: state.allMatches)
                return .none

            case .openOpponentDB:
                state.opponentDB = OpponentDatabaseFeature.State(matches: state.allMatches)
                return .none

            case let .openVideoReview(match):
                state.videoReview = VideoReviewFeature.State(match: match)
                return .none

            case let .openPlayerPage(playerId):
                state.playerPage = PlayerPageFeature.State(playerId: playerId, matches: state.allMatches)
                return .none

            case .openVideoStream:
                state.videoStream = VideoStreamFeature.State()
                return .none

            case .openEmailAuth:
                state.emailAuth = EmailAuthFeature.State()
                return .none

            case .openTeamSwitcher:
                state.teamSwitcher = TeamSwitcherFeature.State()
                return .none

            case .openLegal:
                state.legal = LegalFeature.State()
                return .none

            case .closeChild:
                state.teamManagement = nil
                state.matchSetup = nil
                state.matchInput = nil
                state.matchViewer = nil
                state.review = nil
                state.report = nil
                state.opponentDB = nil
                state.videoReview = nil
                state.playerPage = nil
                state.videoStream = nil
                state.emailAuth = nil
                state.teamSwitcher = nil
                state.legal = nil
                return .none

            case .matchSetup(.matchPrepared(let match)):
                state.matchSetup = nil
                state.matchInput = MatchInputFeature.State(match: match, currentSetId: match.sets[0].id)
                state.allMatches.append(match)
                return .none

            case let .emailAuth(.sessionReceived(session)):
                state.session = session
                state.emailAuth = nil
                return .none

            case .teamManagement, .matchSetup, .matchInput, .matchViewer, .review,
                 .report, .opponentDB, .videoReview, .playerPage, .videoStream,
                 .emailAuth, .teamSwitcher, .legal:
                return .none
            }
        }
    }
}

// 子 Reducer を 2 つに分割 (型チェッカーの timeout 回避)

private struct Phase1Children: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action
    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifLet(\.teamManagement, action: \.teamManagement) { TeamManagementFeature() }
            .ifLet(\.matchSetup, action: \.matchSetup) { MatchSetupFeature() }
            .ifLet(\.matchInput, action: \.matchInput) { MatchInputFeature() }
            .ifLet(\.matchViewer, action: \.matchViewer) { MatchViewerFeature() }
            .ifLet(\.review, action: \.review) { ReviewFeature() }
    }
}

private struct Phase2Children: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action
    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifLet(\.report, action: \.report) { ReportFeature() }
            .ifLet(\.opponentDB, action: \.opponentDB) { OpponentDatabaseFeature() }
            .ifLet(\.videoReview, action: \.videoReview) { VideoReviewFeature() }
            .ifLet(\.playerPage, action: \.playerPage) { PlayerPageFeature() }
    }
}

private struct Phase2bChildren: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action
    var body: some ReducerOf<Self> {
        EmptyReducer()
            .ifLet(\.videoStream, action: \.videoStream) { VideoStreamFeature() }
            .ifLet(\.emailAuth, action: \.emailAuth) { EmailAuthFeature() }
            .ifLet(\.teamSwitcher, action: \.teamSwitcher) { TeamSwitcherFeature() }
            .ifLet(\.legal, action: \.legal) { LegalFeature() }
    }
}

// MARK: - View

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if store.team != nil {
                        primaryActions
                        Divider()
                        secondaryMenu
                        if store.session != nil {
                            Divider()
                            signOutSection
                        }
                    } else {
                        Button("デフォルトチームを作成") {
                            store.send(.createDefaultTeamTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Lumi")
            .task { store.send(.onAppear) }
            .modifier(AppSheetsModifier(store: store))
            .modifier(AuthGateModifier(store: store))
            .alert(
                "中断中の試合を復元しますか？",
                isPresented: Binding(
                    get: { store.recoverableMatch != nil },
                    set: { if !$0 { store.send(.recoveryDismissed) } }
                ),
                presenting: store.recoverableMatch
            ) { _ in
                Button("復元") { store.send(.recoveryAccepted) }
                Button("破棄", role: .destructive) { store.send(.recoveryDismissed) }
                Button("キャンセル", role: .cancel) {}
            } message: { match in
                Text("vs \(match.opponentTeamName)\n\(match.date.formatted(date: .abbreviated, time: .omitted))")
            }
            .alert(
                "アカウントを削除しますか?",
                isPresented: Binding(
                    get: { store.presentingDeleteAccountConfirm },
                    set: { if !$0 { store.send(.deleteAccountCancelled) } }
                )
            ) {
                Button("削除する", role: .destructive) { store.send(.deleteAccountConfirmed) }
                Button("キャンセル", role: .cancel) { store.send(.deleteAccountCancelled) }
            } message: {
                Text("関連するすべての試合データ・選手・対戦相手 DB が消去されます。この操作は取り消せません。")
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "volleyball.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Lumi").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("9人制バレーボール スカウティング")
                .font(.subheadline).foregroundStyle(.secondary)
            if let name = store.team?.name {
                Text("チーム: \(name)").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.openMatchSetup)
            } label: {
                Label("試合を作成", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)

            Button {
                store.send(.openTeamManagement)
            } label: {
                Label("チーム管理 (選手15人)", systemImage: "person.3")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var secondaryMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ツール").font(.headline).foregroundStyle(.secondary)
            menuRow("doc.richtext", "レポート") { store.send(.openReport) }
            menuRow("person.text.rectangle", "対戦相手 DB") { store.send(.openOpponentDB) }
            menuRow("video", "動画レビュー") {
                if let match = store.allMatches.first {
                    store.send(.openVideoReview(match))
                }
            }
            menuRow("dot.radiowaves.left.and.right", "ライブ映像配信") { store.send(.openVideoStream) }
            menuRow("rectangle.2.swap", "チーム切替") { store.send(.openTeamSwitcher) }
            menuRow("envelope", "メール認証") { store.send(.openEmailAuth) }
            menuRow("doc.text", "利用規約 / プライバシー") { store.send(.openLegal) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = store.session?.email {
                Text("サインイン中: \(email)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("サインアウト") {
                    store.send(.signOutTapped)
                }
                .buttonStyle(.bordered)

                Button("アカウント削除", role: .destructive) {
                    store.send(.deleteAccountTapped)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func menuRow(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Auth Gate Modifier (iOS のみ fullScreenCover、macOS は sheet にフォールバック)

private struct AuthGateModifier: ViewModifier {
    @Bindable var store: StoreOf<AppFeature>

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: .constant(store.shouldShowAuthGate)) {
            authGateContent
        }
        #else
        content.sheet(isPresented: .constant(store.shouldShowAuthGate)) {
            authGateContent
        }
        #endif
    }

    @ViewBuilder
    private var authGateContent: some View {
        if let s = store.scope(state: \.emailAuth, action: \.emailAuth) {
            NavigationStack {
                EmailAuthView(store: s)
                    .navigationTitle("サインイン")
            }
            .interactiveDismissDisabled()
        }
    }
}

// MARK: - Sheet Modifier (1 ViewModifier に集約して View 本体を圧迫しない)

private struct AppSheetsModifier: ViewModifier {
    @Bindable var store: StoreOf<AppFeature>

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: bind(\.teamManagement)) {
                if let s = store.scope(state: \.teamManagement, action: \.teamManagement) {
                    TeamManagementView(store: s)
                }
            }
            .sheet(isPresented: bind(\.matchSetup)) {
                if let s = store.scope(state: \.matchSetup, action: \.matchSetup) {
                    MatchSetupView(store: s)
                }
            }
            .sheet(isPresented: bind(\.matchInput)) {
                if let s = store.scope(state: \.matchInput, action: \.matchInput) {
                    NavigationStack {
                        MatchInputView(store: s)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("閉じる") { store.send(.closeChild) }
                                }
                                if let m = store.matchInput?.match {
                                    ToolbarItem(placement: .primaryAction) {
                                        Button("KPI") { store.send(.openMatchViewer(m)) }
                                    }
                                    ToolbarItem(placement: .primaryAction) {
                                        Button("振り返り") { store.send(.openReview(m)) }
                                    }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: bind(\.matchViewer)) {
                if let s = store.scope(state: \.matchViewer, action: \.matchViewer) {
                    wrapInNav(MatchViewerView(store: s))
                }
            }
            .sheet(isPresented: bind(\.review)) {
                if let s = store.scope(state: \.review, action: \.review) {
                    wrapInNav(ReviewView(store: s), title: "振り返り")
                }
            }
            .sheet(isPresented: bind(\.report)) {
                if let s = store.scope(state: \.report, action: \.report) {
                    wrapInNav(ReportView(store: s), title: "レポート")
                }
            }
            .sheet(isPresented: bind(\.opponentDB)) {
                if let s = store.scope(state: \.opponentDB, action: \.opponentDB) {
                    OpponentDatabaseView(store: s)
                }
            }
            .sheet(isPresented: bind(\.videoReview)) {
                if let s = store.scope(state: \.videoReview, action: \.videoReview) {
                    wrapInNav(VideoReviewView(store: s), title: "動画レビュー")
                }
            }
            .sheet(isPresented: bind(\.playerPage)) {
                if let s = store.scope(state: \.playerPage, action: \.playerPage) {
                    wrapInNav(PlayerPageView(store: s), title: "選手ページ")
                }
            }
            .sheet(isPresented: bind(\.videoStream)) {
                if let s = store.scope(state: \.videoStream, action: \.videoStream) {
                    wrapInNav(VideoStreamView(store: s), title: "ライブ映像")
                }
            }
            .sheet(isPresented: Binding(
                get: { !store.shouldShowAuthGate && store.emailAuth != nil },
                set: { if !$0 { store.send(.closeChild) } }
            )) {
                if let s = store.scope(state: \.emailAuth, action: \.emailAuth) {
                    wrapInNav(EmailAuthView(store: s), title: "メール認証")
                }
            }
            .sheet(isPresented: bind(\.teamSwitcher)) {
                if let s = store.scope(state: \.teamSwitcher, action: \.teamSwitcher) {
                    wrapInNav(TeamSwitcherView(store: s), title: "チーム切替")
                }
            }
            .sheet(isPresented: bind(\.legal)) {
                if let s = store.scope(state: \.legal, action: \.legal) {
                    wrapInNav(LegalView(store: s), title: "規約 / プライバシー")
                }
            }
    }

    private func bind<T>(_ keyPath: KeyPath<AppFeature.State, T?>) -> Binding<Bool> {
        Binding(
            get: { store.state[keyPath: keyPath] != nil },
            set: { if !$0 { store.send(.closeChild) } }
        )
    }

    @ViewBuilder
    private func wrapInNav<V: View>(_ view: V, title: String? = nil) -> some View {
        NavigationStack {
            view
                .navigationTitle(title ?? "")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { store.send(.closeChild) }
                    }
                }
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
