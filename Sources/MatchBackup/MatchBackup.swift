// MatchBackup — 試合データを JSON にエンコードしてバックアップ

import Foundation
import Models

public enum MatchBackup {
    /// ミリ秒精度を維持するため Date は秒の Double 値で保存
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    public static func encode(_ match: Match) throws -> Data {
        try encoder.encode(match)
    }

    public static func decode(_ data: Data) throws -> Match {
        try decoder.decode(Match.self, from: data)
    }

    /// バックアップファイル名 (試合 ID + 試合日)
    public static func suggestedFilename(for match: Match) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let dateStr = formatter.string(from: match.startTime)
        return "lumi-backup-\(dateStr)-\(match.id.uuidString.prefix(8)).json"
    }

    /// Documents ディレクトリ配下に書き出し
    public static func writeToDocuments(_ match: Match) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = docs.appendingPathComponent(suggestedFilename(for: match))
        let data = try encode(match)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
