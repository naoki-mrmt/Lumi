// TeamManagementFeature — チーム・選手15人マスタ管理

import ComposableArchitecture
import Foundation
import Models
import LocalStore

@Reducer
public struct TeamManagementFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var team: Team?
        public var players: [Player] = []
        public var isLoading: Bool = false
        public var errorMessage: String?
        public var editingPlayer: PlayerDraft?

        public init(team: Team? = nil) {
            self.team = team
        }

        /// 選手追加・編集の下書き
        public struct PlayerDraft: Equatable, Identifiable {
            public var id: UUID
            public var jerseyNumber: Int
            public var name: String
            public var positionTendency: PositionTendency?
            public var isActive: Bool
            public var existing: Player?

            public init(
                id: UUID = UUID(),
                jerseyNumber: Int = 0,
                name: String = "",
                positionTendency: PositionTendency? = nil,
                isActive: Bool = true,
                existing: Player? = nil
            ) {
                self.id = id
                self.jerseyNumber = jerseyNumber
                self.name = name
                self.positionTendency = positionTendency
                self.isActive = isActive
                self.existing = existing
            }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case playersLoaded([Player])
        case loadFailed(String)
        case addPlayerTapped
        case editPlayerTapped(Player)
        case draftChanged(State.PlayerDraft)
        case draftSaveTapped
        case draftCancelled
        case playerSaved(Player)
        case saveFailed(String)
        case deletePlayerRequested(UUID)
        case playerDeleted(UUID)
    }

    @Dependency(\.localStore) var localStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let teamId = state.team?.id else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let players = try await localStore.fetchPlayers(teamId)
                        await send(.playersLoaded(players))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .playersLoaded(players):
                state.isLoading = false
                state.players = players
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .addPlayerTapped:
                state.editingPlayer = State.PlayerDraft()
                return .none

            case let .editPlayerTapped(player):
                state.editingPlayer = State.PlayerDraft(
                    id: player.id,
                    jerseyNumber: player.jerseyNumber,
                    name: player.name,
                    positionTendency: player.positionTendency,
                    isActive: player.isActive,
                    existing: player
                )
                return .none

            case let .draftChanged(draft):
                state.editingPlayer = draft
                return .none

            case .draftCancelled:
                state.editingPlayer = nil
                return .none

            case .draftSaveTapped:
                guard let draft = state.editingPlayer,
                      let team = state.team else { return .none }
                let player: Player
                if var existing = draft.existing {
                    existing.jerseyNumber = draft.jerseyNumber
                    existing.name = draft.name
                    existing.positionTendency = draft.positionTendency
                    existing.isActive = draft.isActive
                    player = existing
                } else {
                    player = Player(
                        id: draft.id,
                        teamId: team.id,
                        jerseyNumber: draft.jerseyNumber,
                        name: draft.name,
                        positionTendency: draft.positionTendency,
                        isActive: draft.isActive
                    )
                }
                return .run { send in
                    do {
                        try await localStore.savePlayer(player)
                        await send(.playerSaved(player))
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case let .playerSaved(player):
                state.editingPlayer = nil
                if let idx = state.players.firstIndex(where: { $0.id == player.id }) {
                    state.players[idx] = player
                } else {
                    state.players.append(player)
                }
                state.players.sort { $0.jerseyNumber < $1.jerseyNumber }
                return .none

            case let .saveFailed(message):
                state.errorMessage = message
                return .none

            case let .deletePlayerRequested(playerId):
                return .run { send in
                    try await localStore.deletePlayer(playerId)
                    await send(.playerDeleted(playerId))
                }

            case let .playerDeleted(playerId):
                state.players.removeAll { $0.id == playerId }
                return .none
            }
        }
    }
}
