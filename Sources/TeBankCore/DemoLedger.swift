import Foundation

public struct DemoLedger: Sendable {
    public struct Entry: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let note: String
        public let amount: Int64
    }

    public let openingBalance: Int64
    public let entries: [Entry]

    public var balance: Int64 {
        entries.reduce(openingBalance) { $0 + $1.amount }
    }

    public static let sample = DemoLedger(openingBalance: 5_000_000, entries: [
        Entry(id: "DEMO-003", title: "Pembayaran pesanan", note: "Toko Reka", amount: 1_200_000),
        Entry(id: "DEMO-002", title: "Pembelian kemasan", note: "Studio Kertas", amount: -425_000),
        Entry(id: "DEMO-001", title: "Pembayaran invoice", note: "Kedai Awan", amount: 2_075_000)
    ])
}
