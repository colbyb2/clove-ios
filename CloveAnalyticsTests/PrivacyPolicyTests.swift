import XCTest
@testable import Clove

final class PrivacyPolicyTests: XCTestCase {
    func testCanonicalPolicyContainsNoPlaceholdersOrUnsupportedClaims() {
        let policy = ClovePrivacyPolicy.text.lowercased()

        XCTAssertFalse(policy.contains("[date]"))
        XCTAssertFalse(policy.contains("example.com"))
        XCTAssertFalse(policy.contains("encrypted at rest"))
        XCTAssertFalse(policy.contains("encrypted in transit"))
        XCTAssertFalse(policy.contains("delete your account"))
        XCTAssertTrue(policy.contains("does not add database-level encryption"))
        XCTAssertTrue(policy.contains("not transmitted"))
    }

    func testCanonicalPolicyIdentifiesCurrentDiagnosticsBackupsAndContact() {
        let policy = ClovePrivacyPolicy.text

        XCTAssertTrue(policy.contains("Local Diagnostics"))
        XCTAssertTrue(policy.contains("Exports and Backups"))
        XCTAssertTrue(policy.contains(ClovePrivacyPolicy.effectiveDate))
        XCTAssertTrue(policy.contains(ClovePrivacyPolicy.contactURL.absoluteString))
        XCTAssertEqual(ClovePrivacyPolicy.popup.message, policy)
    }
}
