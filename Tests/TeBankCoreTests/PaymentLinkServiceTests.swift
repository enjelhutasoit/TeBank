import Foundation
import XCTest
@testable import TeBankCore

@MainActor
final class PaymentLinkServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testConcurrentRetriesReturnTheSameLink() async throws {
        let now = self.now
        let service = FakePaymentLinkService(now: { now })
        let request = try makeRequest(expiresAt: now.addingTimeInterval(60))
        let key = UUID()

        async let first = service.create(request, idempotencyKey: key)
        async let second = service.create(request, idempotencyKey: key)
        let (created, replayed) = try await (first, second)

        XCTAssertEqual(created, replayed)
        XCTAssertEqual(created.shareURL?.host, "pay.tebank.invalid")
        let fetched = try await service.find(id: created.id)
        XCTAssertEqual(fetched, created)
    }

    func testReusingAKeyForADifferentRequestReportsAConflict() async throws {
        let now = self.now
        let service = FakePaymentLinkService(now: { now })
        let key = UUID()
        let expiration = now.addingTimeInterval(60)
        let request = try makeRequest(expiresAt: expiration)
        let created = try await service.create(request, idempotencyKey: key)
        let changed = try makeRequest(amountRupiah: 75_000, expiresAt: expiration)

        do {
            _ = try await service.create(changed, idempotencyKey: key)
            XCTFail("Expected reuse with a different amount to fail")
        } catch let error as PaymentLinkError {
            XCTAssertEqual(error, .idempotencyConflict)
        }

        let replayed = try await service.create(request, idempotencyKey: key)
        XCTAssertEqual(replayed, created)
    }

    func testLinksExpireAtTheDeadlineAndExpiredRequestsDoNotReserveTheKey() async throws {
        let now = self.now
        let service = FakePaymentLinkService(now: { now })
        let key = UUID()
        let expired = try makeRequest(expiresAt: now)

        do {
            _ = try await service.create(expired, idempotencyKey: key)
            XCTFail("Expected a request at its expiration deadline to fail")
        } catch let error as PaymentLinkError {
            XCTAssertEqual(error, .expired)
        }

        let deadline = now.addingTimeInterval(60)
        let valid = try makeRequest(expiresAt: deadline)
        let link = try await service.create(valid, idempotencyKey: key)
        XCTAssertEqual(link.status(at: deadline.addingTimeInterval(-1)), .active)
        XCTAssertEqual(link.status(at: deadline), .expired)
    }

    func testLostResponseRetryRecoversTheRecordedPayment() async throws {
        let instant = now
        let service = FakePaymentLinkService(loseNextCreateResponse: true, now: { instant })
        let request = try makeRequest(expiresAt: instant.addingTimeInterval(60))
        let key = UUID()
        do {
            _ = try await service.create(request, idempotencyKey: key)
            XCTFail("Expected the simulated response loss")
        } catch let error as PaymentLinkDemoError {
            XCTAssertEqual(error, .responseLost)
        }

        let committed = await service.allLinks()
        XCTAssertEqual(committed.count, 1)
        let recovered = try await service.create(request, idempotencyKey: key)
        XCTAssertEqual(committed.first, recovered)
        let paid = try await service.simulatePayment(id: recovered.id)
        let repeated = try await service.simulatePayment(id: recovered.id)
        let refreshed = try await service.find(id: recovered.id)
        let replay = try await service.create(request, idempotencyKey: key)
        XCTAssertEqual(paid.status(at: request.expiresAt), .paid)
        XCTAssertEqual(paid.paidAt, instant)
        XCTAssertEqual(refreshed, paid)
        XCTAssertEqual(repeated, paid)
        XCTAssertEqual(replay, paid)
    }

    private func makeRequest(amountRupiah: Int64 = 50_000, expiresAt: Date) throws -> PaymentLinkRequest {
        try PaymentLinkRequest(title: "Pesanan demo", amountRupiah: amountRupiah, expiresAt: expiresAt)
    }
}
