// MatchInputView — 試合入力画面 (iPad 横画面前提)

import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

public struct MatchInputView: View {
    @Bindable public var store: StoreOf<MatchInputFeature>

    public init(store: StoreOf<MatchInputFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    teamSwitch
                    playerSelector
                }
                .frame(width: 280)

                courtView
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().padding(.vertical, 8)

            bottomControls
        }
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
        .alert("エラー", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("OK") {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { store.presentingTimeoutSheet },
            set: { store.send(.presentTimeoutSheet($0)) }
        )) {
            TimeoutSheet(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.presentingSubstitutionSheet },
            set: { store.send(.presentSubstitutionSheet($0)) }
        )) {
            SubstitutionSheet(store: store)
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 12) {
            scoreView
            Spacer()
            Button("TO") {
                store.send(.presentTimeoutSheet(true))
            }
            .buttonStyle(.bordered)
            .tint(Color.Lumi.average)

            Button("選手交代") {
                store.send(.presentSubstitutionSheet(true))
            }
            .buttonStyle(.bordered)

            Picker("モード", selection: Binding(
                get: { store.inputMode },
                set: { store.send(.modeChanged($0)) }
            )) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Text(modeLabel(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.Lumi.surface)
    }

    private func modeLabel(_ mode: InputMode) -> String {
        switch mode {
        case .quick: "クイック"
        case .standard: "標準"
        case .detailed: "詳細"
        }
    }

    @ViewBuilder
    private var scoreView: some View {
        HStack(spacing: 16) {
            Text("Set \(store.currentSet?.setNumber ?? 1)")
                .font(.Lumi.headlineSmall)
                .foregroundStyle(Color.Lumi.textSecondary)

            Text("\(store.ourScore)")
                .font(.Lumi.scoreSmall)
                .monospacedDigit()
                .foregroundStyle(Color.Lumi.textPrimary)

            Text("-")
                .foregroundStyle(Color.Lumi.textTertiary)

            Text("\(store.opponentScore)")
                .font(.Lumi.scoreSmall)
                .monospacedDigit()
                .foregroundStyle(Color.Lumi.textSecondary)
        }
    }

    // MARK: - Team / Player

    @ViewBuilder
    private var teamSwitch: some View {
        Picker("Team", selection: Binding(
            get: { store.draftSelectedTeam },
            set: { store.send(.teamSwitched($0)) }
        )) {
            Text("自軍").tag(Team.ServingSide.own)
            Text("相手").tag(Team.ServingSide.opponent)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var playerSelector: some View {
        if store.draftSelectedTeam == .own {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(rosterPlayers, id: \.self) { id in
                        Button {
                            store.send(.playerSelected(id))
                        } label: {
                            VStack {
                                Text("#\(jerseyNumber(for: id))")
                                    .font(.Lumi.statMedium)
                            }
                            .frame(width: 76, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(store.draftSelectedPlayerId == id
                                          ? Color.Lumi.accent.opacity(0.7)
                                          : Color.Lumi.surfaceElevated)
                            )
                        }
                        .foregroundStyle(Color.Lumi.textPrimary)
                    }
                }
                .padding(.horizontal, 4)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("相手背番号")
                    .font(.Lumi.caption)
                    .foregroundStyle(Color.Lumi.textSecondary)
                let jerseyField = TextField("背番号", value: Binding(
                    get: { store.draftOpponentJersey },
                    set: { store.send(.opponentJerseyChanged($0)) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                jerseyField.keyboardType(.numberPad)
                #else
                jerseyField
                #endif
            }
        }
    }

    // 自軍ロスター: ServiceOrderEntry の現在 player を 1..9 順で
    private var rosterPlayers: [UUID] {
        store.match.serviceOrders
            .sorted(by: { $0.order < $1.order })
            .map(\.currentPlayerId)
    }

    private func jerseyNumber(for playerId: UUID) -> Int {
        // 試合作成時に Player.id ベースで構築されているので、Player のロスターを引き渡されない場合は
        // 順序番号を返す (実利用時はチーム選手と突合する想定)
        if let order = store.match.serviceOrders.first(where: { $0.currentPlayerId == playerId })?.order {
            return order
        }
        return 0
    }

    // MARK: - Court

    @ViewBuilder
    private var courtView: some View {
        VStack(spacing: 4) {
            Text("相手陣")
                .font(.Lumi.caption).foregroundStyle(Color.Lumi.textTertiary)
            CourtGrid(side: .opponent, selected: store.draftCourtZone) { zone in
                store.send(.courtZoneTapped(zone))
            }
            Rectangle().fill(Color.Lumi.accent).frame(height: 3)
            Text("自陣")
                .font(.Lumi.caption).foregroundStyle(Color.Lumi.textTertiary)
            CourtGrid(side: .own, selected: store.draftCourtZone) { zone in
                store.send(.courtZoneTapped(zone))
            }
        }
        .padding(8)
        .background(Color.Lumi.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 12) {
            playTypeRow
            if store.inputMode != .quick {
                modeRefinementsRow
            }
            evaluationRow
            timelineView
            actionRow
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // 詳細・標準モード時の補助項目 (ServeType/ReceptionQuality/AttackCourse)
    @ViewBuilder
    private var modeRefinementsRow: some View {
        HStack(spacing: 8) {
            if store.draftPlayType == .serve {
                Picker("Serve", selection: Binding(
                    get: { store.draftServeType },
                    set: { store.send(.serveTypeSelected($0)) }
                )) {
                    Text("種別").tag(ServeType?.none)
                    Text("Float").tag(ServeType?.some(.float))
                    Text("Jump").tag(ServeType?.some(.jump))
                    Text("JF").tag(ServeType?.some(.jumpFloat))
                }
                .pickerStyle(.segmented)
                if store.inputMode == .detailed {
                    Picker("Zone", selection: Binding(
                        get: { store.draftServeCourse },
                        set: { store.send(.serveCourseSelected($0)) }
                    )) {
                        Text("コース").tag(Int?.none)
                        ForEach(1...9, id: \.self) { z in
                            Text("\(z)").tag(Int?.some(z))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            if store.draftPlayType == .reception {
                Picker("Pass", selection: Binding(
                    get: { store.draftReceptionQuality },
                    set: { store.send(.receptionQualitySelected($0)) }
                )) {
                    Text("質").tag(ReceptionQuality?.none)
                    Text("A").tag(ReceptionQuality?.some(.aPass))
                    Text("B").tag(ReceptionQuality?.some(.bPass))
                    Text("C").tag(ReceptionQuality?.some(.cPass))
                    Text("D").tag(ReceptionQuality?.some(.dPass))
                }
                .pickerStyle(.segmented)
            }
            if store.draftPlayType == .attack && store.inputMode == .detailed {
                Picker("Course", selection: Binding(
                    get: { store.draftAttackCourse },
                    set: { store.send(.attackCourseSelected($0)) }
                )) {
                    Text("コース").tag(AttackCourse?.none)
                    Text("Cross").tag(AttackCourse?.some(.cross))
                    Text("Straight").tag(AttackCourse?.some(.straight))
                    Text("Inner").tag(AttackCourse?.some(.inner))
                    Text("Feint").tag(AttackCourse?.some(.feint))
                }
                .pickerStyle(.segmented)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var playTypeRow: some View {
        HStack(spacing: 6) {
            ForEach(PlayType.allCases, id: \.self) { type in
                Button {
                    store.send(.playTypeSelected(type))
                } label: {
                    Text(playTypeLabel(type))
                        .font(.Lumi.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(store.draftPlayType == type ? Color.Lumi.accent : Color.Lumi.surfaceElevated)
                        )
                        .foregroundStyle(Color.Lumi.textPrimary)
                }
            }
        }
    }

    private func playTypeLabel(_ t: PlayType) -> String {
        switch t {
        case .serve: "サーブ"
        case .reception: "レセプ"
        case .set: "セット"
        case .attack: "アタック"
        case .block: "ブロック"
        case .dig: "ディグ"
        case .error: "ミス"
        }
    }

    @ViewBuilder
    private var evaluationRow: some View {
        HStack(spacing: 8) {
            ForEach(Evaluation.allCases, id: \.self) { eval in
                EvaluationButton(evaluation: eval) {
                    store.send(.evaluationSelected(eval))
                }
            }
        }
    }

    @ViewBuilder
    private var timelineView: some View {
        if let rally = store.currentRally, !rally.plays.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rally.plays) { play in
                        PlayCard(play: play)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 70)
        } else {
            Text("プレーを追加してください")
                .font(.Lumi.caption)
                .foregroundStyle(Color.Lumi.textTertiary)
                .frame(maxHeight: 70)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                store.send(.undoTapped)
            } label: {
                Label("アンドゥ", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                store.send(.rallyEndTapped(winner: .opponent))
            } label: {
                Label("相手得点", systemImage: "minus.circle")
            }
            .buttonStyle(.bordered)
            .tint(Color.Lumi.poor)

            Button {
                store.send(.rallyEndTapped(winner: .own))
            } label: {
                Label("自軍得点", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Lumi.excellent)
        }
    }
}

// MARK: - Court Grid

private struct CourtGrid: View {
    let side: CourtZone.Side
    let selected: CourtZone?
    let onTap: (CourtZone) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { col in
                        let zone = CourtZone(row: row, col: col, side: side)
                        let isSelected = selected == zone
                        Rectangle()
                            .fill(isSelected ? Color.Lumi.accent.opacity(0.6) : Color.Lumi.surfaceElevated)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(
                                Text(zoneLabel(row: row, col: col))
                                    .font(.Lumi.caption)
                                    .foregroundStyle(Color.Lumi.textTertiary)
                            )
                            .onTapGesture {
                                onTap(zone)
                            }
                    }
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
    }

    private func zoneLabel(row: Int, col: Int) -> String {
        let rows = ["F", "H", "B"]
        let cols = ["L", "C", "R"]
        return rows[row] + cols[col]
    }
}

// MARK: - Evaluation Button (Haptic)

private struct EvaluationButton: View {
    let evaluation: Evaluation
    let action: () -> Void
    @State private var trigger: Bool = false

    var body: some View {
        Button {
            trigger.toggle()
            action()
        } label: {
            VStack(spacing: 2) {
                Text(evaluation.symbol).font(.system(size: 24, weight: .bold))
                Text(evaluation.label).font(.Lumi.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(evaluation.color.opacity(0.85))
            )
            .foregroundStyle(.white)
        }
        .sensoryFeedback(evaluation.sensoryFeedback, trigger: trigger)
    }
}

// MARK: - Play Card

private struct PlayCard: View {
    let play: Play

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(play.sequenceInRally).")
                    .font(.Lumi.caption)
                    .foregroundStyle(Color.Lumi.textTertiary)
                Text(play.playTeam == .own ? "自" : "相")
                    .font(.Lumi.caption)
                Text(playTypeShort(play.playType))
                    .font(.Lumi.caption)
                Text(play.evaluation.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(play.evaluation.color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.Lumi.surfaceElevated)
        )
    }

    private func playTypeShort(_ t: PlayType) -> String {
        switch t {
        case .serve: "Sv"
        case .reception: "Rc"
        case .set: "St"
        case .attack: "At"
        case .block: "Bl"
        case .dig: "Dg"
        case .error: "Er"
        }
    }
}

// MARK: - Timeout Sheet

private struct TimeoutSheet: View {
    @Bindable var store: StoreOf<MatchInputFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("使用済み")) {
                    HStack {
                        Text("自軍")
                        Spacer()
                        Text("\(store.ownTimeoutsUsed) / \(MatchSet.maxTimeoutsPerTeamPerSet)")
                            .monospacedDigit()
                    }
                    HStack {
                        Text("相手")
                        Spacer()
                        Text("\(store.opponentTimeoutsUsed) / \(MatchSet.maxTimeoutsPerTeamPerSet)")
                            .monospacedDigit()
                    }
                }

                Section {
                    Button("自軍 タイムアウト") {
                        store.send(.timeoutRequested(.own))
                        store.send(.presentTimeoutSheet(false))
                    }
                    .disabled(store.ownTimeoutsUsed >= MatchSet.maxTimeoutsPerTeamPerSet)

                    Button("相手 タイムアウト") {
                        store.send(.timeoutRequested(.opponent))
                        store.send(.presentTimeoutSheet(false))
                    }
                    .disabled(store.opponentTimeoutsUsed >= MatchSet.maxTimeoutsPerTeamPerSet)
                }
            }
            .navigationTitle("タイムアウト")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { store.send(.presentTimeoutSheet(false)) }
                }
            }
        }
    }
}

// MARK: - Substitution Sheet

private struct SubstitutionSheet: View {
    @Bindable var store: StoreOf<MatchInputFeature>
    @State private var playerOutId: UUID?
    @State private var playerInIdText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("出る選手 (現在ロスター)")) {
                    ForEach(store.match.serviceOrders.sorted(by: { $0.order < $1.order })) { entry in
                        Button {
                            playerOutId = entry.currentPlayerId
                        } label: {
                            HStack {
                                Text("順 \(entry.order)").frame(width: 60)
                                Text(entry.currentPlayerId.uuidString.prefix(8) + "…")
                                Spacer()
                                if playerOutId == entry.currentPlayerId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.Lumi.excellent)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("入る選手 ID")) {
                    let idField = TextField("Player ID (UUID)", text: $playerInIdText)
                        .autocorrectionDisabled()
                    #if os(iOS)
                    idField.textInputAutocapitalization(.never)
                    #else
                    idField
                    #endif
                }
            }
            .navigationTitle("選手交代")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { store.send(.presentSubstitutionSheet(false)) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("実行") {
                        guard let outId = playerOutId,
                              let inId = UUID(uuidString: playerInIdText) else { return }
                        store.send(.substitutionRequested([
                            .init(playerOut: outId, playerIn: inId)
                        ]))
                        store.send(.presentSubstitutionSheet(false))
                    }
                    .disabled(playerOutId == nil || UUID(uuidString: playerInIdText) == nil)
                }
            }
        }
    }
}
