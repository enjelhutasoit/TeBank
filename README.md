# TeBank

TeBank is an independent, unofficial iOS prototype for demonstrating business banking workflows with synthetic data.

## Prototype scope

- A SwiftUI shell with a home screen and an About screen.
- Light and dark TeBank palettes mapped to VaneKit.
- An opaque privacy cover applied when an iOS scene leaves the active state.
- Device-authenticated sessions with passcode fallback.
- Synthetic business onboarding with local checkpoint recovery and configurable failure scenarios.

TeBank does not open bank accounts or collect identity photos. The onboarding sequence is an independent demo design.

## Run locally

Use Xcode 16.2 and Swift 6.0.3. The app targets iOS 17 or later. The package supports macOS 14 or later for local tests.

1. Open `TeBank.xcodeproj` in Xcode.
2. Select the shared `TeBank` scheme and an installed iPhone simulator.
3. Run the app and select **Buka TeBank**. Use device authentication or an enrolled simulator biometric.
4. Open **Pendaftaran bisnis**, give demo consent, and select the synthetic samples.
5. In **Lab simulasi**, select **Respons hilang setelah diterima**, return, and submit. Terminate the app after the missing-response message. Relaunch, unlock, and reopen onboarding. The original request should show **Menunggu tinjauan**.
6. For the sample-replacement demo, start a new request in the lab, select **Minta penggantian sampel**, and submit the new draft. Replace the synthetic samples to return to pending review.

7. In the lab, select **Setujui pengajuan demo** once the request is pending. Return to onboarding, open **Buka dashboard**, and select a transaction to see its synthetic detail.

From the repository root, run the package tests with Xcode 16.2 selected:

```bash
xcrun swift test --disable-automatic-resolution -Xswiftc -warnings-as-errors
```

The unit tests cover theme contrast, checkpoint storage, the simulated authority, and onboarding recovery. To check the privacy cover, open the About screen, enter the iOS app switcher, and inspect the TeBank preview for hidden content. Reopen TeBank and confirm that device authentication is required again. Repeat in light and dark appearance.

## Slice A verification

On the Intel Mac, select Xcode 16.2 (build `16C5032a`) and make sure the shared `TeBank` scheme has an eligible iPhone simulator already installed. From the repository root, run:

```bash
git rev-parse HEAD
./verify.sh
```

Record the tested commit, simulator and result. The script runs the SwiftPM tests and the approval-to-transaction-detail UI test, including the dashboard and detail accessibility audits.

[CI run #44](https://github.com/enjelhutasoit/TeBank/actions/runs/45108475355) passed 19 SwiftPM tests with Xcode 16.2 and the iOS simulator UI test with Xcode 16.4. Local simulator verification on Xcode 16.2, manual VoiceOver and Dynamic Type checks, Instruments measurements and the demo recording are pending. See the [Slice A walkthrough and verification record](docs/slice-a-demo.md).

## Module boundaries

- `TeBankCore` owns color math, synthetic onboarding state, persistence, and the simulated authority.
- `TeBankUI` owns SwiftUI navigation and the VaneKit theme adapter.
- `App` hosts the shell and manages each window's privacy cover through the UIKit scene lifecycle.
