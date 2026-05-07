// MatchViewerFeature — 試合閲覧 (KPIダッシュボード + 得点推移グラフ + フィルタ)

import ComposableArchitecture
import Foundation
import Models
import StatsEngine

@Reducer
public struct MatchViewerFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var match: Match
        public var statsScope: StatsScope = .wholeMatch
        public var selectedPlayerId: UUID?
        public var ownStats: TeamStats = .empty
        public var opponentStats: TeamStats = .empty
        public var playerStats: PlayerStats?
        public var consecutiveRuns: [ConsecutiveRun] = []

        public init(match: Match) {
            self.match = match
        }
    }

    public enum Action: Equatable {
        case onAppear
        case scopeChanged(StatsScope)
        case playerSelected(UUID?)
        case matchUpdated(Match)
        case statsRecomputed(own: TeamStats, opp: TeamStats, player: PlayerStats?, runs: [ConsecutiveRun])
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return recompute(state: state)

            case let .scopeChanged(scope):
                state.statsScope = scope
                return recompute(state: state)

            case let .playerSelected(id):
                state.selectedPlayerId = id
                return recompute(state: state)

            case let .matchUpdated(match):
                state.match = match
                return recompute(state: state)

            case let .statsRecomputed(own, opp, player, runs):
                state.ownStats = own
                state.opponentStats = opp
                state.playerStats = player
                state.consecutiveRuns = runs
                return .none
            }
        }
    }

    private func recompute(state: State) -> Effect<Action> {
        let match = state.match
        let scope = state.statsScope
        let playerId = state.selectedPlayerId
        return .run { send in
            let engine = StatsEngine()
            let own = engine.teamStats(in: match, scope: scope, side: .own)
            let opp = engine.teamStats(in: match, scope: scope, side: .opponent)
            let playerStats = playerId.map { engine.playerStats(playerId: $0, in: match, scope: scope) }
            let runs = match.sets.flatMap { engine.consecutiveRuns(in: $0) }
            await send(.statsRecomputed(own: own, opp: opp, player: playerStats, runs: runs))
        }
    }
}
