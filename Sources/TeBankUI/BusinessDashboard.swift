import SwiftUI
import TeBankCore
import VaneKit

struct BusinessDashboard: View {
    let ledger: DemoLedger

    @Environment(\.vaneTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saldo simulasi")
                        .font(.subheadline)
                    Text(rupiah(ledger.balance))
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                        .accessibilityIdentifier("dashboard.balance")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            }
            .listRowBackground(theme.color(.surface, for: scheme))

            Section("Aktivitas terbaru") {
                ForEach(ledger.entries) { entry in
                    NavigationLink {
                        TransactionDetail(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title).font(.headline)
                            Text(entry.note).foregroundStyle(.secondary)
                            Text(rupiah(entry.amount)).monospacedDigit()
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityLabel(Text("\(entry.title), \(entry.note), \(entry.amount < 0 ? "Keluar" : "Masuk") \(rupiah(entry.amount))"))
                    .accessibilityIdentifier("transaction.\(entry.id)")
                    .listRowBackground(theme.color(.surface, for: scheme))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.color(.background, for: scheme))
        .navigationTitle("Dashboard bisnis")
    }
}

private struct TransactionDetail: View {
    let entry: DemoLedger.Entry

    var body: some View {
        Form {
            Section("Transaksi sintetis") {
                LabeledContent("Jenis", value: entry.amount < 0 ? "Keluar" : "Masuk")
                LabeledContent("Jumlah", value: rupiah(entry.amount))
                LabeledContent("Mitra", value: entry.note)
            }
            Section("Referensi demo") {
                Text(entry.id)
                    .accessibilityIdentifier("transaction.detail.reference")
            }
        }
        .navigationTitle(entry.title)
    }
}

private func rupiah(_ amount: Int64) -> String {
    amount.formatted(.currency(code: "IDR").precision(.fractionLength(0)).locale(Locale(identifier: "id_ID")))
}
