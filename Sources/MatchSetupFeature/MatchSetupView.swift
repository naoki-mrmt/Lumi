// MatchSetupView — MatchSetupFeature の SwiftUI ビュー

import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

public struct MatchSetupView: View {
    @Bindable public var store: StoreOf<MatchSetupFeature>

    public init(store: StoreOf<MatchSetupFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                formationSection
                lineupSection
                copySection
            }
            .navigationTitle("試合作成")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("作成") {
                        store.send(.createMatchTapped(
                            recorderId: UUID(),
                            matchCode: generateMatchCode(),
                            codeExpiresAt: Date().addingTimeInterval(3600 * 24)
                        ))
                    }
                    .disabled(!canCreate)
                }
            }
            .task { store.send(.onAppear) }
            .alert("エラー", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            )) {
                Button("OK") {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    private var basicInfoSection: some View {
        Section(header: Text("基本情報")) {
            TextField("対戦相手名", text: Binding(
                get: { store.opponentTeamName },
                set: { store.send(.opponentNameChanged($0)) }
            ))
            TextField("大会名 (任意)", text: Binding(
                get: { store.tournamentName },
                set: { store.send(.tournamentNameChanged($0)) }
            ))
            TextField("会場 (任意)", text: Binding(
                get: { store.venue },
                set: { store.send(.venueChanged($0)) }
            ))
            Picker("試合タイプ", selection: Binding(
                get: { store.matchType },
                set: { store.send(.matchTypeChanged($0)) }
            )) {
                Text("公式戦").tag(MatchType.official)
                Text("練習試合").tag(MatchType.practice)
                Text("合宿").tag(MatchType.trainingCamp)
            }
            DatePicker("試合日", selection: Binding(
                get: { store.date },
                set: { store.send(.dateChanged($0)) }
            ), displayedComponents: .date)
            DatePicker("開始時刻", selection: Binding(
                get: { store.startTime },
                set: { store.send(.startTimeChanged($0)) }
            ), displayedComponents: .hourAndMinute)
        }
    }

    private var formationSection: some View {
        Section(header: Text("フォーメーション")) {
            Picker("フォーメーション", selection: Binding(
                get: { store.formation },
                set: { store.send(.formationChanged($0)) }
            )) {
                ForEach(Formation.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var lineupSection: some View {
        Section(header: Text("スタメン (\(store.startingLineup.count)/9)")) {
            if !store.startingLineup.isEmpty {
                List {
                    ForEach(Array(store.startingLineup.enumerated()), id: \.element.id) { idx, player in
                        HStack {
                            Text("\(idx + 1)").font(.Lumi.statMedium).frame(width: 32)
                            Text("#\(player.jerseyNumber)").font(.Lumi.statMedium).frame(width: 50)
                            Text(player.name)
                            Spacer()
                            Button {
                                store.send(.togglePlayerInLineup(player))
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.Lumi.poor)
                            }
                        }
                    }
                    .onMove { from, to in
                        guard let f = from.first else { return }
                        store.send(.moveLineupPlayer(fromOffset: f, toOffset: to))
                    }
                }
                .frame(minHeight: 280)
            }

            DisclosureGroup("選手から追加") {
                ForEach(store.availablePlayers) { player in
                    Button {
                        store.send(.togglePlayerInLineup(player))
                    } label: {
                        HStack {
                            Text("#\(player.jerseyNumber)").font(.Lumi.statMedium).frame(width: 50)
                            Text(player.name)
                            Spacer()
                            if store.startingLineup.contains(player) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.Lumi.excellent)
                            }
                        }
                    }
                }
            }
        }
    }

    private var copySection: some View {
        Section {
            Button {
                store.send(.copyFromLastMatchTapped)
            } label: {
                Label("前回スタメンをコピー", systemImage: "doc.on.doc")
            }
            .disabled(!store.lastMatchAvailable)
        }
    }

    private var canCreate: Bool {
        store.startingLineup.count == 9 && !store.opponentTeamName.isEmpty
    }

    private func generateMatchCode() -> String {
        // M4 で正式実装。ここでは一意のプレースホルダー。
        let chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
