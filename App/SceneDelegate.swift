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
        window.rootViewController = UIHostingController(rootView: TeBankShell().teBankTheme())
        self.window = window
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
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        shield.removeFromSuperview()
        window?.rootViewController?.view.accessibilityElementsHidden = false
    }

    private func coverWindow() {
        guard let window else { return }
        window.rootViewController?.view.accessibilityElementsHidden = true
        shield.frame = window.bounds
        window.addSubview(shield)
    }
}
