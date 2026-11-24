import Foundation
import XCTest
@testable import TeBankCore

@MainActor
final class LocalTransferTests: XCTestCase {
    private func request(amount: Int64 = 12_500, account: String = "0017") throws -> LocalTransfer {
        try LocalTransfer(beneficiary: " Demo ", bank: "Bank demo", account: account, rupiah: amount)
    }

    func testValidationPreservesLeadingZerosAndConvertsRupiahExactly() throws {
        let value = try request()
        XCTAssertEqual(value.account, "0017")
        XCTAssertEqual(value.beneficiary, "Demo")
        XCTAssertEqual(value.intent.amount.minorUnits, 1_250_000)
        for amount: Int64 in [0, -1, .max] { XCTAssertThrowsError(try request(amount: amount)) }
        for account in ["", "12A", "１"] { XCTAssertThrowsError(try request(account: account)) }
    }

    func testLostResponseIsReconciledAfterRepeatedSubmissionOfTheSameIntent() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = try DemoLocalTransferService(
            request: request(), storeURL: directory.appendingPathComponent("journal.sqlite"), loseResponse: true
        )
        let first = try await service.submit()
        let replay = try await service.submit()
        let recovered = try await service.checkStatus()
        XCTAssertEqual(first, .pending)
        XCTAssertEqual(replay, .pending)
        XCTAssertEqual(recovered, .accepted)
    }
}
