// ReviewFeature — 試合終了後の振り返り画面
//
// PDF / CSV エクスポート + 共有

import ComposableArchitecture
import CSVExporter
import DesignSystem
import Foundation
import MatchBackup
import Models
import PDFGenerator
import StatsEngine
import SwiftUI

@Reducer
public struct ReviewFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var match: Match
        public var ownStats: TeamStats = .empty
        public var opponentStats: TeamStats = .empty
        public var generatingPDF: Bool = false
        public var pdfData: Data?
        public var csvPlayerData: Data?
        public var csvLogData: Data?
        public var backupURL: URL?

        public init(match: Match) {
            self.match = match
        }
    }

    public enum Action: Equatable {
        case onAppear
        case statsComputed(own: TeamStats, opp: TeamStats)
        case generatePDFTapped
        case pdfGenerated(Data)
        case generateCSVTapped
        case csvGenerated(player: Data, log: Data)
        case writeBackupTapped
        case backupWritten(URL)
        case backupFailed(String)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let match = state.match
                return .run { send in
                    let engine = StatsEngine()
                    let own = engine.teamStats(in: match, scope: .wholeMatch, side: .own)
                    let opp = engine.teamStats(in: match, scope: .wholeMatch, side: .opponent)
                    await send(.statsComputed(own: own, opp: opp))
                }

            case let .statsComputed(own, opp):
                state.ownStats = own
                state.opponentStats = opp
                return .none

            case .generatePDFTapped:
                state.generatingPDF = true
                let match = state.match
                return .run { send in
                    let pdf = PDFGenerator().generateMatchSummary(match: match)
                    await send(.pdfGenerated(pdf))
                }

            case let .pdfGenerated(data):
                state.generatingPDF = false
                state.pdfData = data
                return .none

            case .generateCSVTapped:
                let match = state.match
                return .run { send in
                    let p = CSVExporter.playerStatsCSV(match: match).data(using: .utf8) ?? Data()
                    let l = CSVExporter.playLogCSV(match: match).data(using: .utf8) ?? Data()
                    await send(.csvGenerated(player: p, log: l))
                }

            case let .csvGenerated(player, log):
                state.csvPlayerData = player
                state.csvLogData = log
                return .none

            case .writeBackupTapped:
                let match = state.match
                return .run { send in
                    do {
                        let url = try MatchBackup.writeToDocuments(match)
                        await send(.backupWritten(url))
                    } catch {
                        await send(.backupFailed(error.localizedDescription))
                    }
                }

            case let .backupWritten(url):
                state.backupURL = url
                return .none

            case .backupFailed:
                return .none
            }
        }
    }
}

// MARK: - View

public struct ReviewView: View {
    @Bindable public var store: StoreOf<ReviewFeature>

    public init(store: StoreOf<ReviewFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsRow
                exportButtons
                shareSection
            }
            .padding(16)
        }
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
        .task { store.send(.onAppear) }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("試合終了").font(.Lumi.headlineMedium)
            Text("vs \(store.match.opponentTeamName)").font(.Lumi.body).foregroundStyle(Color.Lumi.textSecondary)
        }
    }

    @ViewBuilder
    private var statsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            statsBlock(title: "自軍", stats: store.ownStats, accent: Color.Lumi.accent)
            statsBlock(title: "相手", stats: store.opponentStats, accent: Color.Lumi.poor)
        }
    }

    @ViewBuilder
    private func statsBlock(title: String, stats: TeamStats, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.Lumi.headlineSmall).foregroundStyle(accent)
            HStack { Text("Atk決定率"); Spacer(); Text(String(format: "%.1f%%", stats.attackKillRate)).monospacedDigit() }
            HStack { Text("Atk効果率"); Spacer(); Text(String(format: "%.1f%%", stats.attackEfficiency)).monospacedDigit() }
            HStack { Text("Rcp A率"); Spacer(); Text(String(format: "%.1f%%", stats.receptionAPassRate)).monospacedDigit() }
            HStack { Text("Sv効率"); Spacer(); Text(String(format: "%.1f%%", stats.serveEfficiency)).monospacedDigit() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.Lumi.surface))
    }

    @ViewBuilder
    private var exportButtons: some View {
        VStack(spacing: 8) {
            Button {
                store.send(.generatePDFTapped)
            } label: {
                Label("PDF を生成", systemImage: "doc.richtext")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.generatingPDF)

            Button {
                store.send(.generateCSVTapped)
            } label: {
                Label("CSV を生成", systemImage: "tablecells")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                store.send(.writeBackupTapped)
            } label: {
                Label("バックアップ JSON 書き出し", systemImage: "externaldrive.badge.timemachine")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var shareSection: some View {
        VStack(spacing: 8) {
            if let pdf = store.pdfData, !pdf.isEmpty {
                ShareLink(item: pdf, preview: SharePreview("試合サマリ", image: Image(systemName: "doc.text"))) {
                    Label("PDF を共有", systemImage: "square.and.arrow.up")
                }
            }
            if let csv = store.csvPlayerData {
                ShareLink(item: csv, preview: SharePreview("選手別集計", image: Image(systemName: "tablecells"))) {
                    Label("CSV (選手別) を共有", systemImage: "square.and.arrow.up")
                }
            }
            if let csv = store.csvLogData {
                ShareLink(item: csv, preview: SharePreview("プレーログ", image: Image(systemName: "list.bullet"))) {
                    Label("CSV (プレーログ) を共有", systemImage: "square.and.arrow.up")
                }
            }
            if let url = store.backupURL {
                Text("バックアップ保存先:\n\(url.path)").font(.Lumi.caption).foregroundStyle(Color.Lumi.textSecondary)
            }
        }
    }
}
