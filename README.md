# TeBank

TeBank is an independent, unofficial iOS prototype for demonstrating business banking workflows with synthetic data. Public Nobank materials informed the product research. TeBank has no affiliation with or endorsement from Nobank.

## Foundation scope

- A SwiftUI shell with a home screen and an About screen.
- Light and dark TeBank palettes mapped to VaneKit.
- An opaque privacy cover applied when an iOS scene leaves the active state.

The prototype uses no production bank APIs or real customer data. Registration, identity verification, transfers, and payments are outside this milestone.

## Run locally

Use Xcode 16.2 and Swift 6.0.3. The app targets iOS 17 or later. The package supports macOS 14 or later for local tests.

1. Open `TeBank.xcodeproj` in Xcode.
2. Select the shared `TeBank` scheme and an installed iPhone simulator.
3. Press **Run** and open **Tentang TeBank** from the home screen.

From the repository root, run the package tests with Xcode 16.2 selected:

```bash
xcrun swift test --disable-automatic-resolution -Xswiftc -warnings-as-errors
```

The unit tests check the contrast calculation and both palettes. To check the privacy cover, open the About screen, enter the iOS app switcher, and inspect the TeBank preview for hidden content. Reopen TeBank and confirm that the About screen resumes. Repeat in light and dark appearance.

## Module boundaries

- `TeBankCore` holds the color values and contrast calculation.
- `TeBankUI` owns SwiftUI navigation and the VaneKit theme adapter.
- `App` hosts the shell and manages each window's privacy cover through the UIKit scene lifecycle.
