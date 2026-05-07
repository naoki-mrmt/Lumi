// MatchViewerView — KPIダッシュボード + 得点推移グラフ + フィルタ

import Charts
import ComposableArchitecture
import DesignSystem
import Foundation
import Models
import StatsEngine
import SwiftUI

public struct MatchViewerView: View {
    @Bindable public var store: StoreOf<MatchViewerFeature>

    public init(store: StoreOf<MatchViewerFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                filterRow
                HStack(alignment: .top, spacing: 16) {
                    statsColumn(title: "自チーム", stats: store.ownStats, accent: Color.Lumi.accent)
                    statsColumn(title: "相手", stats: store.opponentStats, accent: Color.Lumi.poor)
                }
                if let p = store.playerStats {
                    playerCard(p)
                }
                scoreChart
            }
            .padding(16)
        }
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
        .task { store.send(.onAppear) }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Set \(currentSetNumber)")
                .font(.Lumi.headlineMedium)
            Spacer()
            HStack(spacing: 8) {
                Text("\(ourTotalScore)").font(.Lumi.scoreMedium).monospacedDigit()
                Text("-").foregroundStyle(Color.Lumi.textTertiary)
                Text("\(opponentTotalScore)").font(.Lumi.scoreMedium).monospacedDigit()
                    .foregroundStyle(Color.Lumi.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var filterRow: some View {
        HStack(spacing: 12) {
            scopePicker
            Spacer()
            playerMenu
        }
    }

    @ViewBuilder
    private var scopePicker: some View {
        let binding = Binding<String>(
            get: { scopeKey(store.statsScope) },
            set: { newKey in
                if let scope = scopeFromKey(newKey) {
                    store.send(.scopeChanged(scope))
                }
            }
        )
        Picker("Scope", selection: binding) {
            Text("全試合").tag("whole")
            ForEach(store.match.sets) { set in
                Text("Set \(set.setNumber)").tag("set\(set.setNumber)")
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private var playerMenu: some View {
        if !store.match.serviceOrders.isEmpty {
            Menu {
                Button("選手フィルタ解除") {
                    store.send(.playerSelected(nil))
                }
                let sorted = store.match.serviceOrders.sorted(by: { $0.order < $1.order })
                ForEach(sorted) { entry in
                    Button("順 \(entry.order)") {
                        store.send(.playerSelected(entry.currentPlayerId))
                    }
                }
            } label: {
                Label(store.selectedPlayerId == nil ? "選手別" : "選手選択中", systemImage: "person")
            }
        }
    }

    private func scopeKey(_ s: StatsScope) -> String {
        switch s {
        case .wholeMatch: "whole"
        case let .set(n): "set\(n)"
        case .formation: "whole"
        }
    }

    private func scopeFromKey(_ key: String) -> StatsScope? {
        if key == "whole" { return .wholeMatch }
        if key.hasPrefix("set"), let n = Int(key.dropFirst(3)) {
            return .set(n)
        }
        return nil
    }

    @ViewBuilder
    private func statsColumn(title: String, stats: TeamStats, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.Lumi.headlineSmall).foregroundStyle(accent)

            statsSection("アタック") {
                statRow("打数", "\(stats.attackAttempts)")
                statRow("決定率", String(format: "%.1f%%", stats.attackKillRate))
                statRow("効果率", String(format: "%.1f%%", stats.attackEfficiency))
            }
            statsSection("レセプション") {
                statRow("試行数", "\(stats.receptionAttempts)")
                statRow("A率", String(format: "%.1f%%", stats.receptionAPassRate))
                statRow("返球率", String(format: "%.1f%%", stats.receptionReturnRate))
            }
            statsSection("サーブ") {
                statRow("試行数", "\(stats.serveAttempts)")
                statRow("エース", "\(stats.serveAces)")
                statRow("効率", String(format: "%.1f%%", stats.serveEfficiency))
            }
            statsSection("その他") {
                statRow("ブロック決定", "\(stats.blockKills)")
                statRow("ディグ", "\(stats.digs)")
                statRow("アシスト", "\(stats.assists)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(Color.Lumi.surface)
        )
    }

    @ViewBuilder
    private func statsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.Lumi.caption)
                .foregroundStyle(Color.Lumi.textTertiary)
            content()
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.Lumi.body).foregroundStyle(Color.Lumi.textSecondary)
            Spacer()
            Text(value).font(.Lumi.statMedium).monospacedDigit()
        }
    }

    @ViewBuilder
    private func playerCard(_ p: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選手別: \(p.playerId.uuidString.prefix(8))…")
                .font(.Lumi.headlineSmall)
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    statRow("Atk 試行", "\(p.attackAttempts)")
                    statRow("決定率", String(format: "%.1f%%", p.attackKillRate))
                    statRow("効果率", String(format: "%.1f%%", p.attackEfficiency))
                }
                VStack(alignment: .leading) {
                    statRow("Sv 試行", "\(p.serveAttempts)")
                    statRow("エース", "\(p.serveAces)")
                    statRow("アシスト", "\(p.assists)")
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.Lumi.surfaceElevated))
    }

    // MARK: - Score Chart

    @ViewBuilder
    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("得点推移").font(.Lumi.headlineSmall)
            ScoreChartContent(
                ownSeries: scoreSeries(side: .own),
                opponentSeries: scoreSeries(side: .opponent),
                timeoutMarks: timeoutMarks,
                runs: store.consecutiveRuns
            )
            .frame(height: 220)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.Lumi.surface))
        }
    }

    // MARK: - Helpers

    fileprivate struct ScorePoint: Sendable, Hashable {
        let rallyNumber: Int
        let score: Int
    }

    fileprivate struct TimeoutMark: Sendable, Hashable {
        let rallyNumber: Int
        let score: Int
    }

    private var currentSetNumber: Int {
        currentSet?.setNumber ?? 1
    }

    private var currentSet: MatchSet? {
        switch store.statsScope {
        case .wholeMatch: store.match.sets.last
        case let .set(n): store.match.sets.first(where: { $0.setNumber == n })
        case .formation: store.match.sets.first
        }
    }

    private var ourTotalScore: Int {
        currentSet?.rallies.filter { $0.winner == .own }.count ?? 0
    }

    private var opponentTotalScore: Int {
        currentSet?.rallies.filter { $0.winner == .opponent }.count ?? 0
    }

    private func scoreSeries(side: Team.ServingSide) -> [ScorePoint] {
        guard let set = currentSet else { return [] }
        var running = 0
        var out: [ScorePoint] = [ScorePoint(rallyNumber: 0, score: 0)]
        for rally in set.rallies.sorted(by: { $0.rallyNumber < $1.rallyNumber }) {
            if rally.winner == side { running += 1 }
            out.append(ScorePoint(rallyNumber: rally.rallyNumber, score: running))
        }
        return out
    }

    private var timeoutMarks: [TimeoutMark] {
        guard let set = currentSet else { return [] }
        return set.timeouts.map { to in
            TimeoutMark(
                rallyNumber: set.rallies.last?.rallyNumber ?? 0,
                score: to.requestingTeam == .own ? to.ourScore : to.opponentScore
            )
        }
    }
}

