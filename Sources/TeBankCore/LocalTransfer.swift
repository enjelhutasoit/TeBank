import Foundation
import TransferDomain

/// The recipient and amount are fixed when the user reviews a demo transfer.
public struct LocalTransfer: Equatable, Sendable, Identifiable {
    public enum ValidationError: Error { case invalidRecipient, invalidAmount }

    public let id: UUID
    public let beneficiary: String
    public let bank: String
    public let account: String
    public let rupiah: Int64
    let intent: TransferIntent

    public init(beneficiary: String, bank: String, account: String, rupiah: Int64) throws {
        let name = beneficiary.trimmingCharacters(in: .whitespacesAndNewlines)
        let bank = bank.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !bank.isEmpty, !account.isEmpty,
              account.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw ValidationError.invalidRecipient
        }
        let (units, overflow) = rupiah.multipliedReportingOverflow(by: 100)
        guard rupiah > 0, !overflow else { throw ValidationError.invalidAmount }
        let id = UUID()
        self.id = id
        self.beneficiary = name
        self.bank = bank
        self.account = account
        self.rupiah = rupiah
        intent = TransferIntent(id: id, amount: try Money(minorUnits: units, currencyCode: "IDR", scale: 2))
    }
}
