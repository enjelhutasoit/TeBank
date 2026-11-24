# ADR 001 — Separate reviewed transfer, submission identity and bank receipt

- Status — Accepted (implemented through PR #44)
- Date — 2026-11-25
- Scope — Local transfer simulation and history

## Context

A business user may lose the response or terminate the application while submitting a transfer. A retry with a new intent could represent a second business action. The original reviewed amount must therefore stay associated with the original submission identity, and bank status must come from the simulated authority.

## Decision

Maintain three records with distinct responsibilities.

| Record | Ownership | Purpose |
| --- | --- | --- |
| `reviewed-transfer.json` | TeBankCore | Immutable reviewed recipient, bank, account, ID and whole-rupiah amount. Written atomically before submission. |
| `transfers.sqlite` | SwiftTransferKit journal | Original intent (ID and money) and idempotency key. The coordinator journals before dispatch. |
| `transfers.sqlite.bank.sqlite` | DemoBankGateway | Separate simulated acceptance receipt, persisted before returning the response. |

The screen model restores the reviewed request when the transfer screen opens. The service compares the reconstructed intent against the journal before requesting status. The SDK uses the journal's original ID and key for reconciliation; matching bank evidence can confirm acceptance for processing.

| Recovery observation | UI behavior |
| --- | --- |
| No active checkpoint | Enter transfer details. |
| Valid review with no journal entry | Show review and require confirmation. |
| Matching journal but no confirmed receipt | Keep the transfer pending and offer status lookup. |
| Matching journal and confirmed receipt | Display the reconciled status. |
| Invalid checkpoint or intent mismatch | Show recovery error and retain the records. |

When the active status is known, starting a new transfer moves the reviewed checkpoint into `history/<intent UUID>.json`. History reads reuse the journal and reconciliation service to show status. A pending transfer cannot be archived through the new-transfer action. A failed archive leaves the active flow in place.

## Alternatives considered

| Alternative | Trade-off |
| --- | --- |
| Store everything in one app-side JSON record | Simpler storage, but a locally written status cannot independently establish bank acceptance. |
| Automatically resubmit on relaunch | Convenient, but requires an explicit policy for ambiguous outcomes and durable backend idempotency. |
| Move review fields into the shared SDK | Could unify storage, but couples the generic transfer intent to TeBank's synthetic beneficiary UI. |

## Consequences and limitations

- Recovery works across process relaunch with the existing file format. Separate stores introduce multiple persistence boundaries and require reconciliation.
- A status check adds a local journal read to verify that the displayed amount matches the recorded intent. The SDK intent includes identity and money. Recipient fields are app-side metadata and are outside that comparison.
- The demo bank returns acceptance for processing. It does not execute funds movement, settlement or recipient routing. A production integration needs a remote authoritative status API, backend idempotency, appropriate data protection and an explicit recovery policy for missing or corrupted stores.
- History is ordered by beneficiary and UUID because the review format has no transaction timestamp.

## Implementation and verification

- [Reviewed transfer](../../Sources/TeBankCore/LocalTransfer.swift)
- [Checkpoint and archive](../../Sources/TeBankCore/LocalTransferCheckpointStore.swift)
- [SDK adapter and receipt](../../Sources/TeBankCore/LocalTransferService.swift)
- [Transfer screen and recovery](../../Sources/TeBankUI/LocalTransferScreen.swift)
- [Core regression tests](../../Tests/TeBankCoreTests/LocalTransferTests.swift) cover the pre-journal checkpoint, missing bank receipt, lost response after acceptance, mismatched amount and archival failures.
- [Simulator walkthroughs](../../Tests/TeBankUITests/DashboardFlowTests.swift) exercise reconciliation after navigation and process relaunch, including the archived transfer details.
- [v0.8.0 recovery verification](../releases/v0.8.0.md), [v0.9.0 history verification](../releases/v0.9.0.md), and [PR #44 regression CI](https://github.com/enjelhutasoit/TeBank/actions/runs/45436344555).
