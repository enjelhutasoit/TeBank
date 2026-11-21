import SwiftUI
import VaneKit

public struct TeBankShell: View {
    @Environment(\.vaneTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                NavigationLink("Pendaftaran bisnis") {
                    OnboardingScreen(demo: .shared)
                }
                .listRowBackground(theme.color(.surface, for: scheme))
                NavigationLink("Tentang TeBank") {
                    Text("Prototipe independen dengan data simulasi.")
                        .padding()
                        .navigationTitle("Tentang TeBank")
                }
                .listRowBackground(theme.color(.surface, for: scheme))
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.background, for: scheme))
            .navigationTitle("TeBank")
        }
        .foregroundStyle(theme.color(.textPrimary, for: scheme))
        .tint(theme.color(.accent, for: scheme))
    }
}
