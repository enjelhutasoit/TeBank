import Foundation
import SwiftUI
import TeBankCore

@MainActor @Observable
final class LocalTransferModel {
    enum Step {
        case entry
        case review(LocalTransfer)
        case status(LocalTransfer, LocalTransferStatus)
    }

    var beneficiary = ""
    var bank = ""
    var account = ""
    var amount = ""
    var loseResponse = false
    private(set) var step = Step.entry
    private(set) var busy = false
    private(set) var error: String?
    private var service: (any LocalTransferService)?
    private let directory: URL

    init(directory: URL) { self.directory = directory }

    func review() {
        error = nil
        guard amount.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int64(amount) else {
            error = "Masukkan nominal dalam rupiah bulat."
            return
        }
        do {
            step = .review(try LocalTransfer(beneficiary: beneficiary, bank: bank, account: account, rupiah: value))
        } catch LocalTransfer.ValidationError.invalidRecipient {
            error = "Isi nama, bank, dan nomor rekening demo dengan benar."
        } catch {
            error = "Nominal rupiah tidak valid."
        }
    }

    func edit() {
        guard !busy else { return }
        error = nil
        service = nil
        step = .entry
    }

    func submit() async {
        guard case let .review(request) = step, !busy else { return }
        busy = true
        defer { busy = false }
        error = nil
        do {
            if service == nil {
                let path = directory.appendingPathComponent("transfers.sqlite")
                service = try await Task.detached {
                    [loseResponse] in
                    try DemoLocalTransferService(request: request, storeURL: path, loseResponse: loseResponse)
                }.value
            }
            guard let service else { return }
            step = .status(request, try await service.submit())
        } catch {
            error = "Pengiriman belum dapat diproses. Coba kembali."
        }
    }

    func refresh() async {
        guard case let .status(request, _) = step, let service, !busy else { return }
        busy = true
        defer { busy = false }
        error = nil
        do { step = .status(request, try await service.checkStatus()) }
        catch { error = "Status belum dapat diperiksa. Coba kembali." }
    }

    func startNew() {
        guard case let .status(_, status) = step, status != .pending, !busy else { return }
        edit()
        beneficiary = ""
        bank = ""
        account = ""
        amount = ""
        loseResponse = false
    }
}

struct LocalTransferScreen: View {
    @Bindable var model: LocalTransferModel

    var body: some View {
        Form {
            switch model.step {
            case .entry:
                Section("Penerima sintetis") {
                    TextField("Nama penerima demo", text: $model.beneficiary)
                    TextField("Bank demo", text: $model.bank)
                    TextField("Nomor rekening demo", text: $model.account)
                    TextField("Nominal rupiah", text: $model.amount)
                }
                Toggle("Simulasikan respons hilang", isOn: $model.loseResponse)
                Button("Tinjau transfer") { model.review() }
            case let .review(request):
                summary(request)
                Button("Konfirmasi transfer demo") { Task { await model.submit() } }
                Button("Ubah rincian") { model.edit() }
            case let .status(request, status):
                summary(request)
                Section("Status transfer") {
                    switch status {
                    case .pending: Text("Hasil belum diketahui")
                    case .accepted: Text("Diterima untuk diproses")
                    case .settled: Text("Selesai")
                    case .rejected: Text("Ditolak")
                    }
                    Button("Periksa status transfer") { Task { await model.refresh() } }
                    if status != .pending {
                        Button("Transfer baru") { model.startNew() }
                    }
                }
            }
            if let error = model.error { Text(error) }
            if model.busy { ProgressView("Memproses") }
        }
        .disabled(model.busy)
        .navigationTitle("Transfer lokal")
    }

    private func summary(_ request: LocalTransfer) -> some View {
        Section("Ringkasan simulasi") {
            LabeledContent("Nama", value: request.beneficiary)
            LabeledContent("Bank", value: request.bank)
            LabeledContent("Rekening", value: request.account)
            LabeledContent("Jumlah", value: rupiah(request.rupiah))
        }
    }
}
