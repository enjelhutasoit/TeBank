import Foundation

/// Records synthetic fixture choices only. The envelope version belongs to the store.
public struct OnboardingCheckpoint: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public enum ReviewStatus: String, Codable, Sendable {
        case pending, requiresAction, approved
    }

    public enum Progress: Codable, Equatable, Sendable {
        case draft(consent: Bool, identitySample: Bool, selfieSample: Bool)
        /// Persist this state before contacting the mock authority.
        case submitting(requestID: UUID)
        case reviewed(requestID: UUID, status: ReviewStatus)
    }

    public let progress: Progress

    public init(progress: Progress = .draft(consent: false, identitySample: false, selfieSample: false)) {
        self.progress = progress
    }
}
