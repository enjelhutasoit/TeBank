import XCTest

final class DashboardFlowTests: XCTestCase {
    @MainActor
    func testApprovedDashboardSupportsTransactionDetailAndPaymentLinkSharing() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            guard (self.testRun?.failureCount ?? 0) > 0 else { return }
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "Failure screen"
            screen.lifetime = .deleteOnSuccess
            self.add(screen)
            let hierarchy = app.debugDescription
            print("Failure accessibility hierarchy: " + hierarchy)
            let tree = XCTAttachment(string: hierarchy)
            tree.name = "Accessibility hierarchy"
            tree.lifetime = .deleteOnSuccess
            self.add(tree)
        }
        app.launchArguments.append("--dashboard-ui-test")
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "TeBank did not reach the foreground")
        try openApprovedDashboard(in: app)
        let balance = app.descendants(matching: .any)["dashboard.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        XCTAssertEqual(balance.label, "Saldo simulasi")
        XCTAssertEqual(balance.value as? String, "7.850.000 rupiah")
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription]) { issue in
            print("Accessibility finding: \(issue.compactDescription) on \(issue.element?.debugDescription ?? "unknown element")")
            return false
        }
        let firstEntry = app.buttons["transaction.DEMO-003"]
        XCTAssertTrue(firstEntry.label.contains("Masuk"))
        XCTAssertTrue(firstEntry.label.contains("Toko Reka"))
        XCTAssertTrue(firstEntry.label.contains("1.200.000 rupiah"))
        let debit = app.buttons["transaction.DEMO-002"]
        XCTAssertTrue(debit.label.contains("Keluar, 425.000 rupiah"))
        tap("transaction.DEMO-003", in: app)
        let reference = app.staticTexts["transaction.detail.reference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 15))
        XCTAssertEqual(reference.label, "DEMO-003")
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription]) { issue in
            print("Accessibility finding: \(issue.compactDescription) on \(issue.element?.debugDescription ?? "unknown element")")
            return false
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        exerciseLocalTransfer(in: app)
        try exercisePaymentLinkSharing(in: app)
    }

    @MainActor
    private func exerciseLocalTransfer(in app: XCUIApplication) {
        tap("Transfer lokal", in: app)
        enterTransferDetails(in: app)
        tap("Tinjau transfer", in: app)
        XCTAssertTrue(app.staticTexts["Rekening, 0017"].waitForExistence(timeout: 10))
        tap("Konfirmasi transfer demo", in: app)
        XCTAssertTrue(app.staticTexts["Diterima untuk diproses"].waitForExistence(timeout: 15))
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    @MainActor
    func testPendingTransferCanBeReopenedAndReconciled() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--dashboard-ui-test")
        app.launch()
        try openApprovedDashboard(in: app)
        tap("Transfer lokal", in: app)
        let loseResponse = app.switches["Simulasikan respons hilang"]
        XCTAssertTrue(loseResponse.waitForExistence(timeout: 10))
        loseResponse.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(loseResponse.value as? String, "1")
        enterTransferDetails(in: app)
        tap("Tinjau transfer", in: app)
        tap("Konfirmasi transfer demo", in: app)

        let pending = app.staticTexts["Hasil belum diketahui"]
        XCTAssertTrue(pending.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Transfer baru"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("Transfer lokal", in: app)
        XCTAssertTrue(pending.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Rekening, 0017"].exists)
        tap("Periksa status transfer", in: app)
        XCTAssertTrue(app.staticTexts["Diterima untuk diproses"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Transfer baru"].exists)
    }

    @MainActor
    func testPendingTransferRecoversAfterProcessRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--dashboard-ui-test")
        app.launchEnvironment["TEBANK_UI_TEST_STORE"] = UUID().uuidString
        app.launch()
        try openApprovedDashboard(in: app)
        tap("Transfer lokal", in: app)
        let loseResponse = app.switches["Simulasikan respons hilang"]
        XCTAssertTrue(loseResponse.waitForExistence(timeout: 10))
        loseResponse.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(loseResponse.value as? String, "1")
        enterTransferDetails(in: app)
        tap("Tinjau transfer", in: app)
        tap("Konfirmasi transfer demo", in: app)
        XCTAssertTrue(app.staticTexts["Hasil belum diketahui"].waitForExistence(timeout: 15))

        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        tap("Pendaftaran bisnis", in: app)
        tap("Buka dashboard", in: app)
        tap("Transfer lokal", in: app)

        XCTAssertTrue(app.staticTexts["Diterima untuk diproses"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Rekening, 0017"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Transfer baru"].exists)
        XCTAssertFalse(app.buttons["Konfirmasi transfer demo"].exists)
    }

    @MainActor
    private func enterTransferDetails(in app: XCUIApplication) {
        for (label, value) in [("Nama penerima demo", "Rani"), ("Bank demo", "Demo"),
                               ("Nomor rekening demo", "0017"), ("Nominal rupiah", "12500")] {
            let field = app.textFields[label]
            field.tap()
            field.typeText(value)
        }
    }

    @MainActor
    private func exercisePaymentLinkSharing(in app: XCUIApplication) throws {
        tap("Buat link pembayaran", in: app)
        let title = app.textFields["Judul pembayaran"]
        title.tap()
        title.typeText("Pesanan demo")
        let amount = app.textFields["Nominal (rupiah)"]
        amount.tap()
        amount.typeText("50000")
        tap("Buat link", in: app)
        tap("Bagikan link demo", in: app)
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 15),
                      "Expected the system activity sheet after sharing a synthetic link")
    }

    @MainActor
    private func openApprovedDashboard(in app: XCUIApplication) throws {
        tap("Pendaftaran bisnis", in: app)
        XCTAssertFalse(app.buttons["Buka dashboard"].exists)
        let consent = app.switches["Setuju mengikuti simulasi"]
        XCTAssertTrue(consent.waitForExistence(timeout: 10))
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let consentSaved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == '1' AND enabled == true"),
            object: consent
        )
        guard XCTWaiter.wait(for: [consentSaved], timeout: 15) == .completed else {
            return XCTFail("Consent did not turn on. " + app.debugDescription)
        }
        tap("Pilih sampel KTP dan swafoto", in: app)
        let submit = app.buttons["Kirim pengajuan"]
        let ready = NSPredicate(format: "exists == true AND enabled == true")
        let readyExpectation = XCTNSPredicateExpectation(predicate: ready, object: submit)
        guard XCTWaiter.wait(for: [readyExpectation], timeout: 10) == .completed else {
            return XCTFail("Expected submit to become enabled. " + app.debugDescription)
        }
        submit.tap()
        XCTAssertTrue(app.staticTexts["Menunggu tinjauan"].waitForExistence(timeout: 10))
        tap("Lab simulasi", in: app)
        tap("Setujui pengajuan demo", in: app)
        let approval = app.buttons["Setujui pengajuan demo"]
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: approval)
        guard XCTWaiter.wait(for: [finished], timeout: 10) == .completed else {
            return XCTFail("Expected the lab to persist approval")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("Buka dashboard", in: app)
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.buttons[identifier]
        guard element.waitForExistence(timeout: 30) else {
            return XCTFail("Control unavailable: " + identifier, file: file, line: line)
        }
        element.tap()
    }
}
