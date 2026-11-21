import Foundation

/// Local simulator for a remote authority. Use a dedicated directory and one writer per directory.
public actor FakeOnboardingAuthority: OnboardingService {
    public enum Scenario: Sendable {
        case normal, offline, maintenance, loseSubmissionResponse, requireAction
    }

    private let directory: URL
    private var scenario: Scenario = .normal

    public init(directory: URL) {
        self.directory = directory
    }

    /// Only the demo controller sees these controls.
    public func setScenario(_ scenario: Scenario) {
        self.scenario = scenario
    }

    public func submit(requestID: UUID) throws -> OnboardingCheckpoint.ReviewStatus {
        try checkAvailability()
        if let existing = try read(requestID) { return existing }

        let result: OnboardingCheckpoint.ReviewStatus = scenario == .requireAction ? .requiresAction : .pending
        try write(result, for: requestID)
        if scenario == .loseSubmissionResponse {
            throw OnboardingServiceError.unknownOutcome
        }
        return result
    }

    public func status(requestID: UUID) throws -> OnboardingCheckpoint.ReviewStatus {
        try checkAvailability()
        guard let result = try read(requestID) else { throw OnboardingServiceError.notFound }
        return result
    }

    public func replaceSamples(requestID: UUID) throws -> OnboardingCheckpoint.ReviewStatus {
        let existing = try status(requestID: requestID)
        guard existing == .requiresAction else { return existing }
        try write(.pending, for: requestID)
        if scenario == .loseSubmissionResponse { throw OnboardingServiceError.unknownOutcome }
        return .pending
    }

    /// This control belongs to the synthetic demo lab, outside the client protocol.
    public func approveForDemo(requestID: UUID) throws {
        guard let existing = try read(requestID) else { throw OnboardingServiceError.notFound }
        guard existing == .pending else { return }
        try write(.approved, for: requestID)
    }

    private func write(_ status: OnboardingCheckpoint.ReviewStatus, for requestID: UUID) throws {
        do {
            let data = try JSONEncoder().encode(status)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: url(for: requestID), options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: url(for: requestID), options: .atomic)
            #endif
        } catch {
            throw OnboardingServiceError.storageUnavailable
        }
    }

    private func checkAvailability() throws {
        try Task.checkCancellation()
        switch scenario {
        case .offline: throw OnboardingServiceError.offline
        case .maintenance: throw OnboardingServiceError.maintenance
        default: break
        }
    }

    private func url(for requestID: UUID) -> URL {
        directory.appendingPathComponent(requestID.uuidString).appendingPathExtension("json")
    }

    private func read(_ id: UUID) throws -> OnboardingCheckpoint.ReviewStatus? {
        do {
            let data = try Data(contentsOf: url(for: id))
            return try JSONDecoder().decode(OnboardingCheckpoint.ReviewStatus.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            throw OnboardingServiceError.storageUnavailable
        }
    }
}
