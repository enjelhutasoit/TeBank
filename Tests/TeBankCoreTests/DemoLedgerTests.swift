import TeBankCore
import XCTest

final class DemoLedgerTests: XCTestCase {
    func testSampleBalanceIncludesCreditsAndDebits() {
        let ledger = DemoLedger.sample
        XCTAssertEqual(ledger.balance, 7_850_000)
        XCTAssertTrue(ledger.entries.contains { $0.amount > 0 })
        XCTAssertTrue(ledger.entries.contains { $0.amount < 0 })
        XCTAssertEqual(Set(ledger.entries.map(\.id)).count, ledger.entries.count)
    }
}
