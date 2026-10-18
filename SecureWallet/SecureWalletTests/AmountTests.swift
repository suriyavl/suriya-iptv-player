import XCTest
@testable import SecureWallet

final class AmountTests: XCTestCase {
    func testHexRoundTrip() {
        let value = BigUInt(hex: "0x0de0b6b3a7640000")!
        XCTAssertEqual(value.description, "1000000000000000000")
        XCTAssertEqual(value.hexString, "de0b6b3a7640000")
        XCTAssertEqual(value.serialized, Data([0x0d, 0xe0, 0xb6, 0xb3, 0xa7, 0x64, 0x00, 0x00]))
        XCTAssertEqual(BigUInt.zero.serialized, Data([0]))
    }

    func testLargeValues() {
        let max256 = BigUInt(hex: String(repeating: "f", count: 64))!
        XCTAssertEqual(max256.description, "115792089237316195423570985008687907853269984665640564039457584007913129639935")
        XCTAssertEqual(BigUInt(decimal: max256.description), max256)
    }

    func testArithmetic() {
        XCTAssertEqual((BigUInt(21_000) * BigUInt(30_000_000_000)).description, "630000000000000")
        XCTAssertEqual((BigUInt(UInt64.max) + BigUInt(1)).hexString, "10000000000000000")
        XCTAssertTrue(BigUInt(5) < BigUInt(hex: "0x100000000")!)
        XCTAssertEqual(BigUInt(25_200).divided(bySmall: 5).quotient, BigUInt(5_040))
    }

    func testParseEther() {
        XCTAssertEqual(Ether.parse("1.5")?.description, "1500000000000000000")
        XCTAssertEqual(Ether.parse("0,01")?.description, "10000000000000000")
        XCTAssertEqual(Ether.parse(".5")?.description, "500000000000000000")
        XCTAssertEqual(Ether.parse("0.000000000000000001")?.description, "1")
        XCTAssertNil(Ether.parse("0.0000000000000000001"))
        XCTAssertNil(Ether.parse("-1"))
        XCTAssertNil(Ether.parse("1e18"))
        XCTAssertNil(Ether.parse("1.2.3"))
        XCTAssertNil(Ether.parse("."))
        XCTAssertNil(Ether.parse(""))
        XCTAssertNil(Ether.parse("١"))
    }

    func testFormatEther() {
        XCTAssertEqual(Ether.format(BigUInt(decimal: "1500000000000000000")!), "1.5")
        XCTAssertEqual(Ether.format(.zero), "0")
        XCTAssertEqual(Ether.format(BigUInt(1), maxFractionDigits: 18), "0.000000000000000001")
        XCTAssertEqual(Ether.format(BigUInt(decimal: "123000000000000000000")!), "123")
    }
}

final class AddressTests: XCTestCase {
    func testChecksumValidation() throws {
        let checksummed = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        XCTAssertEqual(try WalletService.validatedAddress(checksummed), checksummed)
        XCTAssertEqual(try WalletService.validatedAddress(checksummed.lowercased()), checksummed)
        // One letter's case flipped: checksum must fail.
        XCTAssertThrowsError(try WalletService.validatedAddress("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD"))
        XCTAssertThrowsError(try WalletService.validatedAddress("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeA"))
        XCTAssertThrowsError(try WalletService.validatedAddress("vitalik.eth"))
    }

    func testKnownDerivation() throws {
        // Hardhat/Anvil default mnemonic, account 0 at m/44'/60'/0'/0/0.
        let seed = Data("test test test test test test test test test test test junk".utf8)
        XCTAssertEqual(try WalletService.address(fromSeed: seed), "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
    }

    func testGeneratedMnemonicIs24Words() {
        let phrase = WalletService.generateMnemonic()
        XCTAssertEqual(phrase.split(separator: " ").count, 24)
        XCTAssertTrue(WalletService.isValid(mnemonic: phrase))
        XCTAssertNotEqual(phrase, WalletService.generateMnemonic())
    }
}
