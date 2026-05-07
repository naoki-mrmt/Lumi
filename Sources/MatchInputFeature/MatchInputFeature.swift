// MatchInputFeature — 試合中の入力UIの State / Reducer
//
// 機能 (M2-T3〜T17):
// - 3モード切替 (quick/standard/detailed)
// - 自/相手切替
// - 選手選択 / 相手背番号入力
// - プレー種別 / 評価4段階
// - コートタップ (CourtZone)
// - ラリータイムライン (現在ラリー)
// - アンドゥ最大5ステップ
// - タイムアウト / 選手交代

import ComposableArchitecture
import Foundation
import Models
import LocalStore
import RallyTimeline
import ServiceOrderEngine
import Sync
import Telemetry

public enum InputMode: String, Codable, CaseIterable, Sendable {
    case quick, standard, detailed
}

@Reducer
public struct MatchInputFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var match: Match
        public var currentSetId: UUID
        public var inputMode: InputMode = .standard

        // 入力ドラフト
        public var draftSelectedTeam: Team.ServingSide = .own
        public var draftSelectedPlayerId: UUID?
        public var draftOpponentJersey: Int?
        public var draftPlayType: PlayType?
        public var draftCourtZone: CourtZone?
        public var draftServeType: ServeType?
        public var draftServeCourse: Int?     // 1..9 (詳細モード)
        public var draftReceptionQuality: ReceptionQuality?
        public var draftAttackCourse: AttackCourse?

        // UI状態
        public var presentingTimeoutSheet: Bool = false
        public var presentingSubstitutionSheet: Bool = false
        public var errorMessage: String?

        // アンドゥ履歴 (最大5件)
        var stateHistory: [Snapshot] = []

        public init(match: Match, currentSetId: UUID) {
            self.match = match
            self.currentSetId = currentSetId
        }

        public var currentSet: MatchSet? {
            match.sets.first { $0.id == currentSetId }
        }

        public var currentRally: Rally? {
            currentSet?.rallies.last { $0.endedAt == nil }
        }

        public var ourScore: Int {
            currentSet?.rallies.filter { $0.winner == .own }.count ?? 0
        }

        public var opponentScore: Int {
            currentSet?.rallies.filter { $0.winner == .opponent }.count ?? 0
        }

        public var ownTimeoutsUsed: Int {
            currentSet?.timeouts.filter { $0.requestingTeam == .own }.count ?? 0
        }

        public var opponentTimeoutsUsed: Int {
            currentSet?.timeouts.filter { $0.requestingTeam == .opponent }.count ?? 0
        }

        struct Snapshot: Equatable, Sendable {
            let match: Match
        }
    }

    public enum Action: Equatable {
        case onAppear
        case startSnapshotting
        case snapshotRequested
        case stopSnapshotting
        case modeChanged(InputMode)
        case teamSwitched(Team.ServingSide)
        case playerSelected(UUID?)
        case opponentJerseyChanged(Int?)
        case playTypeSelected(PlayType?)
        case courtZoneTapped(CourtZone)
        case serveTypeSelected(ServeType?)
        case serveCourseSelected(Int?)
        case receptionQualitySelected(ReceptionQuality?)
        case attackCourseSelected(AttackCourse?)
        case evaluationSelected(Evaluation)
        case rallyEndTapped(winner: Team.ServingSide)
        case undoTapped
        case timeoutRequested(Team.ServingSide)
        case substitutionRequested([SubPair])
        case presentTimeoutSheet(Bool)
        case presentSubstitutionSheet(Bool)
        case errorDismissed
        case persistMatch  // localStore に保存 (副作用)

        public struct SubPair: Equatable, Sendable {
            public let playerOut: UUID
            public let playerIn: UUID
            public init(playerOut: UUID, playerIn: UUID) {
                self.playerOut = playerOut
                self.playerIn = playerIn
            }
        }
    }

    @Dependency(\.localStore) var localStore
    @Dependency(\.syncEngine) var syncEngine
    @Dependency(\.continuousClock) var clock

    public init() {}

    private enum CancelID: Hashable, Sendable {
        case snapshot
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.startSnapshotting)

            case .startSnapshotting:
                return .run { send in
                    for await _ in self.clock.timer(interval: .seconds(10)) {
                        await send(.snapshotRequested)
                    }
                }
                .cancellable(id: CancelID.snapshot)

            case .snapshotRequested:
                // 試合状態を inProgress に保証 + persistMatch
                if state.match.status == .preparing {
                    state.match.status = .inProgress
                }
                let match = state.match
                return .run { _ in
                    try? await localStore.saveMatch(match)
                }

            case .stopSnapshotting:
                return .cancel(id: CancelID.snapshot)

            case let .modeChanged(mode):
                state.inputMode = mode
                return .none

            case let .teamSwitched(team):
                state.draftSelectedTeam = team
                state.draftSelectedPlayerId = nil
                state.draftOpponentJersey = nil
                return .none

            case let .playerSelected(id):
                state.draftSelectedPlayerId = id
                return .none

            case let .opponentJerseyChanged(j):
                state.draftOpponentJersey = j
                return .none

            case let .playTypeSelected(type):
                state.draftPlayType = type
                return .none

            case let .courtZoneTapped(zone):
                state.draftCourtZone = zone
                return .none

            case let .serveTypeSelected(t):
                state.draftServeType = t
                return .none

            case let .serveCourseSelected(c):
                state.draftServeCourse = c
                return .none

            case let .receptionQualitySelected(q):
                state.draftReceptionQuality = q
                return .none

            case let .attackCourseSelected(c):
                state.draftAttackCourse = c
                return .none

            case let .evaluationSelected(eval):
                Telemetry.breadcrumb(category: .input, message: "Play recorded", data: [
                    "team": state.draftSelectedTeam.rawValue,
                    "playType": state.draftPlayType?.rawValue ?? "nil",
                    "evaluation": eval.rawValue
                ])
                let effect = commitPlay(&state, evaluation: eval)
                // 直前に追加された Play があればクラウドに push
                if let lastPlay = lastAppendedPlay(state) {
                    let engine = syncEngine
                    return .merge(effect, .run { _ in
                        try? await engine.push(play: lastPlay)
                    })
                }
                return effect

            case let .rallyEndTapped(winner):
                Telemetry.breadcrumb(category: .match, message: "Rally ended", data: [
                    "winner": winner.rawValue
                ])
                let effect = endRally(&state, winner: winner)
                if let endedRally = lastEndedRally(state) {
                    let engine = syncEngine
                    return .merge(effect, .run { _ in
                        try? await engine.push(rally: endedRally)
                    })
                }
                return effect

            case .undoTapped:
                return undo(&state)

            case let .timeoutRequested(team):
                let effect = requestTimeout(&state, team: team)
                if let lastTimeout = lastAppendedTimeout(state) {
                    let engine = syncEngine
                    return .merge(effect, .run { _ in
                        try? await engine.push(timeout: lastTimeout)
                    })
                }
                return effect

            case let .substitutionRequested(subs):
                let effect = requestSubstitution(&state, subs: subs)
                let newSubs = lastAppendedSubstitutions(state, count: subs.count)
                if !newSubs.isEmpty {
                    let engine = syncEngine
                    return .merge(effect, .run { _ in
                        for s in newSubs {
                            try? await engine.push(substitution: s)
                        }
                    })
                }
                return effect

            case let .presentTimeoutSheet(b):
                state.presentingTimeoutSheet = b
                return .none

            case let .presentSubstitutionSheet(b):
                state.presentingSubstitutionSheet = b
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .persistMatch:
                let m = state.match
                return .run { _ in
                    try await localStore.saveMatch(m)
                }
            }
        }
    }

    // MARK: - Play 確定

    private func commitPlay(_ state: inout State, evaluation: Evaluation) -> Effect<Action> {
        // バリデーション
        guard let playType = state.draftPlayType else {
            state.errorMessage = "プレー種別を選択してください"
            return .none
        }
        if state.draftSelectedTeam == .own && state.draftSelectedPlayerId == nil {
            state.errorMessage = "自軍プレーは選手を選択してください"
            return .none
        }
        if state.draftSelectedTeam == .opponent && state.draftOpponentJersey == nil {
            state.errorMessage = "相手プレーは背番号を入力してください"
            return .none
        }

        pushSnapshot(&state)

        // 現在ラリーがなければ新規作成
        let rally = ensureCurrentRally(&state)

        let play = Play(
            rallyId: rally.id,
            sequenceInRally: rally.plays.count + 1,
            playTeam: state.draftSelectedTeam,
            playerId: state.draftSelectedTeam == .own ? state.draftSelectedPlayerId : nil,
            opponentJersey: state.draftSelectedTeam == .opponent ? state.draftOpponentJersey : nil,
            playType: playType,
            evaluation: evaluation,
            serveType: state.inputMode != .quick ? state.draftServeType : nil,
            receptionQuality: state.inputMode != .quick ? state.draftReceptionQuality : nil,
            attackCourse: state.inputMode == .detailed ? state.draftAttackCourse : nil,
            serveCourse: state.inputMode == .detailed ? state.draftServeCourse : nil,
            courtZone: state.inputMode == .detailed ? state.draftCourtZone : nil
        )

        // RallyTimeline で append
        let timeline = RallyTimeline()
        if let setIdx = state.match.sets.firstIndex(where: { $0.id == state.currentSetId }),
           let rallyIdx = state.match.sets[setIdx].rallies.firstIndex(where: { $0.id == rally.id }) {
            let updatedRally = timeline.append(play, to: state.match.sets[setIdx].rallies[rallyIdx])
            state.match.sets[setIdx].rallies[rallyIdx] = updatedRally
        }

        // ドラフトリセット
        state.draftPlayType = nil
        state.draftServeType = nil
        state.draftServeCourse = nil
        state.draftReceptionQuality = nil
        state.draftAttackCourse = nil
        state.draftCourtZone = nil

        return .none
    }

    private func ensureCurrentRally(_ state: inout State) -> Rally {
        if let r = state.currentRally { return r }
        // 新規ラリー作成
        let setIdx = state.match.sets.firstIndex { $0.id == state.currentSetId }!
        let prevRallies = state.match.sets[setIdx].rallies
        let rallyNumber = prevRallies.count + 1
        let engine = ServiceOrderEngine()
        let server = engine.currentServer(in: state.match, set: state.match.sets[setIdx])

        let rally = Rally(
            setId: state.currentSetId,
            rallyNumber: rallyNumber,
            startScoreUs: state.ourScore,
            startScoreOpp: state.opponentScore,
            servingTeam: state.match.sets[setIdx].lastServingTeam ?? .own,
            servingPlayerId: server?.currentPlayerId
        )
        state.match.sets[setIdx].rallies.append(rally)
        return rally
    }

    private func endRally(_ state: inout State, winner: Team.ServingSide) -> Effect<Action> {
        guard let setIdx = state.match.sets.firstIndex(where: { $0.id == state.currentSetId }),
              let rallyIdx = state.match.sets[setIdx].rallies.lastIndex(where: { $0.endedAt == nil }) else {
            state.errorMessage = "終了するラリーがありません"
            return .none
        }

        pushSnapshot(&state)

        let timeline = RallyTimeline()
        let engine = ServiceOrderEngine()
        var rally = state.match.sets[setIdx].rallies[rallyIdx]
        rally = timeline.endRally(rally, winner: winner, endedAt: Date())
        state.match.sets[setIdx].rallies[rallyIdx] = rally

        // ServiceOrder の advance
        let updatedSet = engine.advance(after: rally, in: state.match, set: state.match.sets[setIdx])
        state.match.sets[setIdx] = MatchSet(
            id: state.match.sets[setIdx].id,
            matchId: updatedSet.matchId,
            setNumber: updatedSet.setNumber,
            formation: updatedSet.formation,
            customFormation: updatedSet.customFormation,
            ourScoreFinal: updatedSet.ourScoreFinal,
            opponentScoreFinal: updatedSet.opponentScoreFinal,
            startedAt: updatedSet.startedAt,
            endedAt: updatedSet.endedAt,
            substitutions: updatedSet.substitutions,
            rallies: state.match.sets[setIdx].rallies,
            timeouts: updatedSet.timeouts,
            lastOwnServingOrder: updatedSet.lastOwnServingOrder,
            lastServingTeam: updatedSet.lastServingTeam
        )

        return .none
    }

    // MARK: - アンドゥ

    private static let maxHistory = 5

    private func pushSnapshot(_ state: inout State) {
        state.stateHistory.append(.init(match: state.match))
        if state.stateHistory.count > Self.maxHistory {
            state.stateHistory.removeFirst()
        }
    }

    private func undo(_ state: inout State) -> Effect<Action> {
        guard let snapshot = state.stateHistory.popLast() else { return .none }
        state.match = snapshot.match
        return .none
    }

    // MARK: - タイムアウト

    private func requestTimeout(_ state: inout State, team: Team.ServingSide) -> Effect<Action> {
        guard let setIdx = state.match.sets.firstIndex(where: { $0.id == state.currentSetId }) else {
            return .none
        }
        let usedCount = state.match.sets[setIdx].timeouts.filter { $0.requestingTeam == team }.count
        guard usedCount < MatchSet.maxTimeoutsPerTeamPerSet else {
            state.errorMessage = "\(team == .own ? "自軍" : "相手") のタイムアウトは1セット2回までです"
            return .none
        }

        pushSnapshot(&state)

        let to = Timeout(
            setId: state.currentSetId,
            ourScore: state.ourScore,
            opponentScore: state.opponentScore,
            requestingTeam: team
        )
        state.match.sets[setIdx].timeouts.append(to)
        return .none
    }

    // MARK: - Live 同期 用ヘルパ

    /// commitPlay 直後に呼ぶ。直前のラリーに追加された最新 Play を返す。
    private func lastAppendedPlay(_ state: State) -> Play? {
        guard let set = state.match.sets.first(where: { $0.id == state.currentSetId }),
              let rally = set.rallies.last(where: { $0.endedAt == nil }) ?? set.rallies.last
        else { return nil }
        return rally.plays.last
    }

    /// endRally 直後に呼ぶ。直近で endedAt がついたラリーを返す。
    private func lastEndedRally(_ state: State) -> Rally? {
        guard let set = state.match.sets.first(where: { $0.id == state.currentSetId }) else { return nil }
        return set.rallies.last(where: { $0.endedAt != nil })
    }

    /// timeoutRequested 直後に呼ぶ。最後に追加された Timeout を返す。
    private func lastAppendedTimeout(_ state: State) -> Timeout? {
        state.match.sets.first(where: { $0.id == state.currentSetId })?.timeouts.last
    }

    /// substitutionRequested 直後に呼ぶ。直近 N 件の Substitution を返す。
    private func lastAppendedSubstitutions(_ state: State, count: Int) -> [Substitution] {
        guard let set = state.match.sets.first(where: { $0.id == state.currentSetId }) else { return [] }
        return Array(set.substitutions.suffix(count))
    }

    // MARK: - 選手交代

    private func requestSubstitution(_ state: inout State, subs: [Action.SubPair]) -> Effect<Action> {
        let engine = ServiceOrderEngine()
        let pairs = subs.map { (playerOut: $0.playerOut, playerIn: $0.playerIn) }
        do {
            pushSnapshot(&state)
            state.match = try engine.substitute(
                in: state.match,
                setId: state.currentSetId,
                substitutions: pairs,
                atOurScore: state.ourScore,
                atOpponentScore: state.opponentScore,
                timestamp: Date()
            )
        } catch ServiceOrderError.substitutionLimitExceeded {
            _ = state.stateHistory.popLast()
            state.errorMessage = "1セット最大4回までです"
        } catch ServiceOrderError.tooManyPlayersAtOnce {
            _ = state.stateHistory.popLast()
            state.errorMessage = "1回最大3人までです"
        } catch ServiceOrderError.alreadyResubstituted {
            _ = state.stateHistory.popLast()
            state.errorMessage = "再交代は1回までです"
        } catch ServiceOrderError.playerNotInOrder {
            _ = state.stateHistory.popLast()
            state.errorMessage = "対象選手が見つかりません"
        } catch {
            _ = state.stateHistory.popLast()
            state.errorMessage = "選手交代失敗: \(error)"
        }
        return .none
    }
}
