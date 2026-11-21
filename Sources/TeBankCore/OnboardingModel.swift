import Foundation
import Observation

@MainActor @Observable
public final class OnboardingModel {
    public enum Issue: Equatable {
        case checkpoint, offline, maintenance, unresolved, missingRequest, unavailable
    }

    /// Only closed event names leave the model. No payload can contain a request ID.
    public enum Event: String, Sendable {
        case intentSaved, statusChecked, decisionSaved, interrupted, demoReset, samplesReplaced
    }

    public private(set) var events: [Event] = []

    private func record(_ event: Event) {
        events.append(event)
        if events.count > 30 { events.removeFirst() }
    }

    private enum Activity { case idle, loading, writing, contacting }
    private var activity: Activity = .idle
    private var generation = UUID()
    private let store: any CheckpointStore
    private let service: any OnboardingService

    public private(set) var progress: OnboardingCheckpoint.Progress?
    public private(set) var issue: Issue?
    public var isBusy: Bool { activity != .idle }
    public var canReset: Bool { progress != nil && (activity == .idle || activity == .contacting) }

    public init(store: any CheckpointStore, service: any OnboardingService) {
        self.store = store
        self.service = service
    }

    /// A read failure keeps the model unloaded and prevents overwriting the file.
    public func restore() async {
        guard progress == nil, !isBusy else { return }
        activity = .loading
        do {
            progress = try await store.load()?.progress ?? OnboardingCheckpoint().progress
            issue = nil
        } catch {
            issue = .checkpoint
        }
        activity = .idle
        if case .submitting = progress { await refresh() }
    }

    public func updateDraft(consent: Bool, identitySample: Bool, selfieSample: Bool) async {
        guard case .draft = progress, !isBusy else { return }
        _ = await save(.draft(consent: consent, identitySample: identitySample, selfieSample: selfieSample))
    }

    public func submit() async {
        guard !isBusy, !Task.isCancelled else { return }
        let id: UUID
        switch progress {
        case .draft(true, true, true):
            id = UUID()
            guard await save(.submitting(requestID: id)) else { return }
            record(.intentSaved)
        case .submitting(let existing) where issue == .missingRequest:
            id = existing
        default:
            return
        }
        await contact(id: id) { try await self.service.submit(requestID: id) }
    }

    public func refresh() async {
        guard !isBusy else { return }
        let id: UUID
        switch progress {
        case .submitting(let key), .reviewed(let key, _): id = key
        default: return
        }
        record(.statusChecked)
        await contact(id: id) { try await self.service.status(requestID: id) }
    }

    public func replaceSamples() async {
        guard case .reviewed(let id, .requiresAction) = progress, !isBusy else { return }
        await contact(id: id) { try await self.service.replaceSamples(requestID: id) }
        if case .reviewed(id, .pending) = progress, issue == nil { record(.samplesReplaced) }
    }

    public func reset() async {
        guard canReset else { return }
        generation = UUID()
        if await save(OnboardingCheckpoint().progress) { record(.demoReset) }
    }

    private func contact(id: UUID, operation: () async throws -> OnboardingCheckpoint.ReviewStatus) async {
        let token = generation
        activity = .contacting
        issue = nil
        defer { if generation == token { activity = .idle } }
        do {
            try Task.checkCancellation()
            let status = try await operation()
            guard generation == token else { return }
            try Task.checkCancellation()
            if await save(.reviewed(requestID: id, status: status)) { record(.decisionSaved) }
        } catch {
            guard generation == token else { return }
            record(.interrupted)
            switch error {
            case OnboardingServiceError.offline: issue = .offline
            case OnboardingServiceError.maintenance: issue = .maintenance
            case OnboardingServiceError.notFound: issue = .missingRequest
            case OnboardingServiceError.storageUnavailable: issue = .unavailable
            default: issue = .unresolved
            }
        }
    }

    private func save(_ next: OnboardingCheckpoint.Progress) async -> Bool {
        activity = .writing
        defer { activity = .idle }
        do {
            try await store.save(OnboardingCheckpoint(progress: next))
            progress = next
            issue = nil
            return true
        } catch {
            issue = .checkpoint
            return false
        }
    }
}
