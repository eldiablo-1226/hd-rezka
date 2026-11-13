import XCTest
import SwiftUI
@testable import HDrezka

/// Logic of the profile / account / settings / downloads screens (area d3). Nothing here touches the network:
/// the sign-up checks are only driven into branches that fail before any request.
final class ProfileAccountViewTests: XCTestCase {

    // MARK: PremiumStatus

    /// improvement: three days or fewer is flagged with a warning symbol, not ember text (ember marks what can be tapped).
    func testPremiumIsRunningOutAtThreeDaysOrFewer() {
        XCTAssertEqual(PremiumStatus(raw: "3 дня")?.isRunningOut, true)
        XCTAssertEqual(PremiumStatus(raw: "1 день")?.isRunningOut, true)
        XCTAssertEqual(PremiumStatus(raw: "97 дней")?.isRunningOut, false)
        XCTAssertEqual(PremiumStatus(raw: "Активен")?.isRunningOut, false, "no number, nothing to count down")
    }

    func testPremiumStatusEmptyOrBlankIsNil() {
        XCTAssertNil(PremiumStatus(raw: ""))
        XCTAssertNil(PremiumStatus(raw: "  \n\t "))
    }

    func testPremiumStatusKeepsTrimmedTextAndJoinsAllDigits() {
        let status = PremiumStatus(raw: "  23 дня\n")
        XCTAssertEqual(status?.daysLeft, 23)
        XCTAssertEqual(status?.rawText, "23 дня")

        let text = PremiumStatus(raw: "Premium")
        XCTAssertNotNil(text)
        XCTAssertNil(text?.daysLeft)
        XCTAssertEqual(text?.rawText, "Premium")

        // Every digit counts, as in the binary: a date becomes one big number.
        XCTAssertEqual(PremiumStatus(raw: "до 12.05")?.daysLeft, 1205)
    }

    func testDayWordFollowsRussianPluralRules() {
        let expected: [Int: String] = [0: "many", 1: "one", 2: "few", 4: "few", 5: "many", 11: "many", 12: "many",
                                       14: "many", 21: "one", 22: "few", 25: "many", 101: "one", 111: "many",
                                       112: "many", 122: "few", -1: "many"]
        for (days, form) in expected {
            XCTAssertEqual(PremiumStatus.dayWordKey(for: days), "key_days_" + form, "days = \(days)")
        }
        XCTAssertEqual(PremiumStatus.dayWord(for: 21), String(localized: "key_days_one"))
        XCTAssertEqual(PremiumStatus.dayWord(for: 3), String(localized: "key_days_few"))
    }

    // MARK: RegisterView

    @MainActor
    func testEmailRegex() {
        let view = RegisterView()
        XCTAssertTrue(view.isValidEmail("user.name+tag@example.com"))
        XCTAssertTrue(view.isValidEmail("a@b.c"))
        XCTAssertFalse(view.isValidEmail("user@example"))
        XCTAssertFalse(view.isValidEmail("user name@example.com"))
        XCTAssertFalse(view.isValidEmail("@example.com"))
        XCTAssertFalse(view.isValidEmail(""))
    }

    @MainActor
    func testCheckoutValidationOrderAndMessages() async throws {
        let view = RegisterView()
        func check(_ email: String, _ name: String, _ pass: String, _ confirm: String) async throws -> String? {
            try await view.checkout(email: email, name: name, pass: pass, conf_pass: confirm)
        }
        let mail = String(localized: "key_mail+not+valid")
        let nameLength = String(localized: "key_wrong+username+lenght")
        let passLength = String(localized: "key_wrong+password+length")
        let mismatch = String(localized: "key_passwords+does+not+match")

        // The e-mail is checked first, then the name length (3...30), the password length, the confirmation.
        let result1 = try await check("bad", "ab", "1", "2")
        XCTAssertEqual(result1, mail)
        let result2 = try await check("a@b.cd", "ab", "1", "2")
        XCTAssertEqual(result2, nameLength)
        let result3 = try await check("a@b.cd", String(repeating: "x", count: 31), "123456", "123456")
        XCTAssertEqual(result3, nameLength)
        let result4 = try await check("a@b.cd", "abc", "12345", "12345")
        XCTAssertEqual(result4, passLength)
        let result5 = try await check("a@b.cd", String(repeating: "x", count: 30), "123456", "1234567")
        XCTAssertEqual(result5, mismatch)
        // An empty password skips the length check (only 1...5 fails) and still has to match.
        let result6 = try await check("a@b.cd", "abc", "", "x")
        XCTAssertEqual(result6, mismatch)
    }

    // MARK: ProfileView

    /// critique r2: «Загрузки» is a labelled row of the profile's list that says how many files are ready, signed in or
    /// not (files on the device need no account). It was an unlabelled arrow in the far corner of the bar.
    @MainActor
    func testDownloadsIsALabelledRowSignedInOrNot() throws {
        let wasOn = try setAccessibilityAutomation(true)
        defer { _ = try? setAccessibilityAutomation(wasOn) }
        let suite = "ProfileAccountViewTests.downloadsRow"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = DownloadManager.shared
        let saved = manager.downloads
        defer { manager.downloads = saved }
        func download(_ state: DownloadState) -> Download {
            Download(id: UUID(), title: "t", subtitle: "", poster: "", quality: "720p", sourceURL: "", fileName: "x.mp4",
                     state: state, createdAt: Date(), destination: .app, receivedBytes: 0, totalBytes: 0)
        }
        manager.downloads = [download(.completed), download(.paused), download(.completed)]
        let downloads = NSLocalizedString("Downloads", comment: "")
        for isLoggedIn in [false, true] {
            defaults.set(isLoggedIn, forKey: "isLoggedIn")
            let host = UIHostingController(rootView: ProfileView(isPresentedDetail: .constant(false), id: .constant(""))
                .environmentObject(manager)
                .defaultAppStorage(defaults))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            let leaves = accessibilityLeaves(in: host.view)
            window.isHidden = true
            let row = try XCTUnwrap(leaves.first { ($0.accessibilityLabel ?? "").hasPrefix(downloads) },
                                    "signed in: \(isLoggedIn); \(leaves.map { $0.accessibilityLabel ?? "" })")
            XCTAssertGreaterThan(row.accessibilityFrame.width, 200, "signed in: \(isLoggedIn); a row, not a symbol in the bar")
            XCTAssertTrue(((row.accessibilityLabel ?? "") + (row.accessibilityValue ?? "")).contains("2"),
                          "signed in: \(isLoggedIn); two files are ready: \(row.accessibilityLabel ?? "") \(row.accessibilityValue ?? "")")
        }
    }

    // MARK: DownloadRow

    func testByteStringUsesFileStyleAndDownloadedForZero() {
        let download = Download(id: UUID(), title: "t", subtitle: "", poster: "", quality: "720p", sourceURL: "",
                                fileName: "x.mp4", state: .completed, createdAt: Date(), destination: .app,
                                receivedBytes: 0, totalBytes: 0)
        let row = DownloadRow(download: download, onTap: {})
        XCTAssertEqual(row.byteString(0), String(localized: "key_downloaded_status"))
        XCTAssertEqual(row.byteString(-1), String(localized: "key_downloaded_status"))
        XCTAssertEqual(row.byteString(1_500_000), ByteCountFormatter.string(fromByteCount: 1_500_000, countStyle: .file))
    }
}
