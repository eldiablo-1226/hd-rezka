import XCTest
@testable import HDrezka

/// Non-UI logic of the shell, home, search, collections and common views (area d1).
final class ShellCatalogViewTests: XCTestCase {
    private let filmPage = "https://ijobs.app/films/fiction/646-matrica-1999.html"

    // MARK: hdr:// links

    func testDeepLinkOpensFilmPageOnHardCodedMirror() {
        XCTAssertEqual(HDRezkaApp.filmURL(fromDeepLink: URL(string: "hdr://films/fiction/646-matrica-1999")!), filmPage)
    }

    func testBareSchemeIsIgnored() {
        XCTAssertNil(HDRezkaApp.filmURL(fromDeepLink: URL(string: "hdr://")!))
    }

    func testShareLinks() {
        XCTAssertEqual(ShareButton.siteLink(filmPage), "https://rezka.ag/films/fiction/646-matrica-1999.html")
        XCTAssertEqual(ShareButton.universalLink(filmPage), "hdr://films/fiction/646-matrica-1999")
    }

    func testUniversalLinkRoundTripsThroughOnOpenURL() {
        let link = URL(string: ShareButton.universalLink(filmPage))!
        XCTAssertEqual(HDRezkaApp.filmURL(fromDeepLink: link), filmPage)
    }

    // MARK: start page

    func testStartPageFilterIsTheCaseName() {
        XCTAssertEqual(StartupPageVariation.allCases.map(HomeView.filter(for:)), ["watching", "last", "popular", "soon"])
    }

    @MainActor
    func testStartPageRequestsGoThroughNetworkMoviesURL() {
        let network = Network()
        XCTAssertEqual(network.moviesURL(page: 1, filter: HomeView.filter(for: .last)),
                       "https://\(network.settingStore)/?filter=last")
        XCTAssertEqual(network.moviesURL(page: 2, filter: HomeView.filter(for: .popular)),
                       "https://\(network.settingStore)/page/2/?filter=popular")
    }

    // MARK: requests built by the views

    func testQuickSearchRequest() throws {
        let request = try SearchView.quickSearchRequest(mirror: "ijobs.app", version: "2.2.5", text: "the matrix")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/engine/ajax/search.php/?q=the%20matrix")
        assertAppHeaders(request)
    }

    func testFullSearchRequestKeepsTheSiteQuery() throws {
        let request = try SearchResultsView.searchRequest(mirror: "ijobs.app", version: "2.2.5", query: "matrix")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/search/?do=search&subaction=search&q=matrix")
        assertAppHeaders(request)
    }

    func testMovieListPageRequest() throws {
        let request = try MovieListView.pageRequest(listURL: "https://ijobs.app/films/best/2020", page: 3, version: "2.2.5")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/films/best/2020/page/3")
        assertAppHeaders(request)
    }

    // MARK: SystemVersion

    func testSystemVersionReadsProcessInfo() {
        let version = SystemVersion()
        XCTAssertEqual(version.os.majorVersion, ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        XCTAssertEqual(version.osString, ProcessInfo.processInfo.operatingSystemVersionString)
    }

    private func assertAppHeaders(_ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Hdrezka-Ios-App"), "1", file: file, line: line)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Hdrezka-Ios-App-Version"), "2.2.5", file: file, line: line)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"), file: file, line: line)
    }
}
