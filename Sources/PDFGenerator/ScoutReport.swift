// ScoutReport — 試合前ブリーフィング PDF (Phase 2.0)
//
// 過去の対戦データから対戦相手の傾向を分析した PDF を生成。

import Foundation
import Models
import StatsEngine

#if canImport(UIKit)
import UIKit
import PDFKit
#endif

public struct ScoutReport: Sendable {
    public let opponentTeamName: String
    public let analyzedMatches: [Match]
    public let attackCourseTally: [AttackCourse: Int]
    public let serveCourseTally: [Int: Int]

    public init(opponentTeamName: String, analyzedMatches: [Match]) {
        self.opponentTeamName = opponentTeamName
        let engine = StatsEngine()
        var attack: [AttackCourse: Int] = [:]
        var serve: [Int: Int] = [:]
        for m in analyzedMatches where m.opponentTeamName == opponentTeamName {
            for (k, v) in engine.opponentAttackCourseTally(in: m, scope: .wholeMatch) {
                attack[k, default: 0] += v
            }
            for (k, v) in engine.opponentServeCourseTally(in: m, scope: .wholeMatch) {
                serve[k, default: 0] += v
            }
        }
        self.analyzedMatches = analyzedMatches.filter { $0.opponentTeamName == opponentTeamName }
        self.attackCourseTally = attack
        self.serveCourseTally = serve
    }
}

public struct ScoutReportPDFGenerator: Sendable {
    public init() {}

    public func generate(_ report: ScoutReport) -> Data {
        #if canImport(UIKit)
        return render(report)
        #else
        return Data()
        #endif
    }

    #if canImport(UIKit)
    private func render(_ report: ScoutReport) -> Data {
        let pageSize = CGSize(width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            ("対戦相手スカウトレポート").draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14)]
            ("対戦相手: \(report.opponentTeamName)").draw(at: CGPoint(x: 40, y: 80), withAttributes: subAttrs)
            ("過去対戦数: \(report.analyzedMatches.count)").draw(at: CGPoint(x: 40, y: 100), withAttributes: subAttrs)

            // アタックコース傾向
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ]
            ("■ アタックコース傾向").draw(at: CGPoint(x: 40, y: 150), withAttributes: subAttrs)
            for (i, course) in AttackCourse.allCases.enumerated() {
                let count = report.attackCourseTally[course] ?? 0
                ("  \(course.rawValue.uppercased())  \(count)")
                    .draw(at: CGPoint(x: 40, y: 175 + CGFloat(i) * 18), withAttributes: bodyAttrs)
            }

            // サーブコース傾向 (ゾーン)
            ("■ サーブコース傾向 (ゾーン1〜9)").draw(at: CGPoint(x: 40, y: 320), withAttributes: subAttrs)
            for zone in 1...9 {
                let count = report.serveCourseTally[zone] ?? 0
                ("  Zone \(zone)  \(count)")
                    .draw(at: CGPoint(x: 40, y: 345 + CGFloat(zone - 1) * 18), withAttributes: bodyAttrs)
            }
        }
    }
    #endif
}
