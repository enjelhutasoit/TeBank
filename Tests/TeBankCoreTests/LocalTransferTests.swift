import Foundation
import TransferPersistence
import XCTest
@testable import TeBankCore

@MainActor
final class LocalTransferTests: XCTestCase {
    private func request(amount: Int64 = 12_500, account: String = "0017") throws -> LocalTransfer {
        try LocalTransfer(beneficiary: " Demo ", bank: "Bank demo", account: account, rupiah: amount)
    }

    func testReviewedCheckpointBeforeJournalWriteRequiresConfirmation() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let reviewed = try request()
        let checkpoint = LocalTransferCheckpointStore(directory: directory)
        try checkpoint.save(reviewed)
        let recovered = try XCTUnwrap(checkpoint.load())
        let service = try DemoLocalTransferService(
            request: recovered, storeURL: directory.appendingPathComponent("journal.sqlite"), loseResponse: false
        )
        let status = try await service.restoredStatus()
        XCTAssertNil(status)
        XCTAssertEqual(recovered, reviewed)
        try checkpoint.clear()
        XCTAssertNil(try checkpoint.load())
    }

    func testValidationPreservesLeadingZerosAndConvertsRupiahExactly() throws {
        let value = try request()
        XCTAssertEqual(value.account, "0017")
        XCTAssertEqual(value.beneficiary, "Demo")
        XCTAssertEqual(value.intent.amount.minorUnits, 1_250_000)
        for amount: Int64 in [0, -1, .max] { XCTAssertThrowsError(try request(amount: amount)) }
        for account in ["", "12A", "１"] { XCTAssertThrowsError(try request(account: account)) }
    }

    func testFreshStoreRestoresLatestReviewedTransferAndOriginalIntent() throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalTransferCheckpointStore(directory: directory)
        XCTAssertNil(try store.load())

        let original = try request()
        try store.save(original)
        let reopened = LocalTransferCheckpointStore(directory: directory)
        XCTAssertEqual(try reopened.load(), original)

        let replacement = try request(amount: 500, account: "0004")
        try reopened.save(replacement)
        XCTAssertEqual(try store.load(), replacement)
    }

    func testInvalidStoredAmountFailsRecovery() throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalTransferCheckpointStore(directory: directory)
        try store.save(request())
        let file = directory.appendingPathComponent("reviewed-transfer.json")
        let data = try Data(contentsOf: file)
        var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        fields["rupiah"] = 0
        try JSONSerialization.data(withJSONObject: fields).write(to: file)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? LocalTransfer.ValidationError, .invalidAmount)
        }
    }

    func testFreshServiceRecoversBankAcceptanceAfterLostResponse() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journalURL = directory.appendingPathComponent("journal.sqlite")
        let reviewed = try request()
        do {
            let first = try DemoLocalTransferService(request: reviewed, storeURL: journalURL, loseResponse: true)
            let result = try await first.submit()
            XCTAssertEqual(result, .pending)
        }

        let reopened = try DemoLocalTransferService(request: reviewed, storeURL: journalURL, loseResponse: false)
        let recovered = try await reopened.restoredStatus()
        XCTAssertEqual(recovered, .accepted)
    }

    func testClientJournalAloneDoesNotConfirmBankAcceptance() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journalURL = directory.appendingPathComponent("journal.sqlite")
        let reviewed = try request()
        let journal = try CoreDataTransferJournal(storeURL: journalURL)
        _ = try await journal.record(reviewed.intent, idempotencyKey: UUID())

        let reopened = try DemoLocalTransferService(request: reviewed, storeURL: journalURL, loseResponse: false)
        let recovered = try await reopened.restoredStatus()
        XCTAssertEqual(recovered, .pending)
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
