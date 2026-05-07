// OpponentDatabaseFeature — Phase 2.1 対戦相手DB UI

import ComposableArchitecture
import DesignSystem
import Foundation
import LocalStore
import Models
import StatsEngine
import SwiftUI

@Reducer
public struct OpponentDatabaseFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var allMatches: [Match]
        public var opponents: [OpponentTeam] = []
        public var searchQuery: String = ""
        public var maskingEnabled: Bool = false
        public var selectedOpponent: OpponentTeam?
        public var tendency: OpponentDatabase.Tendency?

        public init(matches: [Match]) {
            self.allMatches = matches
        }

        public var filteredOpponents: [OpponentTeam] {
            if searchQuery.isEmpty { return opponents }
            return opponents.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case opponentsLoaded([OpponentTeam])
        case searchChanged(String)
        case toggleMasking(Bool)
        case opponentTapped(OpponentTeam)
        case tendencyLoaded(OpponentDatabase.Tendency)
        case dismissDetail
        case notesChanged(String)
        case maskedNameChanged(String)
        case persistEdits
    }

    @Dependency(\.localStore) var localStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let matches = state.allMatches
                return .run { send in
                    // 派生 (matches から自動生成) と 永続 (LocalStore に保存済の編集) をマージ
                    let derived = OpponentDatabase().opponents(from: matches)
                    let stored = (try? await localStore.fetchOpponentTeams()) ?? []
                    let merged = mergeOpponents(derived: derived, stored: stored)
                    await send(.opponentsLoaded(merged))
                }

            case let .opponentsLoaded(list):
                state.opponents = list
                return .none

            case let .searchChanged(q):
                state.searchQuery = q
                return .none

            case let .toggleMasking(b):
                state.maskingEnabled = b
                return .none

            case let .opponentTapped(opp):
                state.selectedOpponent = opp
                let matches = state.allMatches
                let name = opp.name
                return .run { send in
                    let t = OpponentDatabase().tendency(against: name, in: matches)
                    await send(.tendencyLoaded(t))
                }

            case let .tendencyLoaded(t):
                state.tendency = t
                return .none

            case .dismissDetail:
                state.selectedOpponent = nil
                state.tendency = nil
                return .none

            case let .notesChanged(notes):
                state.selectedOpponent?.notes = notes
                state.selectedOpponent?.updatedAt = Date()
                return .none

            case let .maskedNameChanged(name):
                state.selectedOpponent?.maskedName = name.isEmpty ? nil : name
                state.selectedOpponent?.updatedAt = Date()
                return .none

            case .persistEdits:
                guard let opp = state.selectedOpponent else { return .none }
                // ローカルリストにも反映
                if let idx = state.opponents.firstIndex(where: { $0.id == opp.id }) {
                    state.opponents[idx] = opp
                }
                return .run { _ in
                    try? await localStore.saveOpponentTeam(opp)
                }
            }
        }
    }
}

/// 派生 (matches → 自動生成) と 永続 (LocalStore) をマージ。
/// 名前が一致するエントリは永続側のメタデータ (notes / maskedName) を上書きで保持。
private func mergeOpponents(derived: [OpponentTeam], stored: [OpponentTeam]) -> [OpponentTeam] {
    var byName: [String: OpponentTeam] = [:]
    for d in derived { byName[d.name] = d }
    for s in stored {
        if var existing = byName[s.name] {
            existing.maskedName = s.maskedName
            existing.notes = s.notes
            byName[s.name] = existing
        } else {
            byName[s.name] = s
        }
    }
    return byName.values.sorted { $0.name < $1.name }
}

// MARK: - View

public struct OpponentDatabaseView: View {
    @Bindable public var store: StoreOf<OpponentDatabaseFeature>

    public init(store: StoreOf<OpponentDatabaseFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                List(store.filteredOpponents) { opp in
                    Button {
                        store.send(.opponentTapped(opp))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(opp.displayName(masked: store.maskingEnabled))
                                    .font(.Lumi.body)
                                    .foregroundStyle(Color.Lumi.textPrimary)
                                Text("対戦数: \(opp.encounteredMatchIds.count)")
                                    .font(.Lumi.caption)
                                    .foregroundStyle(Color.Lumi.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.Lumi.textTertiary)
                        }
                    }
                }
            }
            .navigationTitle("対戦相手 DB")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle("マスク", isOn: Binding(
                        get: { store.maskingEnabled },
                        set: { store.send(.toggleMasking($0)) }
                    ))
                    .toggleStyle(.switch)
                }
            }
            .task { store.send(.onAppear) }
            .sheet(isPresented: Binding(
                get: { store.selectedOpponent != nil },
                set: { if !$0 { store.send(.dismissDetail) } }
            )) {
                if let opp = store.selectedOpponent {
                    OpponentDetailView(
                        opponent: opp,
                        masked: store.maskingEnabled,
                        tendency: store.tendency,
                        onClose: { store.send(.dismissDetail) }
                    )
                }
            }
        }
        .background(Color.Lumi.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.Lumi.textTertiary)
            TextField("チーム名で検索", text: Binding(
                get: { store.searchQuery },
                set: { store.send(.searchChanged($0)) }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Detail (試合前ブリーフィング)

private struct OpponentDetailView: View {
    let opponent: OpponentTeam
    let masked: Bool
    let tendency: OpponentDatabase.Tendency?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(opponent.displayName(masked: masked))
                        .font(.Lumi.headlineLarge)

                    Text("過去対戦数: \(opponent.encounteredMatchIds.count)")
                        .font(.Lumi.body)
                        .foregroundStyle(Color.Lumi.textSecondary)

                    if let t = tendency {
                        Group {
                            sectionTitle("アタックコース傾向")
                            tendencyBars(items: AttackCourse.allCases.map {
                                ($0.rawValue.uppercased(), t.attackCourse[$0] ?? 0)
                            })

                            sectionTitle("サーブゾーン傾向")
                            tendencyBars(items: (1...9).map {
                                ("Z\($0)", t.serveCourse[$0] ?? 0)
                            })
                        }
                    } else {
                        Text("傾向を集計中…")
                            .foregroundStyle(Color.Lumi.textSecondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("ブリーフィング")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onClose)
                }
            }
        }
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
    }

    @ViewBuilder
    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.Lumi.headlineSmall).padding(.top, 8)
    }

    @ViewBuilder
    private func tendencyBars(items: [(String, Int)]) -> some View {
        let maxCount = max(1, items.map(\.1).max() ?? 1)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0).font(.Lumi.statSmall).frame(width: 40, alignment: .leading)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.Lumi.accent.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(item.1) / CGFloat(maxCount))
                    }
                    .frame(height: 14)
                    Text("\(item.1)").font(.Lumi.statSmall).monospacedDigit().frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.Lumi.surface))
    }
}
