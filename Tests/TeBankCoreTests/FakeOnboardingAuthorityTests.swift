import Foundation
import TeBankCore
import XCTest

final class FakeOnboardingAuthorityTests: XCTestCase {
    private func makeDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    func testLostResponseCanBeReconciledAfterRestartAndRetryPreservesOriginalDecision() async throws {
        let directory = try makeDirectory()
        let id = UUID()
        let first = FakeOnboardingAuthority(directory: directory)
        await first.setScenario(.loseSubmissionResponse)
        do {
            _ = try await first.submit(requestID: id)
            XCTFail("Expected an unknown outcome")
        } catch let error as OnboardingServiceError {
            XCTAssertEqual(error, .unknownOutcome)
        }

        let restarted = FakeOnboardingAuthority(directory: directory)
        let recovered = try await restarted.status(requestID: id)
        XCTAssertEqual(recovered, .pending)

        await restarted.setScenario(.requireAction)
        async let retryA = restarted.submit(requestID: id)
        async let retryB = restarted.submit(requestID: id)
        let results = try await [retryA, retryB]
        XCTAssertEqual(results, [.pending, .pending])
        let independent = try await restarted.submit(requestID: UUID())
        XCTAssertEqual(independent, .requiresAction)
    }

    func testAvailabilityFailuresLeaveNoRecord() async throws {
        let authority = FakeOnboardingAuthority(directory: try makeDirectory())
        let cases: [(FakeOnboardingAuthority.Scenario, OnboardingServiceError)] = [
            (.offline, .offline), (.maintenance, .maintenance)
        ]
        for (scenario, expected) in cases {
            let id = UUID()
            await authority.setScenario(scenario)
            do {
                _ = try await authority.submit(requestID: id)
                XCTFail("Expected submission to fail")
            } catch let error as OnboardingServiceError {
                XCTAssertEqual(error, expected)
            }
            await authority.setScenario(.normal)
            do {
                _ = try await authority.status(requestID: id)
                XCTFail("Failed submission must leave no record")
            } catch let error as OnboardingServiceError {
                XCTAssertEqual(error, .notFound)
            }
        }
    }

    func testDamagedDecisionCannotBeReplacedByRetry() async throws {
        let root = try makeDirectory()
        let authority = FakeOnboardingAuthority(directory: root)
        let id = UUID()
        _ = try await authority.submit(requestID: id)
        let record = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        let damaged = Data("invalid".utf8)
        try damaged.write(to: record)
        do {
            _ = try await authority.submit(requestID: id)
            XCTFail("Expected an unreadable record to block submission")
        } catch let error as OnboardingServiceError {
            XCTAssertEqual(error, .storageUnavailable)
        }
        XCTAssertEqual(try Data(contentsOf: record), damaged)
    }
}
