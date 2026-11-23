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
                LabeledContent("Kedaluwarsa", value: link.request.expiresAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let url = link.shareURL {
                Section {
                    Text(url.absoluteString)
                        .font(.footnote)
                        .textSelection(.enabled)
                    ShareLink(item: url) {
                        Label("Bagikan link demo", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Link simulasi")
                } footer: {
                    Text("Link demo ini tidak dapat digunakan untuk membayar.")
                }
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
