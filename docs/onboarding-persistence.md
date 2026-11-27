# Onboarding persistence and session boundaries

tebank uses two independent local data stores to model a client and a remote authority. The integration layer supplies separate app-private Application Support locations. Both stores contain synthetic state.

| Owner | Durable state | Recovery rule |
| --- | --- | --- |
| Client checkpoint | Versioned progress and request ID | Keep the same ID across a retry. Preserve unreadable or newer records for an explicit recovery decision. |
| Fake authority | One review decision per UUID | Read an existing decision before creating one. When simulating response loss, finish the atomic write before throwing. |
| Scene | No persisted unlock flag | Start behind a lock screen and replace the scene session on background entry. Device authentication opens the current scene. |

Each store assumes one actor instance per writable location in one process. Atomic replacement keeps readers from seeing a partial record. It does not provide a cross-process transaction spanning both stores. A missing client response can therefore coexist with a durable authority decision. When the app resumes an interrupted submission, it uses the saved request ID to look up the authority's decision.

The session gate uses BiometricSession with device passcode fallback. The [Xcode workspace lockfile](../tebank.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) records the SDK version and revision. The SDK owns the authentication prompt. The app owns scene replacement and the opaque inactive-state cover. Switching to the background discards in-memory navigation. A temporary inactive transition during a system prompt only covers the window. Unlocking has no effect on the simulated authority.

## Manual verification on iOS

1. Launch the app and check that the shell is inaccessible until device authentication succeeds.
2. Cancel the prompt, retry, and unlock using an enrolled biometric or the device passcode.
3. Open About, enter the app switcher, and inspect the preview for an opaque cover. Return and check that authentication is required again.
4. Background the app during a prompt. After returning, verify that a late result cannot open the new scene session.
