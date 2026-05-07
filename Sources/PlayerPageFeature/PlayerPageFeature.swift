// PlayerPageFeature — Phase 2.2 選手個人マイページ

import ComposableArchitecture
import DesignSystem
import Foundation
import Models
import StatsEngine
import SwiftUI

@Reducer
public struct PlayerPageFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var playerId: UUID
        public var allMatches: [Match]
        public var pageData: PlayerPageData?

        public init(playerId: UUID, matches: [Match]) {
            self.playerId = playerId
            self.allMatches = matches
        }
    }

    public enum Action: Equatable {
        case onAppear
        case dataLoaded(PlayerPageData)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let id = state.playerId
                let matches = state.allMatches
                return .run { send in
                    let page = StatsEngine().playerPage(playerId: id, in: matches)
                    await send(.dataLoaded(page))
                }
            case let .dataLoaded(page):
                state.pageData = page
                return .none
            }
        }
    }
}

public struct PlayerPageView: View {
    @Bindable public var store: StoreOf<PlayerPageFeature>

    public init(store: StoreOf<PlayerPageFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let p = store.pageData {
                    Text("選手 \(p.playerId.uuidString.prefix(8))…").font(.Lumi.headlineMedium)
                    careerCard(p.careerStats)
                    Text("直近試合").font(.Lumi.headlineSmall)
                    ForEach(p.recentMatches, id: \.matchId) { rec in
                        recentMatchRow(rec)
                    }
                } else {
                    Text("読込中…").foregroundStyle(Color.Lumi.textSecondary)
                }
            }
            .padding(16)
        }
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
        .task { store.send(.onAppear) }
    }

    @ViewBuilder
    private func careerCard(_ s: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("キャリア累計").font(.Lumi.headlineSmall)
            row("Atk 試行", "\(s.attackAttempts)")
            row("Atk 決定", "\(s.attackKills)")
            row("Sv 試行", "\(s.serveAttempts)")
            row("エース", "\(s.serveAces)")
            row("アシスト", "\(s.assists)")
            row("ブロック決定", "\(s.blockKills)")
            row("ディグ", "\(s.digs)")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.Lumi.surface))
    }

    @ViewBuilder
    private func recentMatchRow(_ rec: PlayerPageData.PlayerMatchRecord) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(rec.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.Lumi.caption).foregroundStyle(Color.Lumi.textSecondary)
                Text("vs \(rec.opponentName)").font(.Lumi.body)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Atk \(rec.stats.attackKills)/\(rec.stats.attackAttempts)").font(.Lumi.statSmall).monospacedDigit()
                Text("Ace \(rec.stats.serveAces) Asst \(rec.stats.assists)").font(.Lumi.caption).monospacedDigit()
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.Lumi.surfaceElevated))
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.Lumi.textSecondary)
            Spacer()
            Text(value).font(.Lumi.statMedium).monospacedDigit()
        }
    }
}
