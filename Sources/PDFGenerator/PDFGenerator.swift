// PDFGenerator — 試合サマリ PDF を生成 (PDFKit / UIKit ベース)
//
// docs/04_UI_DESIGN.md 10.1 のレイアウトに準拠 (A4・1〜2枚)
// iOS 専用。macOS テスト時はスタブを返す。

import Foundation
import Models
import StatsEngine

#if canImport(UIKit)
import UIKit
import PDFKit
#endif

public struct PDFGenerator: Sendable {
    public init() {}

    /// 試合サマリ PDF データを生成。
    /// - Returns: PDF バイナリデータ。生成失敗時は空 Data。
    public func generateMatchSummary(match: Match) -> Data {
        #if canImport(UIKit)
        return renderPDF(match: match)
        #else
        // macOS テストでは空 Data を返す (本番は iOS 限定機能)
        return Data()
        #endif
    }
}

#if canImport(UIKit)
private extension PDFGenerator {
    func renderPDF(match: Match) -> Data {
        let pageSize = CGSize(width: 595, height: 842) // A4
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawPage1(match: match, in: ctx.pdfContextBounds)
            ctx.beginPage()
            drawPage2(match: match, in: ctx.pdfContextBounds)
        }
    }

    func drawPage1(match: Match, in bounds: CGRect) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let title = "9人制バレーボール 試合記録"
        title.draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateLine = "\(formatter.string(from: match.date))  vs \(match.opponentTeamName)"
        dateLine.draw(at: CGPoint(x: 40, y: 80), withAttributes: subAttrs)

        if let venue = match.venue {
            ("会場: \(venue)").draw(at: CGPoint(x: 40, y: 100), withAttributes: subAttrs)
        }

        // チーム集計
        let engine = StatsEngine()
        let own = engine.teamStats(in: match, scope: .wholeMatch, side: .own)
        let opp = engine.teamStats(in: match, scope: .wholeMatch, side: .opponent)

        drawTeamStatsTable(at: CGPoint(x: 40, y: 150), title: "■ チーム集計 (自軍)", stats: own)
        drawTeamStatsTable(at: CGPoint(x: 320, y: 150), title: "■ チーム集計 (相手)", stats: opp)
    }

    func drawTeamStatsTable(at origin: CGPoint, title: String, stats: TeamStats) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: origin, withAttributes: titleAttrs)

        let lines = [
            String(format: "  アタック決定率   %5.1f%%", stats.attackKillRate),
            String(format: "  アタック効果率   %5.1f%%", stats.attackEfficiency),
            String(format: "  レセプション A率  %5.1f%%", stats.receptionAPassRate),
            String(format: "  サーブ効率      %5.1f%%", stats.serveEfficiency),
            String(format: "  ブロック決定    %5d", stats.blockKills),
            String(format: "  アシスト        %5d", stats.assists)
        ]
        for (i, line) in lines.enumerated() {
            line.draw(at: CGPoint(x: origin.x, y: origin.y + 22 + CGFloat(i) * 18), withAttributes: bodyAttrs)
        }
    }

    func drawPage2(match: Match, in bounds: CGRect) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        ("■ 選手別集計").draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let header = "  Player           Atk att  Atk%  Eff%  Aces  Asst"
        header.draw(at: CGPoint(x: 40, y: 80), withAttributes: bodyAttrs)

        let engine = StatsEngine()
        let starters = match.serviceOrders.sorted(by: { $0.order < $1.order }).map(\.startingPlayerId)
        for (i, pid) in starters.enumerated() {
            let s = engine.playerStats(playerId: pid, in: match, scope: .wholeMatch)
            let line = String(
                format: "  %-16@ %4d   %5.1f %5.1f %4d %4d",
                pid.uuidString.prefix(8) as NSString,
                s.attackAttempts, s.attackKillRate, s.attackEfficiency,
                s.serveAces, s.assists
            )
            line.draw(at: CGPoint(x: 40, y: 100 + CGFloat(i) * 16), withAttributes: bodyAttrs)
        }
    }
}
#endif
