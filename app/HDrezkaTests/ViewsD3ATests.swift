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

    // MARK: AboutUsView.isXmas() (0x1000ead04): from Dec 25 00:00 to "Dec 32" (Jan 1) 00:00 inclusive

    func testXmasWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s)))
        }
        XCTAssertFalse(AboutUsView.isXmas(on: try date(2025, 12, 24, 23, 59, 59), calendar: calendar))
        XCTAssertTrue(AboutUsView.isXmas(on: try date(2025, 12, 25), calendar: calendar))
        XCTAssertTrue(AboutUsView.isXmas(on: try date(2025, 12, 31, 23, 59, 59), calendar: calendar))
        // Jan 1 belongs to the new year, whose window has not started yet.
        XCTAssertFalse(AboutUsView.isXmas(on: try date(2026, 1, 1), calendar: calendar))
        XCTAssertFalse(AboutUsView.isXmas(on: try date(2026, 6, 1), calendar: calendar))
    }

    // MARK: AboutUsView version line and init(allowDebug:) (0x1000ea778)

    func testVersionText() {
        let os = SystemVersion().osString
        let known = AboutUsView(allowDebug: .constant(false), appVersion: "1.6.0", buildVerison: "570")
        XCTAssertEqual(known.versionText, "v1.6.0, build 570, OS \(os)")
        let unknown = AboutUsView(allowDebug: .constant(false), appVersion: nil, buildVerison: nil)
        XCTAssertEqual(unknown.versionText, "vUNKNOWN VERSION, build UNKNOWN BUILD, OS \(os)")
    }

    func testAboutUsInitReadsBundleVersions() {
        let view = AboutUsView(allowDebug: .constant(false))
        XCTAssertEqual(view.appVersion, Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        XCTAssertEqual(view.buildVerison, Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        XCTAssertNotNil(view.appVersion)
    }
}
