# TeBank

TeBank is an independent, unofficial iOS prototype for demonstrating business banking workflows with synthetic data. Public Nobank materials informed the product research. TeBank has no affiliation with or endorsement from Nobank.

## Prototype scope

- A SwiftUI shell with a home screen and an About screen.
- Light and dark TeBank palettes mapped to VaneKit.
- An opaque privacy cover applied when an iOS scene leaves the active state.
- Device-authenticated sessions with passcode fallback.
- Synthetic business onboarding with local checkpoint recovery and configurable failure scenarios.

TeBank does not open bank accounts or collect identity photos. The onboarding sequence is an independent demo design. Nobank advertises online registration on its [digital business account page](https://nobank.id/fitur/rekening-digital).

## Run locally

Use Xcode 16.2 and Swift 6.0.3. The app targets iOS 17 or later. The package supports macOS 14 or later for local tests.

1. Open `TeBank.xcodeproj` in Xcode.
2. Select the shared `TeBank` scheme and an installed iPhone simulator.
3. Run the app and select **Buka TeBank**. Use device authentication or an enrolled simulator biometric.
4. Open **Pendaftaran bisnis**, give demo consent, and select the synthetic samples.
5. In **Lab simulasi**, select **Respons hilang setelah diterima**, return, and submit. Terminate the app after the missing-response message. Relaunch, unlock, and reopen onboarding. The original request should show **Menunggu tinjauan**.
6. For the sample-replacement demo, start a new request in the lab, select **Minta penggantian sampel**, and submit the new draft. Replace the synthetic samples to return to pending review.

From the repository root, run the package tests with Xcode 16.2 selected:

```bash
xcrun swift test --disable-automatic-resolution -Xswiftc -warnings-as-errors
```

The unit tests cover theme contrast, checkpoint storage, the simulated authority, and onboarding recovery. To check the privacy cover, open the About screen, enter the iOS app switcher, and inspect the TeBank preview for hidden content. Reopen TeBank and confirm that device authentication is required again. Repeat in light and dark appearance.

## Module boundaries

- `TeBankCore` owns color math, synthetic onboarding state, persistence, and the simulated authority.
- `TeBankUI` owns SwiftUI navigation and the VaneKit theme adapter.
- `App` hosts the shell and manages each window's privacy cover through the UIKit scene lifecycle.
