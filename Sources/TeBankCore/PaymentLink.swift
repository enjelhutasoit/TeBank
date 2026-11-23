import Foundation

public struct PaymentLinkRequest: Equatable, Sendable {
    public let title: String
    public let amountRupiah: Int64
    public let expiresAt: Date

    public init(title: String, amountRupiah: Int64, expiresAt: Date) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw PaymentLinkError.emptyTitle }
        guard amountRupiah > 0 else { throw PaymentLinkError.invalidAmount }
        self.title = title
        self.amountRupiah = amountRupiah
        self.expiresAt = expiresAt
    }
}

public enum PaymentLinkError: Error, Equatable, Sendable {
    case emptyTitle
    case invalidAmount
    case expired
    case idempotencyConflict
}

public struct PaymentLink: Equatable, Identifiable, Sendable {
    public enum Status: Equatable, Sendable {
        case active
        case expired
        case paid
    }

    public let id: UUID
    public let request: PaymentLinkRequest
    public let createdAt: Date
    public let paidAt: Date?

    init(id: UUID, request: PaymentLinkRequest, createdAt: Date, paidAt: Date? = nil) {
        self.id = id
        self.request = request
        self.createdAt = createdAt
        self.paidAt = paidAt
    }

    /// A synthetic address for the demo.
    public var shareURL: URL? {
        URL(string: "https://pay.tebank.invalid/links/\(id.uuidString.lowercased())")
    }

    public func status(at date: Date) -> Status {
        if let paidAt, paidAt <= date { return .paid }
        return date >= request.expiresAt ? .expired : .active
    }
}
