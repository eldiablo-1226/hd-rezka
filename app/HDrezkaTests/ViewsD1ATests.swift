import XCTest
import SwiftUI
@testable import HDrezka

/// App shell, home and common views (area d1a): links, start-page mapping, list paging requests, strings.
final class ViewsD1ATests: XCTestCase {
    private let filmPage = "https://ijobs.app/films/fiction/646-matrica-1999.html"

    // MARK: hdr:// deep links (HDRezkaApp.onOpenURL, 0x1000feaa0)

    func testDeepLinkBecomesFilmPageOnTheHardCodedHost() {
        XCTAssertEqual(HDRezkaApp.filmURL(fromDeepLink: URL(string: "hdr://films/fiction/646-matrica-1999")!), filmPage)
        XCTAssertEqual(HDRezkaApp.filmURL(fromDeepLink: URL(string: "hdr://series/drama/1605-gavayi-5-0")!),
                       "https://ijobs.app/series/drama/1605-gavayi-5-0.html")
    }

    func testBareSchemeOpensNothing() {
        XCTAssertNil(HDRezkaApp.filmURL(fromDeepLink: URL(string: "hdr://")!))
    }

    // MARK: ShareButton (0x10010f254)

    func testSiteLinkSwapsTheMirrorForThePublicDomain() {
        XCTAssertEqual(ShareButton.siteLink(filmPage), "https://rezka.ag/films/fiction/646-matrica-1999.html")
    }

    func testUniversalLinkDropsSchemeHostAndExtension() {
        XCTAssertEqual(ShareButton.universalLink(filmPage), "hdr://films/fiction/646-matrica-1999")
        XCTAssertEqual(ShareButton.universalLink("https://hdrezka.ag/films/fiction/646-matrica-1999.html"),
                       "hdr://films/fiction/646-matrica-1999")
        // removeMirror() keeps strings that do not start with "http".
        XCTAssertEqual(ShareButton.universalLink("films/fiction/646-matrica-1999.html"), "hdr://films/fiction/646-matrica-1999")
    }

    func testUniversalLinkOpensTheSameFilm() {
        XCTAssertEqual(HDRezkaApp.filmURL(fromDeepLink: URL(string: ShareButton.universalLink(filmPage))!), filmPage)
    }

    // MARK: start page (HomeView / HomeGridViewIpad)

    func testStartPageFilterIsTheCaseName() {
        XCTAssertEqual(StartupPageVariation.allCases.map(HomeView.filter(for:)), ["watching", "last", "popular", "soon"])
    }

    @MainActor
    func testFirstPageOfLatestReleasesIsTheStartPage() {
        let network = Network()
        XCTAssertEqual(network.moviesURL(page: 1, filter: HomeView.filter(for: .last)), "https://\(network.settingStore)/?filter=last")
        XCTAssertEqual(network.moviesURL(page: 1, filter: HomeView.filter(for: .watching)),
                       "https://\(network.settingStore)/page/1/?filter=watching")
    }

    // MARK: MovieListView paging (0x10009061c, 0x10008faa4)

    func testListPageIsAGETWithTheTwoAppHeaders() throws {
        let request = try MovieListView.pageRequest(listURL: "https://ijobs.app/films/best/2012", page: 2, version: "2.2.5")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/films/best/2012/page/2")
        XCTAssertEqual(request.allHTTPHeaderFields, ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": "2.2.5"])
        XCTAssertNil(request.httpBody)
    }

    func testListPageAppendsToTheGivenURLAsIs() throws {
        // The binary concatenates `id + "/page/" + n` without normalising a trailing slash.
        let request = try MovieListView.pageRequest(listURL: "https://ijobs.app/films/best/2012/", page: 1, version: "")
        XCTAssertEqual(request.url?.absoluteString, "https://ijobs.app/films/best/2012//page/1")
    }

    // MARK: SystemVersion (inlined in UINavigationController.viewDidLoad, 0x1000e006c)

    func testSystemVersionReadsProcessInfo() {
        let version = SystemVersion()
        XCTAssertEqual(version.os.majorVersion, ProcessInfo().operatingSystemVersion.majorVersion)
        XCTAssertEqual(version.osString, ProcessInfo().operatingSystemVersionString)
    }

    // improvement: the poster badge keeps progress readable at 11pt; the site's "(все серии)" adds nothing to "Завершен".
    func testBadgeShortensOnlyTheCompletedPhrase() {
        XCTAssertEqual(TitleBadge.shortInfo("Завершен (все серии)"), "Завершен")
        XCTAssertEqual(TitleBadge.shortInfo("2 сезон, 26 серия"), "2 сезон, 26 серия")
    }

    // MARK: strings used by the shell, home and share views

    func testLocalizationKeysExistInEveryTable() throws {
        let keys = ["Home", "Search", "key_collections", "key_profile", "key_share+with+url", "key_share+with+universal+link",
                    "key_page+not+loaded", "key_retry", "key_unparsable_title", "key_unparsable_text"]
            + ["key_mode_watch", "key_mode_about", "key_mode_about_series", "key_mode_picker", "key_season_number",
               "key_episode_number", "key_resume_from", "key_all_voices %lld", "key_fewer_voices", "key_voice_camrip",
               "key_voice_ads", "key_voice_directors_cut", "key_seasons_failed", "key_read_more", "key_read_less",
               "key_remember_quality", "key_remember_quality_hint", "key_last_used", "key_mirrors_known",
               "key_mirrors_known_footer", "key_mirror_default", "key_mirror_needs_login", "key_mirror_custom",
               "key_mirror_custom_placeholder", "key_mirror_custom_footer"]
            + StartupPageVariation.allCases.map(\.rawValue)
        for language in ["en", "ru", "uk"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), language)
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: "<missing>", table: nil), "<missing>", "\(language): \(key)")
            }
        }
    }
}
