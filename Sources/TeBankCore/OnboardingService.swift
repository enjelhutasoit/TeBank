import Foundation

/// The caller persists the request ID before submitting and reuses it on retry.
public protocol OnboardingService: Sendable {
    func submit(requestID: UUID) async throws -> OnboardingCheckpoint.ReviewStatus
    func status(requestID: UUID) async throws -> OnboardingCheckpoint.ReviewStatus
}

public enum OnboardingServiceError: Error, Equatable, Sendable {
    case offline
    case maintenance
    /// The caller must reconcile using the original request ID.
    case unknownOutcome
    case notFound
    case storageUnavailable
}
