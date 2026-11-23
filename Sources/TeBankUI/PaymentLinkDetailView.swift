import SwiftUI
import TeBankCore

struct PaymentLinkDetailView: View {
    let link: PaymentLink

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Ringkasan") {
                LabeledContent("Judul", value: link.request.title)
                LabeledContent("Nominal", value: rupiah(link.request.amountRupiah))
            }
        }
        .navigationTitle("Detail link pembayaran")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Selesai") { dismiss() }
            }
        }
    }
}
