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

    /// critique r1: a link opens in the tab on screen only (ContentView); the others keep their place.
    func testLinkOpensInTheTabOnScreenOnly() {
        var links = TabLinks()
        links.profile.id = "https://ijobs.app/films/x/1-earlier.html"
        links.open(filmPage, in: .profile)
        XCTAssertTrue(links.profile.isPresented)
        XCTAssertEqual(links.profile.id, filmPage)
        for other in [links.home, links.catalog, links.search] {
            XCTAssertFalse(other.isPresented)
            XCTAssertEqual(other.id, "")
        }
        links.profile.isPresented = false
        links.open(filmPage, in: .search)
        XCTAssertFalse(links.profile.isPresented, "Back in one tab stays closed when the next link opens elsewhere")
        XCTAssertEqual(links.profile.id, filmPage, "the popped page keeps its id")
        XCTAssertTrue(links.search.isPresented)
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

    // improvement: at accessibility sizes the grids show two columns and a card fills its column, so a title wraps
    // instead of ending as «Дюна: Часть вто…» under a 113 pt poster.
    func testGridsShowTwoColumnsAtAccessibilitySizes() {
        XCTAssertEqual(TitleCardComponent.columnMinimum(.large), 100)
        XCTAssertEqual(TitleCardComponent.columnMinimum(.xxxLarge, phone: 110), 110)
        XCTAssertEqual(TitleCardComponent.columnMinimum(.accessibility1), 150)
        XCTAssertEqual(TitleCardComponent.columnMinimum(.accessibility5, phone: 110), 150)
    }

    @MainActor
    func testACardFillsItsColumnOnlyAtAccessibilitySizes() {
        let movie = MovieSimple(id: "x", name: "Дюна: Часть вторая", details: "2024, США, Фантастика", poster: "")
        func height(_ size: DynamicTypeSize, width: CGFloat, inRow: Bool = false) -> CGFloat {
            let card = TitleCardComponent(model: movie, fillsColumn: !inRow).environment(\.dynamicTypeSize, size)
            return UIHostingController(rootView: card)
                .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        XCTAssertEqual(height(.large, width: 240), height(.large, width: 180), "the phone's 113 pt poster")
        XCTAssertGreaterThan(height(.accessibility2, width: 240), height(.accessibility2, width: 180))
        XCTAssertEqual(height(.accessibility2, width: 240, inRow: true), height(.accessibility2, width: 180, inRow: true),
                       "a card in a horizontal row keeps its width")
    }

    /// In the person page's horizontal row nothing gives the card a width: its text block keeps the phone's 112 pt, so
    /// a short title starts at the poster's edge instead of being centred under it.
    @MainActor
    func testACardInARowKeepsItsTitleAtThePostersEdge() throws {
        let wasOn = try setAccessibilityAutomation(true)
        defer { _ = try? setAccessibilityAutomation(wasOn) }
        let movie = MovieSimple(id: "x", name: "Дюна", details: "2021", poster: "")
        let host = UIHostingController(rootView: ScrollView(.horizontal) {
            HStack { TitleCardComponent(model: movie, fillsColumn: false) }
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        let title = try XCTUnwrap(accessibilityLeaves(in: host.view).first { $0.accessibilityLabel == "Дюна" })
        XCTAssertLessThan(title.accessibilityFrame.minX, 2, "the title starts \(title.accessibilityFrame.minX) pt in")
    }

    /// critique r2: the link to a row's whole list is «Все» on Home and on a person, with a 44 pt target and a header
    /// VoiceOver can jump to. It was «Все» and «больше», each the size of its text.
    @MainActor
    func testSeeAllIsOneWordWithA44PointTarget() throws {
        let wasOn = try setAccessibilityAutomation(true)
        defer { _ = try? setAccessibilityAutomation(wasOn) }
        let movie = MovieSimple(id: "x", name: "Дюна", details: "2021", poster: "")
        let host = UIHostingController(rootView: NavigationStack {
            PesonHorizontalGrid(movies: [movie], title: "key_actor", isNavigated: .constant(false))
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        let leaves = accessibilityLeaves(in: host.view)
        let all = try XCTUnwrap(leaves.first { $0.accessibilityLabel == NSLocalizedString("key_all", comment: "") },
                                "\(leaves.map { $0.accessibilityLabel ?? "" })")
        XCTAssertGreaterThanOrEqual(all.accessibilityFrame.width, 44)
        XCTAssertGreaterThanOrEqual(all.accessibilityFrame.height, 44)
        let header = try XCTUnwrap(leaves.first { $0.accessibilityLabel == NSLocalizedString("key_actor", comment: "") })
        XCTAssertTrue(header.accessibilityTraits.contains(.header))
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
