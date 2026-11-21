# Slice A interview walkthrough

Use the normal app launch on an enrolled iPhone. Start with a fresh synthetic draft in the demo lab. All timings below are a rehearsal plan.

| Time | Action | Evidence to show |
| --- | --- | --- |
| 0:00–0:30 | Unlock TeBank, open business registration, give consent and select the two samples. | Device authentication opens the local session. The sample picker requires no camera or identity document. |
| 0:30–1:20 | Select lost submission response in the lab and submit. Terminate the app after the missing-response message. | The client stored the request ID before dispatch. The fake authority saved its decision before the response was lost. |
| 1:20–2:05 | Relaunch, unlock and reopen registration. | Status lookup restores the pending decision. The client can resume without starting a second application. |
| 2:05–2:45 | Approve the pending request in the lab, return, open the dashboard and select a transaction. | The approval unlocks a synthetic ledger. Credits and debits produce Rp7.850.000. |
| 2:45–3:00 | Show the privacy cover in the app switcher. | Each scene requires device authentication again after backgrounding. |

## Engineering discussion

The client owns the draft, consent flags and durable request ID. The authority owns the decision associated with that ID. Separate stores make a committed request with a lost response reproducible. Atomic replacement protects one file at a time. A shared actor serializes writes within this demo process. A generation token prevents an obsolete completion from restoring pre-reset state.

A deployed service would need authenticated sessions, per-account authorization, durable transactional idempotency, retention and deletion rules, and audited approval controls. The lab exposes an approval button solely to exercise synthetic transitions. The dashboard uses fixed integer IDR amounts. Banking integration, real KYC review, backend availability and authorization require independent implementations.

## Verification record

- [Dashboard baseline on main](https://github.com/enjelhutasoit/TeBank/actions/runs/44930156336) verified the package tests and the simulator approval-to-detail flow. The workflow uses Xcode 16.2 for package tests and the runner's default Xcode for simulator UI testing.
- The dashboard UI test also requests XCTest audits for Dynamic Type, clipped text and element descriptions on dashboard and detail. Automated inspection covers the visible accessibility tree.
- Local release gate: run `./verify.sh` on the Intel Mac with Xcode 16.2 selected and an eligible simulator already installed. Record the SHA, simulator and result.
- Device evidence pending: on the normal app entry point, enable VoiceOver and the largest accessibility text size. Traverse onboarding, lab, dashboard and detail. Check focus order, spoken transaction direction and amount, wrapping, scroll reachability, and the privacy cover. Record actual findings with the device, OS and SHA.
- Instruments evidence pending: profile a Release build on the iPhone. Record cold launch with App Launch and the consent, submit and restart sequence with File Activity. Save traces and record observed startup times, checkpoint writes and main-thread I/O before proposing performance changes.
- Capture the walkthrough with iOS screen recording and record the tested SHA. Review the clip for readable status transitions and personal notifications before sharing.
