// SeasonReport — シーズン累計レポート PDF (Phase 2.0)

import Foundation
import Models
import StatsEngine

#if canImport(UIKit)
import UIKit
import PDFKit
#endif

public struct SeasonReportPDFGenerator: Sendable {
    public init() {}

    public func generate(matches: [Match]) -> Data {
        #if canImport(UIKit)
        return render(matches: matches)
        #else
        return Data()
        #endif
    }

    #if canImport(UIKit)
    private func render(matches: [Match]) -> Data {
        let stats = StatsEngine().seasonStats(matches: matches)
        let pageSize = CGSize(width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold)
            ]
            ("シーズン累計レポート").draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
            ("試合数: \(stats.matchCount)  勝: \(stats.winCount)  敗: \(stats.lossCount)")
                .draw(at: CGPoint(x: 40, y: 80), withAttributes: subAttrs)

            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
            ("■ 累計集計").draw(at: CGPoint(x: 40, y: 120), withAttributes: subAttrs)
            let lines = [
                String(format: "  アタック決定率   %5.1f%%", stats.aggregate.attackKillRate),
                String(format: "  アタック効果率   %5.1f%%", stats.aggregate.attackEfficiency),
                String(format: "  レセプション A率  %5.1f%%", stats.aggregate.receptionAPassRate),
                String(format: "  サーブ効率      %5.1f%%", stats.aggregate.serveEfficiency),
                String(format: "  ブロック決定    %5d", stats.aggregate.blockKills),
                String(format: "  アシスト        %5d", stats.aggregate.assists)
            ]
            for (i, line) in lines.enumerated() {
                line.draw(at: CGPoint(x: 40, y: 145 + CGFloat(i) * 18), withAttributes: bodyAttrs)
            }

            // 試合別サマリ
            ("■ 試合別サマリ").draw(at: CGPoint(x: 40, y: 280), withAttributes: subAttrs)
            for (i, m) in stats.perMatch.enumerated() {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                let line = String(
                    format: "  %@ vs %@   %@ (%d-%d)",
                    formatter.string(from: m.date), m.opponentTeamName,
                    m.result.rawValue.uppercased(),
                    m.ourSetsWon, m.opponentSetsWon
                )
                line.draw(at: CGPoint(x: 40, y: 305 + CGFloat(i) * 18), withAttributes: bodyAttrs)
            }
        }
    }
    #endif
}
