import XCTest
@testable import HDrezka

/// Logic of the account and downloads screens (area d3b). Nothing here touches the network: the sign-up
/// checks are only driven into branches that fail before AccountService is called.
final class ViewsD3BTests: XCTestCase {

    // MARK: RegisterView.isValidEmail (0x1000f10f4, NSPredicate "SELF MATCHES %@")

    @MainActor
    func testEmailRegexPinsTheOriginalPattern() {
        let view = RegisterView()
        // Local part: 1...256 of [a-zA-Z0-9+._%-].
        XCTAssertTrue(view.isValidEmail("a_b%c-d+e.f@x.yz"))
        XCTAssertTrue(view.isValidEmail(String(repeating: "a", count: 256) + "@b.c"))
        XCTAssertFalse(view.isValidEmail(String(repeating: "a", count: 257) + "@b.c"))
        XCTAssertFalse(view.isValidEmail("й@b.c"))
        XCTAssertFalse(view.isValidEmail(" a@b.c"))
        // First domain label: one alphanumeric, then up to 64 of [a-zA-Z0-9-].
        XCTAssertTrue(view.isValidEmail("a@b" + String(repeating: "-", count: 64) + ".c"))
        XCTAssertFalse(view.isValidEmail("a@b" + String(repeating: "c", count: 65) + ".c"))
        XCTAssertFalse(view.isValidEmail("a@-b.c"))
        // At least one more label: a dot, one alphanumeric, then up to 25 of [a-zA-Z0-9-].
        XCTAssertTrue(view.isValidEmail("a@b.c-"), "a trailing hyphen passes, as in the original")
        XCTAssertTrue(view.isValidEmail("a@b.c." + String(repeating: "d", count: 26)))
        XCTAssertFalse(view.isValidEmail("a@b." + String(repeating: "d", count: 27)))
        XCTAssertFalse(view.isValidEmail("a@b"))
        XCTAssertFalse(view.isValidEmail("a@b..c"))
    }

    // MARK: RegisterView.checkout, local checks only (0x1000f09b4)

    @MainActor
    func testCheckoutAcceptsNamesOfThreeToThirtyCharacters() async throws {
        let view = RegisterView()
        let nameLength = String(localized: "key_wrong+username+lenght")
        let mismatch = String(localized: "key_passwords+does+not+match")
        // A mismatching confirmation stops every accepted name before the network checks.
        for name in ["", "ab", String(repeating: "я", count: 31)] {
            let result = try await view.checkout(email: "a@b.cd", name: name, pass: "123456", conf_pass: "654321")
            XCTAssertEqual(result, nameLength, "\(name.count) characters")
        }
        for name in ["abc", String(repeating: "я", count: 30)] {
            let result = try await view.checkout(email: "a@b.cd", name: name, pass: "123456", conf_pass: "654321")
            XCTAssertEqual(result, mismatch, "\(name.count) characters")
        }
    }

    @MainActor
    func testCheckoutRejectsOnlyPasswordsOfOneToFiveCharacters() async throws {
        let view = RegisterView()
        let passLength = String(localized: "key_wrong+password+length")
        let mismatch = String(localized: "key_passwords+does+not+match")
        for pass in ["1", "12345"] {
            let result = try await view.checkout(email: "a@b.cd", name: "abc", pass: pass, conf_pass: pass)
            XCTAssertEqual(result, passLength, "\(pass.count) characters")
        }
        // Six and more characters, and the empty password, go on to the confirmation check.
        for pass in ["", "123456"] {
            let result = try await view.checkout(email: "a@b.cd", name: "abc", pass: pass, conf_pass: pass + "x")
            XCTAssertEqual(result, mismatch, "\(pass.count) characters")
        }
    }

    @MainActor
    func testCheckoutValidatesTheEmailBeforeEverythingElse() async throws {
        let view = RegisterView()
        let result = try await view.checkout(email: "a@b", name: "", pass: "1", conf_pass: "2")
        XCTAssertEqual(result, String(localized: "key_mail+not+valid"))
    }

    // MARK: Bookmarks (binary facts a review pass restored)

    @MainActor
    func testBookmarkMovieListWritesTheColorSchemeTwiceWithTheSecondOutermost() {
        // body 0x100061f50 (0x10043bfa0): two nil writers, the outermost layer the second. improvement: the
        // onDisappear that cleared the grid is gone (BookmarkMovieListView keeps its pages), so it no longer sits under it.
        let view = BookmarkMovieListView(name: "", id: 0)
        let type = String(describing: Swift.type(of: view.body))
        XCTAssertEqual(type.components(separatedBy: "PreferredColorSchemeKey").count - 1, 2, type)
        XCTAssertTrue(type.hasSuffix("_PreferenceWritingModifier<PreferredColorSchemeKey>>"), type)
    }

    // MARK: DownloadRow (byteString 0x10010421c; the progress text is inlined into statusLine 0x100103c7c / 0x100103ef8)

    private func download(received: Int64, total: Int64) -> Download {
        Download(id: UUID(), title: "Title", subtitle: "S1E1", poster: "", quality: "720p", sourceURL: "",
                 fileName: "x.mp4", state: .downloading, createdAt: Date(), destination: .app,
                 receivedBytes: received, totalBytes: total)
    }

    @MainActor
    func testProgressTextAddsTheTotalOnlyWhenItIsKnown() {
        let row = DownloadRow(download: download(received: 1_500_000, total: 3_000_000), onTap: {})
        XCTAssertEqual(row.progressText, row.byteString(1_500_000) + " / " + row.byteString(3_000_000))
        let unknownTotal = DownloadRow(download: download(received: 1_500_000, total: 0), onTap: {})
        XCTAssertEqual(unknownTotal.progressText, row.byteString(1_500_000))
    }

    @MainActor
    func testProgressTextBeforeTheFirstByteReadsDownloaded() {
        // byteString(0) is the "Downloaded" text, so a fresh download shows it, as the original does.
        let downloaded = String(localized: "key_downloaded_status")
        let fresh = DownloadRow(download: download(received: 0, total: 0), onTap: {})
        XCTAssertEqual(fresh.progressText, downloaded)
        let sized = DownloadRow(download: download(received: 0, total: 2048), onTap: {})
        XCTAssertEqual(sized.progressText,
                       downloaded + " / " + ByteCountFormatter.string(fromByteCount: 2048, countStyle: .file))
    }

    @MainActor
    func testByteStringIsFileStyleFromOneByte() {
        let row = DownloadRow(download: download(received: 0, total: 0), onTap: {})
        XCTAssertEqual(row.byteString(1), ByteCountFormatter.string(fromByteCount: 1, countStyle: .file))
        let fiveGB = Int64(5) << 30
        XCTAssertEqual(row.byteString(fiveGB), ByteCountFormatter.string(fromByteCount: fiveGB, countStyle: .file))
    }
}
