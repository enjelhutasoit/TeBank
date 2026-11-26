import BiometricSessionCore
import BiometricSessionLocalAuth
import SwiftUI
import TeBankUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let shield = UIView()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        presentLockedSession()
        shield.backgroundColor = .black
        shield.isAccessibilityElement = true
        shield.accessibilityLabel = "TeBank"
        shield.accessibilityViewIsModal = true
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coverWindow()
        window.makeKeyAndVisible()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        coverWindow()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        coverWindow()
        presentLockedSession()
        coverWindow()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        shield.removeFromSuperview()
        window?.rootViewController?.view.accessibilityElementsHidden = false
    }

    private func presentLockedSession() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--dashboard-ui-test") {
            window?.rootViewController = UIHostingController(rootView: TeBankShell().teBankTheme())
            return
        }
        #endif
        // Each foreground session has its own controller. A late result can only
        // update the old, detached view after this window re-enters the background.
        let controller = SessionController(
            authenticator: LocalAuthAuthenticator(passcodeFallback: .allowed),
            clock: MonotonicSessionClock()
        )
        window?.rootViewController = UIHostingController(rootView: LockedSession(controller: controller).teBankTheme())
    }

    private func coverWindow() {
        guard let window else { return }
        window.rootViewController?.view.accessibilityElementsHidden = true
        shield.frame = window.bounds
        window.addSubview(shield)
    }
}

private struct LockedSession: View {
    let controller: SessionController
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var showFailure = false

    var body: some View {
        if unlocked {
            TeBankShell()
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    Image("TeBankWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280)
                        .accessibilityHidden(true)

                    Button {
                        guard !authenticating else { return }
                        authenticating = true
                        Task { await authenticate() }
                    } label: {
                        VStack(spacing: 8) {
                            Image("BiometricUnlock")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .accessibilityHidden(true)
                            Text("Buka TeBank")
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(authenticating)

                    if showFailure {
                        Text("Sesi masih terkunci. Coba lagi dengan autentikasi perangkat.")
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .padding(.top, 32)
            }
        }
    }

    @MainActor
    private func authenticate() async {
        defer { authenticating = false }
        showFailure = false
        // The SDK starts signed out. Establish a synthetic local session and
        // lock it before prompting. The shell is shown only after unlock.
        if await controller.state == .signedOut {
            await controller.signIn()
            await controller.lock()
        }
        do {
            try await controller.unlock(reason: "Buka sesi demo TeBank")
            unlocked = await controller.state == .unlocked
        } catch {
            showFailure = true
        }
    }
}
