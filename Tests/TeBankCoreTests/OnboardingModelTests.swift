import Foundation
import XCTest
import TeBankCore

@MainActor
final class OnboardingModelTests: XCTestCase {
    func testEveryMissingPrerequisiteBlocksSubmission() async {
        for missing in 0..<3 {
            let store = FakeCheckpointStore()
            let service = PausedOnboardingService(pause: false)
            let model = OnboardingModel(store: store, service: service)
            await model.restore()
            await model.updateDraft(consent: missing != 0, identitySample: missing != 1, selfieSample: missing != 2)
            await model.submit()
            let calls = await service.submissions
            XCTAssertEqual(calls, 0)
        }
    }

    func testFailedIntentWriteStopsSubmission() async {
        let store = FakeCheckpointStore()
        let service = PausedOnboardingService(pause: false)
        let model = await readyModel(store, service)
        await store.failWrites()
        await model.submit()
        let calls = await service.submissions
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.issue, .checkpoint)
    }

    func testLostResponseIsRecoveredUsingPersistedIDAfterRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("client.json")
        let directory = root.appendingPathComponent("authority")
        let first = FakeOnboardingAuthority(directory: directory)
        let model = await readyModel(FileCheckpointStore(url: url), first)
        await first.setScenario(.loseSubmissionResponse)
        await model.submit()
        guard case .submitting(let id) = model.progress else { return XCTFail("Expected durable intent") }
        XCTAssertEqual(model.issue, .unresolved)
        let restarted = OnboardingModel(store: FileCheckpointStore(url: url), service: FakeOnboardingAuthority(directory: directory))
        await restarted.restore()
        XCTAssertEqual(restarted.progress, .reviewed(requestID: id, status: .pending))
        let disk = try await FileCheckpointStore(url: url).load()
        XCTAssertEqual(disk?.progress, restarted.progress)
    }

    func testConfirmedMissingRequestIsRetriedWithOriginalID() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let authority = FakeOnboardingAuthority(directory: root)
        let model = await readyModel(FakeCheckpointStore(), authority)
        await authority.setScenario(.offline)
        await model.submit()
        guard case .submitting(let id) = model.progress else { return XCTFail("Expected original intent") }
        await authority.setScenario(.normal)
        await model.refresh()
        XCTAssertEqual(model.issue, .missingRequest)
        await model.submit()
        XCTAssertEqual(model.progress, .reviewed(requestID: id, status: .pending))
    }

    func testResetDuringSubmissionDiscardsLateSuccessAndDoubleTap() async throws {
        let store = FakeCheckpointStore()
        let service = PausedOnboardingService()
        let model = await readyModel(store, service)
        let submission = Task { await model.submit() }
        let id = await service.waitForRequest()
        let before = await store.load()
        XCTAssertEqual(before?.progress, .submitting(requestID: id))
        await model.submit()
        await model.reset()
        await service.finish()
        await submission.value
        let calls = await service.submissions
        let disk = await store.load()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(disk?.progress, OnboardingCheckpoint().progress)
        XCTAssertEqual(model.progress, disk?.progress)
    }

    func testCancellationAfterDispatchKeepsOriginalIntent() async {
        let store = FakeCheckpointStore()
        let service = PausedOnboardingService()
        let model = await readyModel(store, service)
        let submission = Task { await model.submit() }
        let id = await service.waitForRequest()
        submission.cancel()
        await service.finish()
        await submission.value
        XCTAssertEqual(model.progress, .submitting(requestID: id))
        XCTAssertFalse(model.isBusy)
        await model.refresh()
        XCTAssertEqual(model.progress, .reviewed(requestID: id, status: .pending))
    }

    func testSampleReplacementPersistsAndEventsExposeOnlyFixedNames() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let authority = FakeOnboardingAuthority(directory: root)
        let store = FakeCheckpointStore()
        let model = await readyModel(store, authority)
        await authority.setScenario(.requireAction)
        await model.submit()
        guard case .reviewed(let id, .requiresAction) = model.progress else {
            return XCTFail("Expected the demo authority to request new samples")
        }
        await model.replaceSamples()
        XCTAssertEqual(model.progress, .reviewed(requestID: id, status: .pending))
        let recovered = try await FakeOnboardingAuthority(directory: root).status(requestID: id)
        XCTAssertEqual(recovered, .pending)
        XCTAssertEqual(model.events.map(\.rawValue), ["intentSaved", "decisionSaved", "decisionSaved", "samplesReplaced"])
    }

    private func readyModel(_ store: any CheckpointStore, _ service: any OnboardingService) async -> OnboardingModel {
        let model = OnboardingModel(store: store, service: service)
        await model.restore()
        await model.updateDraft(consent: true, identitySample: true, selfieSample: true)
        return model
    }
}

private actor FakeCheckpointStore: CheckpointStore {
    private var value: OnboardingCheckpoint?
    private var failing = false
    func load() -> OnboardingCheckpoint? { value }
    func failWrites() { failing = true }
    func save(_ checkpoint: OnboardingCheckpoint) throws {
        if failing { throw CocoaError(.fileWriteOutOfSpace) }
        value = checkpoint
    }
}

private actor PausedOnboardingService: OnboardingService {
    private let pause: Bool
    init(pause: Bool = true) { self.pause = pause }

    private(set) var submissions = 0
    private var request: UUID?
    private var arrival: CheckedContinuation<UUID, Never>?
    private var completion: CheckedContinuation<Void, Never>?

    func waitForRequest() async -> UUID {
        if let request { return request }
        return await withCheckedContinuation { arrival = $0 }
    }

    func submit(requestID: UUID) async -> OnboardingCheckpoint.ReviewStatus {
        submissions += 1
        request = requestID
        arrival?.resume(returning: requestID)
        arrival = nil
        if pause { await withCheckedContinuation { completion = $0 } }
        return .pending
    }

    func finish() {
        completion?.resume()
        completion = nil
    }

    func replaceSamples(requestID: UUID) -> OnboardingCheckpoint.ReviewStatus { .pending }

    func status(requestID: UUID) -> OnboardingCheckpoint.ReviewStatus { .pending }
}
