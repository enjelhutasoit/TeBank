import Foundation

public protocol PaymentLinkService: Sendable {
    func create(_ request: PaymentLinkRequest, idempotencyKey: UUID) async throws -> PaymentLink
    func find(id: UUID) async throws -> PaymentLink?
}

/// Demo-only controls are separate from the operations available to a payment client.
public protocol PaymentLinkDemoService: PaymentLinkService {
    func simulatePayment(id: UUID) async throws -> PaymentLink
}

public enum PaymentLinkDemoError: Error, Equatable {
    case responseLost
    case linkMissing
}

/// Stores synthetic payment links for the lifetime of this service instance.
public actor FakePaymentLinkService: PaymentLinkDemoService {
    private let now: @Sendable () -> Date
    private var linkIDsByKey: [UUID: UUID] = [:]
    private var linksByID: [UUID: PaymentLink] = [:]

    private var loseNextCreateResponse: Bool

    public init(loseNextCreateResponse: Bool = false, now: @escaping @Sendable () -> Date = { Date() }) {
        self.loseNextCreateResponse = loseNextCreateResponse
        self.now = now
    }

    public func create(_ request: PaymentLinkRequest, idempotencyKey: UUID) async throws -> PaymentLink {
        if let id = linkIDsByKey[idempotencyKey], let existing = linksByID[id] {
            guard existing.request == request else { throw PaymentLinkError.idempotencyConflict }
            return existing
        }

        let createdAt = now()
        guard request.expiresAt > createdAt else { throw PaymentLinkError.expired }
        let link = PaymentLink(id: UUID(), request: request, createdAt: createdAt)
        linksByID[link.id] = link
        linkIDsByKey[idempotencyKey] = link.id
        if loseNextCreateResponse {
            loseNextCreateResponse = false
            throw PaymentLinkDemoError.responseLost
        }
        return link
    }

    public func find(id: UUID) async throws -> PaymentLink? {
        linksByID[id]
    }

    public func simulatePayment(id: UUID) async throws -> PaymentLink {
        guard let link = linksByID[id] else { throw PaymentLinkDemoError.linkMissing }
        if link.paidAt != nil { return link }
        let receivedAt = now()
        guard receivedAt < link.request.expiresAt else { throw PaymentLinkError.expired }
        let paid = PaymentLink(id: id, request: link.request, createdAt: link.createdAt, paidAt: receivedAt)
        linksByID[id] = paid
        return paid
    }
}
