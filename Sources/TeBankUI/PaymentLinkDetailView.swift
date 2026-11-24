import SwiftUI
import TeBankCore

struct PaymentLinkDetailView: View {
    @State private var link: PaymentLink
    @State private var error: String?
    @State private var busy = false
    let service: any PaymentLinkDemoService

    init(link: PaymentLink, service: any PaymentLinkDemoService) {
        _link = State(initialValue: link)
        self.service = service
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Ringkasan") {
                LabeledContent("Judul", value: link.request.title)
                LabeledContent("Nominal", value: rupiah(link.request.amountRupiah))
                LabeledContent("Kedaluwarsa", value: link.request.expiresAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Status pembayaran") {
                TimelineView(.explicit([Date.distantPast, link.request.expiresAt])) { context in
                    let status = link.status(at: max(Date.now, context.date))
                    switch status {
                    case .active:
                        Text("Aktif")
                        Button("Simulasikan pembayaran") { update(simulate: true) }
                    case .expired: Text("Kedaluwarsa")
                    case .paid: Text("Dibayar")
                    }
                }
                Button("Periksa status") { update(simulate: false) }
                if let error { Text(error) }
            }
            .disabled(busy)

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
        .onAppear { update(simulate: false) }
        .navigationTitle("Detail link pembayaran")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Selesai") { dismiss() }
            }
        }
    }

    private func refresh() async {
        do {
            guard let current = try await service.find(id: link.id) else {
                throw PaymentLinkDemoError.linkMissing
            }
            link = current
            error = nil
        } catch {
            self.error = "Status belum dapat diperbarui."
        }
    }

    private func update(simulate: Bool) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            if simulate {
                do {
                    link = try await service.simulatePayment(id: link.id)
                    error = nil
                } catch {
                    self.error = "Pembayaran simulasi belum dapat diproses."
                }
            } else {
                await refresh()
            }
        }
    }
}
