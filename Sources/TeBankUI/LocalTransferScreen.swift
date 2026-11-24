import Foundation
import SwiftUI
import TeBankCore

@MainActor @Observable
final class LocalTransferModel {
    enum Step {
        case restoring
        case entry
        case review(LocalTransfer)
        case status(LocalTransfer, LocalTransferStatus)
    }

    var beneficiary = ""
    var bank = ""
    var account = ""
    var amount = ""
    var loseResponse = false
    private(set) var step = Step.restoring
    private(set) var busy = false
    private(set) var errorMessage: String?
    private var service: (any LocalTransferService)?
    private let directory: URL

    init(directory: URL) { self.directory = directory }

    var checkpoint: LocalTransferCheckpointStore {
        LocalTransferCheckpointStore(directory: directory)
    }

    private func openService(for request: LocalTransfer, loseResponse: Bool) async throws -> DemoLocalTransferService {
        let path = directory.appendingPathComponent("transfers.sqlite")
        return try await Task.detached {
            try DemoLocalTransferService(request: request, storeURL: path, loseResponse: loseResponse)
        }.value
    }

    func archivedStatus(for request: LocalTransfer) async throws -> LocalTransferStatus {
        let reader = try await openService(for: request, loseResponse: false)
        return try await reader.checkStatus()
    }

    func restore() async {
        guard case .restoring = step, !busy else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil
        do {
            guard let request = try checkpoint.load() else {
                step = .entry
                return
            }
            let reopened = try await openService(for: request, loseResponse: false)
            if let status = try await reopened.restoredStatus() {
                service = reopened
                step = .status(request, status)
            } else {
                beneficiary = request.beneficiary
                bank = request.bank
                account = request.account
                amount = String(request.rupiah)
                step = .review(request)
            }
        } catch {
            errorMessage = "Transfer belum dapat dipulihkan. Coba kembali."
        }
    }

    func review() {
        errorMessage = nil
        guard amount.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int64(amount) else {
            errorMessage = "Masukkan nominal dalam rupiah bulat."
            return
        }
        do {
            step = .review(try LocalTransfer(beneficiary: beneficiary, bank: bank, account: account, rupiah: value))
        } catch LocalTransfer.ValidationError.invalidRecipient {
            errorMessage = "Isi nama, bank, dan nomor rekening demo dengan benar."
        } catch {
            errorMessage = "Nominal rupiah tidak valid."
        }
    }

    func edit() {
        guard !busy else { return }
        do { try checkpoint.clear() }
        catch {
            errorMessage = "Rincian transfer belum dapat dihapus. Coba kembali."
            return
        }
        returnToEntry()
    }

    private func returnToEntry() {
        errorMessage = nil
        service = nil
        step = .entry
    }

    func submit() async {
        guard case let .review(request) = step, !busy else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil
        do {
            try checkpoint.save(request)
            let service = try await openService(for: request, loseResponse: loseResponse)
            self.service = service
            step = .status(request, try await service.submit())
        } catch {
            step = .restoring
            errorMessage = "Pengiriman belum dapat diproses. Periksa transfer sebelum mencoba kembali."
        }
    }

    func refresh() async {
        guard case let .status(request, _) = step, let service, !busy else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil
        do { step = .status(request, try await service.checkStatus()) }
        catch { errorMessage = "Status belum dapat diperiksa. Coba kembali." }
    }

    func startNew() {
        guard case let .status(request, status) = step, status != .pending, !busy else { return }
        do { try checkpoint.archive(request) }
        catch {
            errorMessage = "Riwayat transfer belum dapat disimpan. Coba kembali."
            return
        }
        returnToEntry()
        beneficiary = ""
        bank = ""
        account = ""
        amount = ""
        loseResponse = false
    }
}

struct LocalTransferScreen: View {
    @Bindable var model: LocalTransferModel
    @State private var showsReviewError = false

    var body: some View {
        Form {
            switch model.step {
            case .restoring:
                if model.errorMessage != nil {
                    Button("Coba pulihkan transfer") { Task { await model.restore() } }
                }
            case .entry:
                Section("Penerima sintetis") {
                    TextField("Nama penerima demo", text: $model.beneficiary)
                    TextField("Bank demo", text: $model.bank)
                    TextField("Nomor rekening demo", text: $model.account)
                    TextField("Nominal rupiah", text: $model.amount)
                }
                Toggle("Simulasikan respons hilang", isOn: $model.loseResponse)
                Button("Tinjau transfer") {
                    model.review()
                    showsReviewError = model.errorMessage != nil
                }
                .alert("Periksa rincian transfer", isPresented: $showsReviewError, presenting: model.errorMessage) { _ in
                    Button("Perbaiki", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
            case let .review(request):
                TransferSummary(request: request)
                Button("Konfirmasi transfer demo") { Task { await model.submit() } }
                Button("Ubah rincian") { model.edit() }
            case let .status(request, status):
                TransferSummary(request: request)
                Section("Status transfer") {
                    TransferStatusLabel(status: status)
                    Button("Periksa status transfer") { Task { await model.refresh() } }
                    if status != .pending {
                        Button("Transfer baru") { model.startNew() }
                    }
                }
            }
            if let errorMessage = model.errorMessage { Text(errorMessage) }
            if model.busy { ProgressView("Memproses") }
        }
        .disabled(model.busy)
        .navigationTitle("Transfer lokal")
        .task { await model.restore() }
    }

}

struct TransferStatusLabel: View {
    let status: LocalTransferStatus

    var body: some View {
        switch status {
        case .pending: Text("Hasil belum diketahui")
        case .accepted: Text("Diterima untuk diproses")
        case .settled: Text("Selesai")
        case .rejected: Text("Ditolak")
        }
    }
}

struct TransferSummary: View {
    let request: LocalTransfer

    var body: some View {
        Section("Ringkasan simulasi") {
            LabeledContent("Nama", value: request.beneficiary)
            LabeledContent("Bank", value: request.bank)
            LabeledContent("Rekening", value: request.account)
            LabeledContent("Jumlah", value: rupiah(request.rupiah))
        }
    }
}
