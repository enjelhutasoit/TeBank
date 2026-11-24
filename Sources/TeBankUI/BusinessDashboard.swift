import SwiftUI
import TeBankCore
import VaneKit

struct BusinessDashboard: View {
    let transfers: LocalTransferModel
    let ledger: DemoLedger
    let paymentLinks: any PaymentLinkDemoService

    @State private var links: [PaymentLink] = []

    @Environment(\.vaneTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saldo simulasi")
                        .font(.subheadline)
                    Text(rupiah(ledger.balance))
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal)
                .background(theme.color(.surface, for: scheme), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Saldo simulasi"))
                .accessibilityValue(Text("\(ledger.balance.formatted(.number.locale(Locale(identifier: "id_ID")))) rupiah"))
                .accessibilityIdentifier("dashboard.balance")

                NavigationLink("Buat link pembayaran") {
                    CreatePaymentLinkView(service: paymentLinks)
                }
                .buttonStyle(.bordered)

                ForEach(links) { link in
                    NavigationLink {
                        PaymentLinkDetailView(link: link, service: paymentLinks)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(link.request.title)
                            Text(rupiah(link.request.amountRupiah)).font(.subheadline)
                        }
                    }
                }

                NavigationLink("Transfer lokal") { LocalTransferScreen(model: transfers) }
                    .buttonStyle(.bordered)

                NavigationLink("Riwayat transfer") { TransferHistoryView(store: transfers.checkpoint) }
                    .buttonStyle(.bordered)

                Text("Aktivitas terbaru").font(.headline).accessibilityAddTraits(.isHeader)
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
                    .accessibilityLabel(transactionLabel(for: entry))
                    .accessibilityIdentifier("transaction.\(entry.id)")
                    .buttonStyle(.plain)
                }
            }
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
        }
        .background(theme.color(.background, for: scheme))
        .task { links = await paymentLinks.allLinks() }
        .navigationTitle("Dashboard bisnis")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func transactionLabel(for entry: DemoLedger.Entry) -> Text {
        let direction = entry.amount < 0 ? "Keluar" : "Masuk"
        let amount = entry.amount.magnitude.formatted(.number.locale(Locale(identifier: "id_ID")))
        return Text("\(entry.title), \(entry.note), \(direction), \(amount) rupiah")
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
        .navigationTitle("Detail transaksi")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

func rupiah(_ amount: Int64) -> String {
    amount.formatted(.currency(code: "IDR").precision(.fractionLength(0)).locale(Locale(identifier: "id_ID")))
}

private struct TransferHistoryView: View {
    let store: LocalTransferCheckpointStore
    @State private var transfers: [LocalTransfer]?
    @State private var failed = false

    var body: some View {
        Group {
            if failed {
                VStack {
                    Text("Riwayat transfer belum dapat dimuat.")
                    Button("Coba lagi") { Task { await load() } }
                }
            } else if let transfers {
                if transfers.isEmpty {
                    Text("Belum ada transfer yang diarsipkan.")
                } else {
                    List(transfers) { transfer in
                        VStack(alignment: .leading) {
                            Text(transfer.beneficiary).font(.headline)
                            Text("\(transfer.bank) · \(transfer.account)")
                            Text(rupiah(transfer.rupiah))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                ProgressView("Memuat riwayat")
            }
        }
        .navigationTitle("Riwayat transfer")
        .task { await load() }
    }

    @MainActor
    private func load() async {
        failed = false
        do {
            let store = self.store
            transfers = try await Task.detached { try store.archivedTransfers() }.value
        } catch {
            failed = true
        }
    }
}
