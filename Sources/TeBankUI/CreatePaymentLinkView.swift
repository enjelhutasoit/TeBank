import SwiftUI
import TeBankCore

struct CreatePaymentLinkView: View {
    let service: any PaymentLinkService

    @State private var title = ""
    @State private var amount = ""
    @State private var expiresAt = Date().addingTimeInterval(86_400)
    @State private var isCreating = false
    @State private var error: String?
    @State private var lastAttempt: Attempt?
    @State private var createdLink: PaymentLink?

    private struct Attempt {
        let request: PaymentLinkRequest
        let key = UUID()
    }

    var body: some View {
        Form {
            Section {
                TextField("Judul pembayaran", text: $title)
                TextField("Nominal (rupiah)", text: $amount)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                DatePicker("Kedaluwarsa", selection: $expiresAt)
            } footer: {
                Text("Masukkan nominal rupiah tanpa titik atau koma.")
            }
            .disabled(isCreating)

            Section {
                Button("Buat link", action: createLink)
                    .disabled(isCreating)
                if isCreating {
                    ProgressView("Membuat link")
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Buat link pembayaran")
        .sheet(item: $createdLink) { link in
            NavigationStack { PaymentLinkDetailView(link: link) }
        }
    }

    private func createLink() {
        guard !isCreating else { return }
        error = nil

        let input = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.utf8.allSatisfy({ (48...57).contains($0) }),
              let rupiah = Int64(input), rupiah > 0 else {
            error = "Masukkan nominal rupiah lebih dari nol dalam angka bulat."
            return
        }

        let request: PaymentLinkRequest
        do {
            request = try PaymentLinkRequest(title: title, amountRupiah: rupiah, expiresAt: expiresAt)
        } catch {
            self.error = creationMessage(for: error)
            return
        }

        let attempt: Attempt
        if let lastAttempt, lastAttempt.request == request {
            attempt = lastAttempt
        } else {
            attempt = Attempt(request: request)
        }
        lastAttempt = attempt
        isCreating = true

        Task {
            defer { isCreating = false }
            do {
                createdLink = try await service.create(attempt.request, idempotencyKey: attempt.key)
                lastAttempt = nil
                title = ""
                amount = ""
                expiresAt = Date().addingTimeInterval(86_400)
            } catch {
                self.error = creationMessage(for: error)
            }
        }
    }

    private func creationMessage(for error: any Error) -> String {
        switch error {
        case PaymentLinkError.emptyTitle: "Masukkan judul pembayaran."
        case PaymentLinkError.expired: "Waktu kedaluwarsa harus di masa depan."
        case PaymentLinkError.invalidAmount: "Masukkan nominal rupiah lebih dari nol."
        default: "Link belum dapat dibuat. Coba lagi."
        }
    }
}
