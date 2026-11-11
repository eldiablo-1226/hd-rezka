import SwiftUI
import XCTest
@testable import HDrezka

/// Non-UI logic of the profile/settings screens (area d3a).
final class ViewsD3ATests: XCTestCase {
    // MARK: PremiumStatus.init(raw:) (0x1000fcfcc)

    func testPremiumStatusIsNilForBlankText() {
        XCTAssertNil(PremiumStatus(raw: ""))
        XCTAssertNil(PremiumStatus(raw: "  \n\t "))
    }

    func testPremiumStatusTrimsAndReadsDays() {
        let status = PremiumStatus(raw: "  осталось 25 дней \n")
        XCTAssertEqual(status?.daysLeft, 25)
        XCTAssertEqual(status?.rawText, "осталось 25 дней")
    }

    func testPremiumStatusJoinsEveryDigit() {
        XCTAssertEqual(PremiumStatus(raw: "до 01.02.2026")?.daysLeft, 1_022_026)
    }

    func testPremiumStatusWithoutDigitsKeepsText() {
        let status = PremiumStatus(raw: "Premium")
        XCTAssertNotNil(status)
        XCTAssertNil(status?.daysLeft)
        XCTAssertEqual(status?.rawText, "Premium")
    }

    // MARK: PremiumStatus.dayWord(for:) (0x1000fd940) through the card text

    func testDisplayTextUsesRussianPluralRules() {
        let cases: [(Int, String)] = [
            (1, "one"), (21, "one"), (101, "one"),
            (2, "few"), (3, "few"), (4, "few"), (22, "few"), (104, "few"),
            (0, "many"), (5, "many"), (11, "many"), (12, "many"), (13, "many"), (14, "many"),
            (15, "many"), (20, "many"), (111, "many"), (112, "many"), (114, "many"),
        ]
        for (days, form) in cases {
            let key = "key_days_" + form
            // The key is checked directly: in English (the test simulator) few and many both read "days".
            XCTAssertEqual(PremiumStatus.dayWordKey(for: days), key, "days = \(days)")
            XCTAssertEqual(PremiumStatus(raw: "\(days)")?.displayText,
                           "\(days) " + String(localized: String.LocalizationValue(key)), "days = \(days)")
        }
    }

    func testDisplayTextFallsBackToRawText() {
        XCTAssertEqual(PremiumStatus(raw: " Premium ")?.displayText, "Premium")
    }

}
