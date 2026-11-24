import Foundation
import TransferCore
import TransferDomain
import TransferPersistence
import TransferSimulation

public enum LocalTransferStatus: Sendable, Equatable {
    case pending, accepted, settled, rejected

    init(_ state: TransferState) {
        switch state {
        case .created, .submitting, .unknown: self = .pending
        case .accepted: self = .accepted
        case .settled: self = .settled
        case .rejected: self = .rejected
        }
    }
}

public protocol LocalTransferService: Sendable {
    func submit() async throws -> LocalTransferStatus
    func checkStatus() async throws -> LocalTransferStatus
}

/// One immutable, reviewed request per session. Both operations use the same SDK journal.
public struct DemoLocalTransferService: LocalTransferService {
    private let request: LocalTransfer
    private let coordinator: TransferCoordinator
    private let reconciliation: TransferReconciliationService

    public init(request: LocalTransfer, storeURL: URL, loseResponse: Bool) throws {
        let key = UUID()
        let bank = SimulatedBank(faults: loseResponse ? [key: .timeoutAfterCommit] : [:])
        let journal = try CoreDataTransferJournal(storeURL: storeURL)
        self.request = request
        coordinator = TransferCoordinator(journal: journal, gateway: bank, makeIdempotencyKey: { key })
        reconciliation = TransferReconciliationService(
            journal: journal, gateway: bank, policy: try ReconciliationPolicy(maximumAttempts: 1)
        )
    }

    public func submit() async throws -> LocalTransferStatus {
        LocalTransferStatus(try await coordinator.submit(request.intent))
    }

    public func checkStatus() async throws -> LocalTransferStatus {
        switch try await reconciliation.reconcile(intentID: request.id) {
        case let .confirmed(state, _): LocalTransferStatus(state)
        case .unresolved: .pending
        }
    }
}
