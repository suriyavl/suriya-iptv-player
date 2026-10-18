import Foundation

/// Minimal arbitrary-precision unsigned integer, enough for exact wei arithmetic
/// (hex <-> decimal conversion, add, multiply, compare). Floating point is never
/// used for amounts.
struct BigUInt: Comparable, Hashable, CustomStringConvertible {
    /// Little-endian base-2^32 limbs, no trailing zero limbs.
    private(set) var limbs: [UInt32]

    static let zero = BigUInt(limbs: [])

    private init(limbs: [UInt32]) {
        self.limbs = limbs
        normalize()
    }

    init(_ value: UInt64) {
        self.init(limbs: [UInt32(truncatingIfNeeded: value), UInt32(truncatingIfNeeded: value >> 32)])
    }

    /// Parses "0x1a2b" or "1a2b".
    init?(hex: String) {
        var digits = Substring(hex)
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") { digits = digits.dropFirst(2) }
        guard !digits.isEmpty, digits.count <= 128 else { return nil }
        var result = BigUInt.zero
        for ch in digits {
            guard let d = ch.hexDigitValue else { return nil }
            result = result.multiplied(bySmall: 16).adding(small: UInt32(d))
        }
        self = result
    }

    /// Parses a base-10 integer string.
    init?(decimal: String) {
        guard !decimal.isEmpty, decimal.count <= 100 else { return nil }
        var result = BigUInt.zero
        for ch in decimal {
            guard let d = ch.wholeNumberValue, ch.isASCII else { return nil }
            result = result.multiplied(bySmall: 10).adding(small: UInt32(d))
        }
        self = result
    }

    var isZero: Bool { limbs.isEmpty }

    var hexString: String {
        guard !isZero else { return "0" }
        var s = String(limbs.last!, radix: 16)
        for limb in limbs.dropLast().reversed() {
            let part = String(limb, radix: 16)
            s += String(repeating: "0", count: 8 - part.count) + part
        }
        return s
    }

    /// Minimal big-endian bytes, at least one byte (the encoding WalletCore expects).
    var serialized: Data {
        var bytes: [UInt8] = []
        for limb in limbs.reversed() {
            bytes += [UInt8(limb >> 24 & 0xff), UInt8(limb >> 16 & 0xff), UInt8(limb >> 8 & 0xff), UInt8(limb & 0xff)]
        }
        while bytes.count > 1, bytes.first == 0 { bytes.removeFirst() }
        return Data(bytes.isEmpty ? [0] : bytes)
    }

    var description: String {
        guard !isZero else { return "0" }
        var digits: [Character] = []
        var n = self
        while !n.isZero {
            let (q, r) = n.divided(bySmall: 10)
            digits.append(Character(String(r)))
            n = q
        }
        return String(digits.reversed())
    }

    // MARK: Arithmetic

    static func + (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        var out: [UInt32] = []
        var carry: UInt64 = 0
        for i in 0..<max(lhs.limbs.count, rhs.limbs.count) {
            let sum = UInt64(i < lhs.limbs.count ? lhs.limbs[i] : 0) + UInt64(i < rhs.limbs.count ? rhs.limbs[i] : 0) + carry
            out.append(UInt32(truncatingIfNeeded: sum))
            carry = sum >> 32
        }
        if carry > 0 { out.append(UInt32(carry)) }
        return BigUInt(limbs: out)
    }

    static func * (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
        guard !lhs.isZero, !rhs.isZero else { return .zero }
        var out = [UInt32](repeating: 0, count: lhs.limbs.count + rhs.limbs.count)
        for i in 0..<lhs.limbs.count {
            var carry: UInt64 = 0
            for j in 0..<rhs.limbs.count {
                let t = UInt64(lhs.limbs[i]) * UInt64(rhs.limbs[j]) + UInt64(out[i + j]) + carry
                out[i + j] = UInt32(truncatingIfNeeded: t)
                carry = t >> 32
            }
            out[i + rhs.limbs.count] = UInt32(carry)
        }
        return BigUInt(limbs: out)
    }

    static func < (lhs: BigUInt, rhs: BigUInt) -> Bool {
        if lhs.limbs.count != rhs.limbs.count { return lhs.limbs.count < rhs.limbs.count }
        for i in stride(from: lhs.limbs.count - 1, through: 0, by: -1) where lhs.limbs[i] != rhs.limbs[i] {
            return lhs.limbs[i] < rhs.limbs[i]
        }
        return false
    }

    func multiplied(bySmall m: UInt32) -> BigUInt {
        self * BigUInt(UInt64(m))
    }

    func adding(small a: UInt32) -> BigUInt {
        self + BigUInt(UInt64(a))
    }

    func divided(bySmall d: UInt32) -> (quotient: BigUInt, remainder: UInt32) {
        precondition(d != 0)
        var out = [UInt32](repeating: 0, count: limbs.count)
        var rem: UInt64 = 0
        for i in stride(from: limbs.count - 1, through: 0, by: -1) {
            let cur = (rem << 32) | UInt64(limbs[i])
            out[i] = UInt32(cur / UInt64(d))
            rem = cur % UInt64(d)
        }
        return (BigUInt(limbs: out), UInt32(rem))
    }

    private mutating func normalize() {
        while limbs.last == 0 { limbs.removeLast() }
    }
}

/// Conversion between wei and human-readable ether strings.
enum Ether {
    static let decimals = 18

    /// "1.5" -> 1500000000000000000 wei. Rejects negatives, exponents, more than 18 decimals.
    static func parse(_ input: String) -> BigUInt? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let whole = parts[0].isEmpty ? "0" : String(parts[0])
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard fraction.count <= decimals, !(parts[0].isEmpty && fraction.isEmpty) else { return nil }
        let padded = fraction + String(repeating: "0", count: decimals - fraction.count)
        return BigUInt(decimal: whole + padded)
    }

    /// 1500000000000000000 wei -> "1.5"
    static func format(_ wei: BigUInt, maxFractionDigits: Int = 6) -> String {
        var s = wei.description
        if s.count <= decimals { s = String(repeating: "0", count: decimals - s.count + 1) + s }
        let whole = s.prefix(s.count - decimals)
        var fraction = String(s.suffix(decimals).prefix(maxFractionDigits))
        while fraction.last == "0" { fraction.removeLast() }
        return fraction.isEmpty ? String(whole) : "\(whole).\(fraction)"
    }
}
