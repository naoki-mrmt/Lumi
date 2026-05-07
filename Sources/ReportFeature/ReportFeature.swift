// ReportFeature — Phase 2.0 レポート出力 UI
//
// 試合サマリ / スカウトレポート / シーズンレポート の生成 + 共有

import ComposableArchitecture
import DesignSystem
import Foundation
import Models
import PDFGenerator
import StatsEngine
import SwiftUI

@Reducer
public struct ReportFeature: Sendable {
    public enum ReportType: String, CaseIterable, Sendable, Equatable {
        case matchSummary = "試合サマリ"
        case scoutReport  = "スカウトレポート"
        case seasonReport = "シーズン累計"
    }

    @ObservableState
    public struct State: Equatable {
        public var matches: [Match]
        public var selectedReportType: ReportType = .matchSummary
        public var selectedMatchId: UUID?
        public var selectedOpponentName: String?
        public var generatedPDF: Data?
        public var isGenerating: Bool = false

        public init(matches: [Match]) {
            self.matches = matches
            self.selectedMatchId = matches.first?.id
            self.selectedOpponentName = matches.first?.opponentTeamName
        }

        public var availableOpponents: [String] {
            Array(Set(matches.map(\.opponentTeamName))).sorted()
        }
    }

    public enum Action: Equatable {
        case reportTypeChanged(ReportType)
        case matchSelected(UUID?)
        case opponentSelected(String?)
        case generateTapped
        case pdfGenerated(Data)
        case clearPDF
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .reportTypeChanged(type):
                state.selectedReportType = type
                state.generatedPDF = nil
                return .none

            case let .matchSelected(id):
                state.selectedMatchId = id
                return .none

            case let .opponentSelected(name):
                state.selectedOpponentName = name
                return .none

            case .generateTapped:
                state.isGenerating = true
                let type = state.selectedReportType
                let matches = state.matches
                let matchId = state.selectedMatchId
                let opponent = state.selectedOpponentName
                return .run { send in
                    let data = await Self.generate(
                        type: type,
                        matches: matches,
                        matchId: matchId,
                        opponent: opponent
                    )
                    await send(.pdfGenerated(data))
                }

            case let .pdfGenerated(data):
                state.isGenerating = false
                state.generatedPDF = data
                return .none

            case .clearPDF:
                state.generatedPDF = nil
                return .none
            }
        }
    }

    private static func generate(
        type: ReportType,
        matches: [Match],
        matchId: UUID?,
        opponent: String?
    ) async -> Data {
        switch type {
        case .matchSummary:
            guard let id = matchId, let match = matches.first(where: { $0.id == id }) else { return Data() }
            return PDFGenerator().generateMatchSummary(match: match)
        case .scoutReport:
            guard let opp = opponent else { return Data() }
            let report = ScoutReport(opponentTeamName: opp, analyzedMatches: matches)
            return ScoutReportPDFGenerator().generate(report)
        case .seasonReport:
            return SeasonReportPDFGenerator().generate(matches: matches)
        }
    }
}

// MARK: - View

public struct ReportView: View {
    @Bindable public var store: StoreOf<ReportFeature>

    public init(store: StoreOf<ReportFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("レポート").font(.Lumi.headlineMedium)

                Picker("種類", selection: Binding(
                    get: { store.selectedReportType },
                    set: { store.send(.reportTypeChanged($0)) }
                )) {
                    ForEach(ReportFeature.ReportType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                contextPicker

                Button {
                    store.send(.generateTapped)
                } label: {
                    Label(store.isGenerating ? "生成中…" : "PDF を生成", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isGenerating)

                if let pdf = store.generatedPDF, !pdf.isEmpty {
                    HStack {
                        Text("生成済み: \(pdf.count / 1024) KB").font(.Lumi.caption)
                        Spacer()
                        ShareLink(item: pdf, preview: SharePreview(store.selectedReportType.rawValue, image: Image(systemName: "doc.text"))) {
                            Label("共有", systemImage: "square.and.arrow.up")
                        }
                        Button("クリア") { store.send(.clearPDF) }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.Lumi.surface))
                }
            }
            .padding(16)
        }
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
    }

    @ViewBuilder
    private var contextPicker: some View {
        switch store.selectedReportType {
        case .matchSummary:
            Picker("試合", selection: Binding(
                get: { store.selectedMatchId ?? UUID() },
                set: { store.send(.matchSelected($0)) }
            )) {
                ForEach(store.matches) { match in
                    Text("\(match.date.formatted(date: .abbreviated, time: .omitted)) vs \(match.opponentTeamName)")
                        .tag(match.id)
                }
            }
        case .scoutReport:
            Picker("対戦相手", selection: Binding(
                get: { store.selectedOpponentName ?? "" },
                set: { store.send(.opponentSelected($0)) }
            )) {
                ForEach(store.availableOpponents, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        case .seasonReport:
            Text("全 \(store.matches.count) 試合をまとめます")
                .font(.Lumi.caption)
                .foregroundStyle(Color.Lumi.textSecondary)
        }
    }
}
