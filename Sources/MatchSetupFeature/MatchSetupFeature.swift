// MatchSetupFeature — 試合作成 (基本情報・スタメン9人・サービス順・フォーメーション)

import ComposableArchitecture
import Foundation
import Models
import LocalStore
import ServiceOrderEngine

@Reducer
public struct MatchSetupFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var team: Team
        public var availablePlayers: [Player] = []

        // 試合基本情報
        public var date: Date = Date()
        public var startTime: Date = Date()
        public var opponentTeamName: String = ""
        public var tournamentName: String = ""
        public var matchType: MatchType = .practice
        public var venue: String = ""
        public var formation: Formation = .f5_1_3

        /// スタメン (順序付き、9人)。サービス順 = この配列の index + 1
        public var startingLineup: [Player] = []
        /// 控え (任意)
        public var benchPlayers: [Player] = []

        public var errorMessage: String?
        public var lastMatchAvailable: Bool = false
        public var setupResult: Match?

        public init(team: Team) {
            self.team = team
        }
    }

    public enum Action: Equatable {
        case onAppear
        case playersLoaded([Player])
        case lastMatchLoaded(Match?)
        case loadFailed(String)
        case opponentNameChanged(String)
        case tournamentNameChanged(String)
        case venueChanged(String)
        case matchTypeChanged(MatchType)
        case formationChanged(Formation)
        case dateChanged(Date)
        case startTimeChanged(Date)
        case togglePlayerInLineup(Player)
        case moveLineupPlayer(fromOffset: Int, toOffset: Int)
        case copyFromLastMatchTapped
        case lineupCopied(lineup: [Player], formation: Formation)
        case createMatchTapped(recorderId: UUID, matchCode: String, codeExpiresAt: Date)
        case matchPrepared(Match)
        case errorDismissed
    }

    @Dependency(\.localStore) var localStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let teamId = state.team.id
                return .run { send in
                    do {
                        async let players = localStore.fetchPlayers(teamId)
                        async let last = localStore.fetchLastMatch(teamId)
                        let (loadedPlayers, lastMatch) = try await (players, last)
                        await send(.playersLoaded(loadedPlayers))
                        await send(.lastMatchLoaded(lastMatch))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .playersLoaded(players):
                state.availablePlayers = players.filter(\.isActive)
                return .none

            case let .lastMatchLoaded(match):
                state.lastMatchAvailable = match != nil
                return .none

            case let .loadFailed(msg):
                state.errorMessage = msg
                return .none

            case let .opponentNameChanged(name):
                state.opponentTeamName = name
                return .none

            case let .tournamentNameChanged(name):
                state.tournamentName = name
                return .none

            case let .venueChanged(v):
                state.venue = v
                return .none

            case let .matchTypeChanged(type):
                state.matchType = type
                return .none

            case let .formationChanged(f):
                state.formation = f
                return .none

            case let .dateChanged(d):
                state.date = d
                return .none

            case let .startTimeChanged(d):
                state.startTime = d
                return .none

            case let .togglePlayerInLineup(player):
                if let idx = state.startingLineup.firstIndex(of: player) {
                    state.startingLineup.remove(at: idx)
                } else if state.startingLineup.count < 9 {
                    state.startingLineup.append(player)
                }
                return .none

            case let .moveLineupPlayer(from, to):
                guard state.startingLineup.indices.contains(from),
                      to >= 0, to <= state.startingLineup.count else { return .none }
                let player = state.startingLineup.remove(at: from)
                let target = to > from ? to - 1 : to
                state.startingLineup.insert(player, at: min(target, state.startingLineup.count))
                return .none

            case .copyFromLastMatchTapped:
                let teamId = state.team.id
                return .run { send in
                    do {
                        guard let last = try await localStore.fetchLastMatch(teamId) else { return }

                        // サービス順 (1..9) に並べた starter player ids
                        let starterIds = last.serviceOrders
                            .sorted(by: { $0.order < $1.order })
                            .map(\.startingPlayerId)
                        var ordered = starterIds
                        let starterMembers = last.members.filter(\.isStarter)
                        for member in starterMembers where !ordered.contains(member.playerId) {
                            ordered.append(member.playerId)
                        }
                        ordered = Array(ordered.prefix(9))

                        let allPlayers = try await localStore.fetchPlayers(teamId)
                        let lookup = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
                        let lineup = ordered.compactMap { lookup[$0] }
                        let formation = last.sets.first?.formation ?? .f5_1_3
                        await send(.lineupCopied(lineup: lineup, formation: formation))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .lineupCopied(lineup, formation):
                state.startingLineup = lineup
                state.formation = formation
                return .none

            case let .createMatchTapped(recorderId, matchCode, codeExpiresAt):
                guard state.startingLineup.count == 9 else {
                    state.errorMessage = "スタメン9人を選択してください"
                    return .none
                }
                guard !state.opponentTeamName.isEmpty else {
                    state.errorMessage = "対戦相手名を入力してください"
                    return .none
                }
                let match = makeMatch(state: state, recorderId: recorderId, matchCode: matchCode, codeExpiresAt: codeExpiresAt)
                let engine = ServiceOrderEngine()
                let starting = state.startingLineup.enumerated().map {
                    (order: $0.offset + 1, playerId: $0.element.id)
                }
                do {
                    let prepared = try engine.initializeForNewSet(
                        match: match,
                        setNumber: 1,
                        formation: state.formation,
                        startingPlayers: starting
                    )
                    return .run { send in
                        try await localStore.saveMatch(prepared)
                        await send(.matchPrepared(prepared))
                    }
                } catch {
                    state.errorMessage = "サービス順初期化失敗: \(error)"
                    return .none
                }

            case let .matchPrepared(match):
                state.setupResult = match
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none
            }
        }
    }

    private func makeMatch(
        state: State,
        recorderId: UUID,
        matchCode: String,
        codeExpiresAt: Date
    ) -> Match {
        let matchId = UUID()
        let members = state.startingLineup.map {
            MatchMember(matchId: matchId, playerId: $0.id, isStarter: true)
        } + state.benchPlayers.map {
            MatchMember(matchId: matchId, playerId: $0.id, isStarter: false)
        }
        return Match(
            id: matchId,
            teamId: state.team.id,
            recorderId: recorderId,
            matchCode: matchCode,
            matchCodeExpiresAt: codeExpiresAt,
            date: state.date,
            startTime: state.startTime,
            opponentTeamName: state.opponentTeamName,
            tournamentName: state.tournamentName.isEmpty ? nil : state.tournamentName,
            matchType: state.matchType,
            venue: state.venue.isEmpty ? nil : state.venue,
            members: members
        )
    }
}
