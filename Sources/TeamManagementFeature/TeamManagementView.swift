// TeamManagementView — TeamManagementFeature の SwiftUI ビュー

import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

public struct TeamManagementView: View {
    @Bindable public var store: StoreOf<TeamManagementFeature>

    public init(store: StoreOf<TeamManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("選手 (\(store.players.count) / \(Team.maxPlayers))")) {
                    ForEach(store.players) { player in
                        Button {
                            store.send(.editPlayerTapped(player))
                        } label: {
                            HStack {
                                Text("\(player.jerseyNumber)")
                                    .font(.Lumi.statMedium)
                                    .frame(width: 40, alignment: .leading)
                                Text(player.name)
                                    .font(.Lumi.body)
                                Spacer()
                                if !player.isActive {
                                    Text("非在籍")
                                        .font(.Lumi.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            store.send(.deletePlayerRequested(store.players[idx].id))
                        }
                    }
                }
            }
            .navigationTitle(store.team?.name ?? "チーム")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addPlayerTapped)
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                    .disabled(store.players.count >= Team.maxPlayers)
                }
            }
            .task { store.send(.onAppear) }
            .sheet(
                isPresented: Binding(
                    get: { store.editingPlayer != nil },
                    set: { if !$0 { store.send(.draftCancelled) } }
                )
            ) {
                if let _ = store.editingPlayer {
                    PlayerDraftSheet(store: store)
                }
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.send(.loadFailed("")) } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}

private struct PlayerDraftSheet: View {
    @Bindable var store: StoreOf<TeamManagementFeature>

    var body: some View {
        NavigationStack {
            Form {
                if let draft = store.editingPlayer {
                    Section(header: Text("基本情報")) {
                        TextField("背番号", value: Binding(
                            get: { draft.jerseyNumber },
                            set: { newValue in
                                var d = draft
                                d.jerseyNumber = newValue
                                store.send(.draftChanged(d))
                            }
                        ), format: .number)
                        TextField("名前", text: Binding(
                            get: { draft.name },
                            set: { newValue in
                                var d = draft
                                d.name = newValue
                                store.send(.draftChanged(d))
                            }
                        ))
                    }
                    Section(header: Text("ポジション傾向 (任意)")) {
                        Picker("傾向", selection: Binding(
                            get: { draft.positionTendency },
                            set: { newValue in
                                var d = draft
                                d.positionTendency = newValue
                                store.send(.draftChanged(d))
                            }
                        )) {
                            Text("未設定").tag(PositionTendency?.none)
                            ForEach(PositionTendency.allCases, id: \.self) { tendency in
                                Text(tendency.rawValue.uppercased()).tag(PositionTendency?.some(tendency))
                            }
                        }
                    }
                    Section {
                        Toggle("在籍中", isOn: Binding(
                            get: { draft.isActive },
                            set: { newValue in
                                var d = draft
                                d.isActive = newValue
                                store.send(.draftChanged(d))
                            }
                        ))
                    }
                }
            }
            .navigationTitle(store.editingPlayer?.existing == nil ? "選手追加" : "選手編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { store.send(.draftCancelled) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { store.send(.draftSaveTapped) }
                        .disabled((store.editingPlayer?.name ?? "").isEmpty)
                }
            }
        }
    }
}
