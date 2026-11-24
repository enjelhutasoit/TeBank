import SwiftUI
import TeBankCore

/// A single client and a single writer per store for all windows in the demo.
@MainActor @Observable
final class OnboardingDemo {
    static let shared = OnboardingDemo(directory: storageDirectory)
    private static var storageDirectory: URL {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--dashboard-ui-test") {
            return URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        }
        #endif
        return URL.applicationSupportDirectory.appendingPathComponent("TeBankDemo")
    }
    let model: OnboardingModel
    let transfers: LocalTransferModel
    let paymentLinks = FakePaymentLinkService()
    private let authority: FakeOnboardingAuthority
    private(set) var scenario: FakeOnboardingAuthority.Scenario = .normal
    private(set) var changingScenario = false

    init(directory: URL) {
        transfers = LocalTransferModel(directory: URL.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        authority = FakeOnboardingAuthority(directory: directory.appendingPathComponent("authority"))
        model = OnboardingModel(
            store: FileCheckpointStore(url: directory.appendingPathComponent("checkpoint.json")),
            service: authority
        )
    }

    func approve() async {
        guard case .reviewed(let id, .pending) = model.progress, !changingScenario, !model.isBusy else { return }
        changingScenario = true
        defer { changingScenario = false }
        approvalFailed = false
        do {
            try await authority.approveForDemo(requestID: id)
            await model.refresh()
        } catch {
            approvalFailed = true
        }
    }

    private(set) var approvalFailed = false

    func select(_ value: FakeOnboardingAuthority.Scenario) async {
        guard !changingScenario else { return }
        changingScenario = true
        await authority.setScenario(value)
        scenario = value
        changingScenario = false
    }
}

struct OnboardingScreen: View {
    let demo: OnboardingDemo
    private var model: OnboardingModel { demo.model }

    var body: some View {
        Form {
            Section("Simulasi TeBank") {
                Text("Gunakan sampel sintetis. Tidak perlu mengunggah foto atau identitas.")
            }
            Section("Status pengajuan") {
                switch model.progress {
                case nil:
                    if model.issue == nil { ProgressView("Memuat progres") }
                case let .draft(consent, identity, selfie):
                    Toggle("Setuju mengikuti simulasi", isOn: Binding(
                        get: { consent },
                        set: { value in Task { await model.updateDraft(consent: value, identitySample: identity, selfieSample: selfie) } }
                    ))
                    Button(identity && selfie ? "Sampel KTP dan swafoto dipilih" : "Pilih sampel KTP dan swafoto") {
                        Task { await model.updateDraft(consent: consent, identitySample: true, selfieSample: true) }
                    }
                    .disabled(identity && selfie)
                    Button("Kirim pengajuan") { Task { await model.submit() } }
                        .disabled(!(consent && identity && selfie))
                case .submitting:
                    Text("Pengiriman belum terkonfirmasi")
                    if model.issue == .missingRequest {
                        Button("Kirim ulang pengajuan yang sama") { Task { await model.submit() } }
                    }
                    refreshButton
                case let .reviewed(_, status):
                    Text(status.title)
                    if status == .requiresAction {
                        Button("Ganti dengan sampel sintetis baru") { Task { await model.replaceSamples() } }
                    }
                    if status == .approved {
                        NavigationLink("Buka dashboard") {
                            BusinessDashboard(transfers: demo.transfers, ledger: .sample, paymentLinks: demo.paymentLinks)
                        }
                    }
                    refreshButton
                }
                if let issue = model.issue {
                    Text(issue.message)
                    if model.progress == nil {
                        Button("Muat ulang progres") { Task { await model.restore() } }
                    }
                }
            }
            .disabled(model.isBusy || demo.changingScenario)
            Section {
                NavigationLink("Lab simulasi") { OnboardingLab(demo: demo) }
            }
        }
        .navigationTitle("Pendaftaran bisnis")
        .task { await model.restore() }
    }

    private var refreshButton: some View {
        Button("Periksa status") { Task { await model.refresh() } }
    }
}

private extension OnboardingCheckpoint.ReviewStatus {
    var title: String {
        switch self {
        case .pending: "Menunggu tinjauan"
        case .requiresAction: "Sampel perlu diganti"
        case .approved: "Disetujui"
        }
    }
}

private extension OnboardingModel.Issue {
    var message: String {
        switch self {
        case .checkpoint: "Progres lokal tidak dapat dibaca atau disimpan. Coba lagi."
        case .offline: "Simulasi offline. Pilih Normal di lab lalu periksa status."
        case .maintenance: "Layanan demo sedang dalam pemeliharaan. Periksa kembali setelah memilih Normal."
        case .unresolved: "Respons belum diterima. Periksa status pengajuan."
        case .missingRequest: "Layanan demo tidak menemukan pengajuan ini."
        case .unavailable: "Data layanan demo tidak dapat diakses."
        }
    }
}
