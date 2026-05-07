// TeamSwitcherFeature — Phase 2.4 複数チーム管理

import ComposableArchitecture
import DesignSystem
import Foundation
import LocalStore
import Models
import SwiftUI

@Reducer
public struct TeamSwitcherFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var profile: UserProfile?
        public var teams: [Team] = []
        public var draftTeamName: String = ""
        public var errorMessage: String?

        public init(profile: UserProfile? = nil) {
            self.profile = profile
        }
    }

    public enum Action: Equatable {
        case onAppear
        case teamsLoaded([Team])
        case loadFailed(String)
        case selectPrimary(UUID)
        case draftNameChanged(String)
        case createTeamTapped
        case teamCreated(Team)
        case errorDismissed
    }

    @Dependency(\.localStore) var localStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    do {
                        let teams = try await localStore.fetchTeams()
                        await send(.teamsLoaded(teams))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .teamsLoaded(teams):
                state.teams = teams
                return .none

            case let .loadFailed(msg):
                state.errorMessage = msg
                return .none

            case let .selectPrimary(id):
                state.profile?.primaryTeamId = id
                return .none

            case let .draftNameChanged(n):
                state.draftTeamName = n
                return .none

            case .createTeamTapped:
                let name = state.draftTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let ownerId = state.profile?.id else { return .none }
                let team = Team(ownerId: ownerId, name: name)
                state.draftTeamName = ""
                return .run { send in
                    try? await localStore.saveTeam(team)
                    await send(.teamCreated(team))
                }

            case let .teamCreated(team):
                state.teams.append(team)
                if state.profile?.primaryTeamId == nil {
                    state.profile?.primaryTeamId = team.id
                }
                state.profile?.teamIds.append(team.id)
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

public struct TeamSwitcherView: View {
    @Bindable public var store: StoreOf<TeamSwitcherFeature>

    public init(store: StoreOf<TeamSwitcherFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section(header: Text("所属チーム")) {
                ForEach(store.teams) { team in
                    HStack {
                        if store.profile?.primaryTeamId == team.id {
                            Image(systemName: "star.fill").foregroundStyle(Color.Lumi.average)
                        }
                        Text(team.name)
                        Spacer()
                        Button("メイン") {
                            store.send(.selectPrimary(team.id))
                        }
                        .disabled(store.profile?.primaryTeamId == team.id)
                    }
                }
            }
            Section(header: Text("新規チーム作成")) {
                TextField("チーム名", text: Binding(
                    get: { store.draftTeamName },
                    set: { store.send(.draftNameChanged($0)) }
                ))
                Button("作成") { store.send(.createTeamTapped) }
                    .disabled(store.draftTeamName.isEmpty)
            }
        }
        .task { store.send(.onAppear) }
    }
}
