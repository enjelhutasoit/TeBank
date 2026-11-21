import XCTest

final class DashboardFlowTests: XCTestCase {
    @MainActor
    func testApprovalUnlocksDashboardAndTransactionDetail() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--dashboard-ui-test")
        app.launch()

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
        let balance = app.staticTexts["dashboard.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        XCTAssertTrue(balance.label.contains("7.850.000"))
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription]) { issue in
            print("Accessibility finding: \(issue.compactDescription) on \(issue.element?.debugDescription ?? "unknown element")")
            return false
        }
        let firstEntry = app.buttons["transaction.DEMO-003"]
        XCTAssertTrue(firstEntry.label.contains("Masuk"))
        XCTAssertTrue(firstEntry.label.contains("Toko Reka"))
        tap("transaction.DEMO-003", in: app)
        let reference = app.staticTexts["transaction.detail.reference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 15))
        XCTAssertEqual(reference.label, "DEMO-003")
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription]) { issue in
            print("Accessibility finding: \(issue.compactDescription) on \(issue.element?.debugDescription ?? "unknown element")")
            return false
        }
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.buttons[identifier]
        let available = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"),
            object: element
        )
        guard XCTWaiter.wait(for: [available], timeout: 15) == .completed else {
            return XCTFail("Control unavailable: " + identifier, file: file, line: line)
        }
        element.tap()
    }
}
