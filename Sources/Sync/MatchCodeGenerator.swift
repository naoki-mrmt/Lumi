// MatchCodeGenerator — 6桁試合コード生成
//
// 紛らわしい文字を除外: 0/O, 1/I/L
// charset: 23456789 + ABCDEFGHJKMNPQRSTUVWXYZ (32文字)

import Foundation

public enum MatchCodeGenerator: Sendable {
    public static let charset: [Character] = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    public static let codeLength = 6

    /// 任意の RNG で決定論的に生成可能
    public static func generate(using rng: inout some RandomNumberGenerator) -> String {
        var out = ""
        out.reserveCapacity(codeLength)
        for _ in 0..<codeLength {
            let idx = Int(rng.next() % UInt64(charset.count))
            out.append(charset[idx])
        }
        return out
    }

    public static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }

    /// コード形式の検証 (長さと charset)
    public static func isValid(_ code: String) -> Bool {
        guard code.count == codeLength else { return false }
        let set = Set(charset)
        return code.allSatisfy { set.contains($0) }
    }
}
