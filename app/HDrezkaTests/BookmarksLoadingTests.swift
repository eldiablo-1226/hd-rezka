import XCTest
@testable import HDrezka

/// The critique of 2026-11-11 (loading and bookmarks): the bookmark sheet, category management, request timeouts and
/// the «Продолжить просмотр» cache.
final class BookmarksLoadingTests: XCTestCase {
    // MARK: Bookmark sheet

    func testSaveFailureIsNilOnlyForSuccessTrue() {
        XCTAssertNil(BookmarksSelectionListViewComponent.saveFailure(answer: #"{"success":true}"#, error: nil))
    }

    func testSaveFailureSaysTheSiteRefusedOnSuccessFalse() {
        // A session that isn't valid on this mirror gets a 200 with success: false; script.673.js waits for success == true.
        XCTAssertEqual(BookmarksSelectionListViewComponent.saveFailure(answer: #"{"success":false,"message":"x"}"#, error: nil),
                       .rejected)
    }

    func testSaveFailureBlamesTheConnectionOnAnErrorOrAnAnswerThatIsNotJSON() {
        XCTAssertEqual(BookmarksSelectionListViewComponent.saveFailure(answer: nil, error: URLError(.timedOut)), .network)
        XCTAssertEqual(BookmarksSelectionListViewComponent.saveFailure(answer: "<html>blocked</html>", error: nil), .network)
    }

    // MARK: Categories

    func testCategoryNameIsTrimmedAndABlankOneIsRefused() {
        XCTAssertEqual(BookmarksView.validName("  Позже \n"), "Позже")
        XCTAssertNil(BookmarksView.validName("   "))
        XCTAssertNil(BookmarksView.validName(""))
    }

    func testCreatedCategoryIsNilForAnAnswerThatIsNotAnObject() throws {
        // 1.6.0 trapped on these (`as!`); a block page served with 200 now just fails the create.
        XCTAssertNil(try AccountService.createdCategory("<html></html>", name: "x"))
        XCTAssertNil(try AccountService.createdCategory("[]", name: "x"))
        XCTAssertEqual(try AccountService.createdCategory(#"{"success":true,"id":42}"#, name: "x"), Bookmark(id: 42, name: "x"))
    }

    func testOnlyAnExplicitSuccessFalseIsARefusal() {
        // script.673.js alerts the sort_cats answer only on success == false, so an answer without the flag is saved.
        XCTAssertTrue(AccountService.isRefusal(#"{"success":false,"message":"Ошибка"}"#))
        XCTAssertFalse(AccountService.isRefusal(#"{"success":true}"#))
        XCTAssertFalse(AccountService.isRefusal("{}"))
        XCTAssertFalse(AccountService.isRefusal("<html></html>"))
    }

    // MARK: Timeouts

    func testSiteRequestsGiveUpAfterFifteenSecondsWithoutData() throws {
        let request = try siteRequest("https://ijobs.app/", headers: siteHeaders(version: "", contentType: false))
        XCTAssertEqual(withSiteTimeout(request).timeoutInterval, 15)
        XCTAssertEqual(withSiteTimeout(request).url, request.url)
    }

    // MARK: Continue watching

    func testContinueWatchingCacheKeepsTheLastListAndForgetsItOnClear() throws {
        let suite = "BookmarksLoadingTests.continueWatching"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let item = MovieWatchLater(id: "https://ijobs.app/series/comedy/1-y.html", name: "Y", details: "2026",
                                   watchingInfo: "1 сезон 2 серия (Дубляж)", date: "сегодня", buttonText: nil, dataId: "7")
        XCTAssertEqual(ContinueWatchingCache.load(from: defaults), [])
        ContinueWatchingCache.save([item], to: defaults)
        XCTAssertEqual(ContinueWatchingCache.load(from: defaults), [item])
        ContinueWatchingCache.clear(defaults)
        XCTAssertEqual(ContinueWatchingCache.load(from: defaults), [])
    }

    /// A page opened from a grid starts on «Смотреть» when the account is watching the title, on whatever mirror
    /// either list came from (the site's own `active` voice acting is set on guest pages too, so it can't tell).
    func testATitleTheAccountIsWatchingIsFoundWhicheverMirrorListedIt() throws {
        let suite = "BookmarksLoadingTests.continueWatchingContains"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let item = MovieWatchLater(id: "https://ijobs.app/series/comedy/1-y.html", name: "Y", details: "2026",
                                   watchingInfo: "1 сезон 2 серия (Дубляж)", date: "сегодня", buttonText: nil, dataId: "7")
        XCTAssertFalse(ContinueWatchingCache.contains("https://ijobs.app/series/comedy/1-y.html", in: defaults))
        ContinueWatchingCache.save([item], to: defaults)
        XCTAssertTrue(ContinueWatchingCache.contains("https://ijobs.app/series/comedy/1-y.html", in: defaults))
        XCTAssertTrue(ContinueWatchingCache.contains("https://hdrezka.ag/series/comedy/1-y.html", in: defaults))
        XCTAssertTrue(ContinueWatchingCache.contains("https://ijobs.app/series/comedy/1-y-latest.html", in: defaults),
                      "the site adds -latest to some addresses: the post number is the title")
        XCTAssertFalse(ContinueWatchingCache.contains("https://ijobs.app/series/comedy/2-z.html", in: defaults))
        // The whole list, not the ten the row shows: an older title still counts.
        let many = (1...12).map { MovieWatchLater(id: "https://ijobs.app/films/drama/\($0)00-x.html", name: "\($0)", details: "",
                                                  watchingInfo: "", date: "", buttonText: nil, dataId: "\($0)") }
        ContinueWatchingCache.save(many, to: defaults)
        XCTAssertTrue(ContinueWatchingCache.contains("https://ijobs.app/films/drama/1200-x.html", in: defaults))
        defaults.removePersistentDomain(forName: suite)
    }
}
