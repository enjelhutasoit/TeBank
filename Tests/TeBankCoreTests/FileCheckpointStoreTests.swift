import Foundation
import XCTest
import TeBankCore

final class FileCheckpointStoreTests: XCTestCase {
    private func freshURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("onboarding.json")
    }

    func testMissingFileAndRecoveryAfterReplacingDraft() async throws {
        let url = try freshURL().appendingPathComponent("checkpoint.json")
        let store = FileCheckpointStore(url: url)
        let missing = try await store.load()
        XCTAssertNil(missing)

        let submitted = OnboardingCheckpoint(progress: .submitting(requestID: UUID()))
        try await store.save(OnboardingCheckpoint())
        try await store.save(submitted)

        let recovered = try await FileCheckpointStore(url: url).load()
        XCTAssertEqual(recovered, submitted)
    }

    func testReadsVersionOneSubmittingRecord() async throws {
        let url = try freshURL()
        let id = UUID()
        let fixture = """
        {"version":1,"checkpoint":{"progress":{"submitting":{"requestID":"\(id.uuidString)"}}}}
        """
        try Data(fixture.utf8).write(to: url)

        let recovered = try await FileCheckpointStore(url: url).load()
        XCTAssertEqual(recovered, OnboardingCheckpoint(progress: .submitting(requestID: id)))
    }

    func testDamagedAndUnknownRecordsAreDistinguishedAndPreserved() async throws {
        let url = try freshURL()
        let cases: [(String, CheckpointReadError)] = [
            ("{", .corrupt),
            (#"{"version":1,"checkpoint":{}}"#, .corrupt),
            (#"{"version":2,"futurePayload":[]}"#, .unsupportedVersion(2))
        ]

        for (json, expected) in cases {
            let bytes = Data(json.utf8)
            try bytes.write(to: url)
            do {
                _ = try await FileCheckpointStore(url: url).load()
                XCTFail("Expected a read error for " + json)
            } catch let error as CheckpointReadError {
                XCTAssertEqual(error, expected)
            }
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
}
