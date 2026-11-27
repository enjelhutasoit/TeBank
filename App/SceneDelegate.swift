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
        shield.accessibilityLabel = "tebank"
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
            ViewThatFits(in: .vertical) {
                VStack(spacing: 16) {
                    // Match the footer's height so the wordmark stays at the center.
                    loginButton.hidden().accessibilityHidden(true)
                    Spacer(minLength: 0)
                    wordmark
                    Spacer(minLength: 0)
                    loginButton
                }
                .padding(.vertical, 24)

                ScrollView {
                    VStack(spacing: 24) {
                        wordmark
                        loginButton
                    }
                    .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 21)
            .alert("Sesi masih terkunci", isPresented: $showFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Coba lagi dengan autentikasi perangkat.")
            }
        }
    }

    private var wordmark: some View {
        Image("TeBankWordmark")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 180)
            .accessibilityHidden(true)
    }

    private var loginButton: some View {
        Button {
            guard !authenticating else { return }
            authenticating = true
            Task { await authenticate() }
        } label: {
            HStack(spacing: 12) {
                Image("BiometricUnlock")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text("Login")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.black, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(authenticating)
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
            try await controller.unlock(reason: "Buka sesi demo tebank")
            unlocked = await controller.state == .unlocked
        } catch {
            showFailure = true
        }
    }
}
