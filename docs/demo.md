# Guided tebank demo

Use an installed iPhone simulator with Xcode 16.2 and the shared tebank scheme. Use only synthetic recipient and business details. Start with a fresh installation if an earlier demo has already completed onboarding.

## 1. Session and onboarding

1. Select **Login** and authenticate.
2. Open **Pendaftaran bisnis**, enable **Setuju mengikuti simulasi**, and tap **Pilih sampel KTP dan swafoto**.
3. Tap **Kirim pengajuan** and wait for **Menunggu tinjauan**.
4. Open **Lab simulasi**, choose **Setujui pengajuan demo**, return to onboarding and tap **Buka dashboard**.

For an interrupted onboarding scenario, select **Respons hilang setelah diterima** in the lab before submitting. Terminate after the missing-response message, relaunch, unlock and reopen onboarding. The original request should show **Menunggu tinjauan**. Alternatively, use the **Minta penggantian sampel** scenario to demonstrate replacing synthetic samples before approval.

## 2. Dashboard and payment links

1. Inspect the synthetic balance and open a recent transaction. Return to the dashboard.
2. Tap **Buat link pembayaran**, enter a title such as Pesanan demo, an amount of 50000 rupiah and a future expiry. Tap **Buat link**.
3. Select **Bagikan link demo** and dismiss the system share sheet.
4. Tap **Simulasikan pembayaran**, then **Periksa status**. Expect **Dibayar**.
5. For an expiry demonstration, create a second link with a near-future expiry and leave it unpaid. Expect **Kedaluwarsa** when the deadline arrives.

Payment links are process-local and use synthetic share URLs.

## 3. Transfer recovery and history

1. Open **Transfer lokal**. Tap **Tinjau transfer** with an empty form, inspect the validation alert and select **Perbaiki**.
2. Enter Rani, Demo, account 0017 and amount 12500. Enable **Simulasikan respons hilang**.
3. Tap **Tinjau transfer**, inspect the summary and confirm via **Konfirmasi transfer demo**.
4. When **Hasil belum diketahui** appears, terminate the app. Relaunch, unlock, reopen onboarding, return to the approved dashboard and open **Transfer lokal**.
5. Expect the original account 0017 and **Diterima untuk diproses**. Tap **Transfer baru** to archive the review.
6. Repeat with account 0042, optionally checking status manually instead of relaunching. Archive the second accepted transfer.
7. Open **Riwayat transfer** and inspect both entries. Their references and account details should be distinct. Refresh status from each detail screen.

The simulator records acceptance for processing. No settlement or actual funds movement occurs. See [ADR 001](adr/001-transfer-recovery.md) for the recovery boundaries.

## 4. Accessibility and privacy

- Repeat the dashboard inspection in both light and dark appearance.
- Increase Dynamic Type and manually check that text remains readable. Use VoiceOver to inspect balance, transaction labels, validation alert and focus after dismissal.
- Enter the app switcher and confirm that the preview is covered; return and authenticate again following a background transition.

These are manual verification steps. Consult the [release evidence](releases) for historical test results.
