import Foundation

public protocol PaymentLinkService: Sendable {
    func create(_ request: PaymentLinkRequest, idempotencyKey: UUID) async throws -> PaymentLink
    func find(id: UUID) async throws -> PaymentLink?
}

/// Stores synthetic payment links for the lifetime of this service instance.
public actor FakePaymentLinkService: PaymentLinkService {
    private let now: @Sendable () -> Date
    private var linkIDsByKey: [UUID: UUID] = [:]
    private var linksByID: [UUID: PaymentLink] = [:]

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
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
        return link
    }

    public func find(id: UUID) async throws -> PaymentLink? {
        linksByID[id]
    }
}
