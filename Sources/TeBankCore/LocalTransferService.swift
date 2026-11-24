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
    private let journal: CoreDataTransferJournal
    private let coordinator: TransferCoordinator
    private let reconciliation: TransferReconciliationService

    public init(request: LocalTransfer, storeURL: URL, loseResponse: Bool) throws {
        let bank = try DemoBankGateway(storeURL: storeURL.appendingPathExtension("bank.sqlite"),
                                       loseResponse: loseResponse)
        let journal = try CoreDataTransferJournal(storeURL: storeURL)
        self.journal = journal
        self.request = request
        coordinator = TransferCoordinator(journal: journal, gateway: bank)
        reconciliation = TransferReconciliationService(
            journal: journal, gateway: bank, policy: try ReconciliationPolicy(maximumAttempts: 1)
        )
    }

    public func submit() async throws -> LocalTransferStatus {
        LocalTransferStatus(try await coordinator.submit(request.intent))
    }

    /// A missing journal entry means submission never reached the gateway.
    public func restoredStatus() async throws -> LocalTransferStatus? {
        do {
            return try await checkStatus()
        } catch TransferReconciliationService.Failure.intentNotFound {
            return nil
        }
    }

    public func checkStatus() async throws -> LocalTransferStatus {
        // The SDK reconciles by ID and key. Check that the displayed amount belongs to that intent.
        guard let entry = try await journal.entry(for: request.id) else {
            throw TransferReconciliationService.Failure.intentNotFound
        }
        guard entry.intent == request.intent else { throw TransferOperationError.intentConflict }

        switch try await reconciliation.reconcile(intentID: request.id) {
        case let .confirmed(state, _): return LocalTransferStatus(state)
        case .unresolved: return .pending
        }
    }
}

private actor DemoBankGateway: TransferGateway, TransferStatusGateway {
    // A row in this separate store means the simulated bank accepted the request.
    private let accepted: CoreDataTransferJournal
    private var loseResponse: Bool

    init(storeURL: URL, loseResponse: Bool) throws {
        accepted = try CoreDataTransferJournal(storeURL: storeURL)
        self.loseResponse = loseResponse
    }

    func submit(_ transfer: JournaledTransfer) async throws -> TransferSubmissionResult {
        let dropReply = loseResponse
        loseResponse = false
        let receipt = try await accepted.record(transfer.intent, idempotencyKey: transfer.idempotencyKey)
        guard receipt == transfer else { throw SimulatedBankError.intentConflict }
        if dropReply { throw SimulatedBankError.timedOut }
        return .accepted
    }

    func status(for intentID: UUID, idempotencyKey: UUID) async throws -> TransferStatusResponse {
        guard let receipt = try await accepted.entry(for: intentID),
              receipt.idempotencyKey == idempotencyKey else {
            return TransferStatusResponse(intentID: intentID, idempotencyKey: idempotencyKey, status: .notFound)
        }
        return TransferStatusResponse(
            intentID: intentID, idempotencyKey: idempotencyKey, status: .accepted,
            version: TransferStatusVersion(rawValue: 1)
        )
    }
}