// MARK: - Chart Content (split out to help type-checker)

private struct ScoreChartContent: View {
    let ownSeries: [MatchViewerView.ScorePoint]
    let opponentSeries: [MatchViewerView.ScorePoint]
    let timeoutMarks: [MatchViewerView.TimeoutMark]
    let runs: [ConsecutiveRun]

    var body: some View {
        Chart {
            ownLines
            opponentLines
            timeoutPoints
            runRectangles
        }
    }

    @ChartContentBuilder
    private var ownLines: some ChartContent {
        ForEach(ownSeries, id: \.rallyNumber) { p in
            LineMark(
                x: .value("ラリー", p.rallyNumber),
                y: .value("自軍", p.score)
            )
            .foregroundStyle(Color.Lumi.accent)
            .symbol(.circle)
        }
    }

    @ChartContentBuilder
    private var opponentLines: some ChartContent {
        ForEach(opponentSeries, id: \.rallyNumber) { p in
            LineMark(
                x: .value("ラリー", p.rallyNumber),
                y: .value("相手", p.score)
            )
            .foregroundStyle(Color.Lumi.poor)
            .symbol(.diamond)
        }
    }

    @ChartContentBuilder
    private var timeoutPoints: some ChartContent {
        ForEach(timeoutMarks, id: \.rallyNumber) { mark in
            PointMark(
                x: .value("ラリー", mark.rallyNumber),
                y: .value("Score", mark.score)
            )
            .foregroundStyle(Color.Lumi.average)
            .symbol(.cross)
        }
    }

    @ChartContentBuilder
    private var runRectangles: some ChartContent {
        ForEach(runs, id: \.self) { run in
            RectangleMark(
                xStart: .value("From", run.startRallyNumber),
                xEnd: .value("To", run.endRallyNumber + 1),
                yStart: .value("min", 0),
                yEnd: .value("max", 25)
            )
            .foregroundStyle((run.team == .own ? Color.Lumi.excellent : Color.Lumi.poor).opacity(0.15))
        }
    }
}
