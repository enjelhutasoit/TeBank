import SwiftUI
import TeBankCore

struct OnboardingLab: View {
    let demo: OnboardingDemo
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("Perilaku layanan demo") {
                ForEach(FakeOnboardingAuthority.Scenario.choices, id: \.self) { choice in
                    Button {
                        Task { await demo.select(choice) }
                    } label: {
                        HStack {
                            Text(choice.title)
                            Spacer()
                            if choice == demo.scenario {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(choice == demo.scenario ? .isSelected : [])
                }
            }
            .disabled(demo.model.isBusy || demo.changingScenario)
            if case .reviewed(_, .pending) = demo.model.progress {
                Section("Tinjauan demo") {
                    Button("Setujui pengajuan demo") {
                        Task { await demo.approve() }
                    }
                    .disabled(demo.model.isBusy || demo.changingScenario)
                    if demo.approvalFailed { Text("Keputusan demo gagal disimpan.") }
                }
            }
            Section {
                Button("Mulai pengajuan baru", role: .destructive) { confirmingReset = true }
                    .disabled(!demo.model.canReset || demo.changingScenario)
            } footer: {
                Text("Menghapus progres klien. Keputusan layanan demo untuk pengajuan lama tetap tersimpan.")
            }
        }
        .navigationTitle("Lab simulasi")
        .confirmationDialog("Mulai pengajuan baru?", isPresented: $confirmingReset) {
            Button("Mulai lagi", role: .destructive) { Task { await demo.model.reset() } }
        }
    }
}

private extension FakeOnboardingAuthority.Scenario {
    static var choices: [Self] { [.normal, .offline, .maintenance, .loseSubmissionResponse, .requireAction] }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .offline: "Offline"
        case .maintenance: "Pemeliharaan"
        case .loseSubmissionResponse: "Respons hilang setelah diterima"
        case .requireAction: "Minta penggantian sampel"
        }
    }
}
