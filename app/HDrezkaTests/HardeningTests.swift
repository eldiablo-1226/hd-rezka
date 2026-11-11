import XCTest
import SwiftUI
import Combine
import Alamofire
import SwiftSoup
@testable import HDrezka

/// improvement (harden): what a failed page load tells the user, the mirror a user types in, and sheets that must not trap.
final class HardeningTests: XCTestCase {
    // MARK: why a page did not load

    func testNoConnectionIsOffline() {
        XCTAssertEqual(PageLoadFailure(error: URLError(.notConnectedToInternet), statusCode: nil), .offline)
        XCTAssertEqual(PageLoadFailure(error: URLError(.networkConnectionLost), statusCode: nil), .offline)
    }

    func testDeadOrBlockedMirrorIsUnreachable() {
        XCTAssertEqual(PageLoadFailure(error: URLError(.cannotFindHost), statusCode: nil), .unreachable)
        XCTAssertEqual(PageLoadFailure(error: URLError(.timedOut), statusCode: nil), .unreachable)
        XCTAssertEqual(PageLoadFailure(error: nil, statusCode: 500), .unreachable)
        XCTAssertEqual(PageLoadFailure(error: nil, statusCode: 503), .unreachable)
    }

    /// Alamofire wraps the URLSession error; that is what the views actually receive.
    func testAlamofireWrappedErrorsAreUnwrapped() {
        let wrapped = AFError.sessionTaskFailed(error: URLError(.cannotConnectToHost))
        XCTAssertEqual(PageLoadFailure(error: wrapped, statusCode: nil), .unreachable)
        let offline = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        XCTAssertEqual(PageLoadFailure(error: offline, statusCode: nil), .offline)
    }

    /// The mirror answers guests with 403 on film pages (re/IMPROVEMENTS.md); after login the same request gets 200.
    /// The session cookie belongs to one mirror, so after a mirror switch a "logged in" user is a guest there too.
    func testForbiddenAsksToLogIn() {
        XCTAssertEqual(PageLoadFailure(error: nil, statusCode: 403), .needsLogin)
    }

    /// siteString validates the status, so pages loaded through it fail with Alamofire's validation error.
    func testValidationFailuresCarryTheirStatus() {
        let forbidden = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))
        XCTAssertEqual(PageLoadFailure(error: forbidden, statusCode: nil), .needsLogin)
        let unavailable = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 503))
        XCTAssertEqual(PageLoadFailure(error: unavailable, statusCode: nil), .unreachable)
    }

    func testAnythingElseIsOther() {
        XCTAssertEqual(PageLoadFailure(error: nil, statusCode: nil), .other)
        XCTAssertEqual(PageLoadFailure(error: nil, statusCode: 200), .other, "a 200 that is not a movie page")
        XCTAssertEqual(PageLoadFailure(error: URLError(.cancelled), statusCode: nil), .other)
    }

    /// The site answered, but the parser could not read the page. The person page trapped on such a page; the error
    /// then said the mirror may be blocked, and a logged-in user who switches mirror is a guest there (403 on film pages).
    func testParserErrorsMeanThePageCouldNotBeRead() {
        let notAPage = "<html><body>Доступ ограничен</body></html>"
        XCTAssertThrowsError(try MovieDetailsParser().parseMovieDetails(html: notAPage, movieId: "1")) {
            XCTAssertEqual(PageLoadFailure(error: $0, statusCode: nil), .unparsable)
        }
        XCTAssertThrowsError(try SwiftSoup.parse(notAPage).select("")) {
            XCTAssertEqual(PageLoadFailure(error: $0, statusCode: nil), .unparsable, "SwiftSoup's own errors")
        }
        XCTAssertThrowsError(try PeopleParser().parse(html: notAPage)) {
            XCTAssertEqual(PageLoadFailure(error: $0, statusCode: nil), .unparsable)
        }
    }

    /// Retry is always there; for a page the app could not read it is the only button. «Войти» is for 403, and
    /// «Сменить зеркало» would not help: the mirror answered.
    func testUnreadablePageOffersOnlyRetry() {
        let failure = PageLoadFailure(error: PageParseError(missing: "div.b-sidecover"), statusCode: 200)
        XCTAssertNotEqual(failure, .needsLogin)
        XCTAssertFalse(failure.suggestsMirrorChange)
    }

    func testOnlyMirrorProblemsOfferAnotherMirror() {
        XCTAssertEqual([PageLoadFailure.offline, .unreachable, .needsLogin, .unparsable, .other].map(\.suggestsMirrorChange),
                       [false, true, false, false, true])
    }

    // MARK: mirror typed by the user

    /// improvement: the known mirrors, checked on 2026-11-11 from the user's network the way the app asks for them: the
    /// catalogue, HDRezka's own static CDN, and the default mirror's DNS host and address range. Clones on other
    /// infrastructure (they would get the user's password) stay out.
    func testKnownMirrorsAreValidHostsLedByTheDefault() {
        let hosts = DefaultSettings.knownMirrors.map(\.host)
        XCTAssertEqual(hosts.first, DefaultSettings.mirror)
        XCTAssertEqual(Set(hosts).count, hosts.count, "no duplicates")
        for host in hosts {
            XCTAssertEqual(MirrorSettingsView.normalizedMirror(host), host, host)
        }
        XCTAssertFalse(hosts.contains("hdrezka.film"), "a clone on other infrastructure")
        XCTAssertFalse(hosts.contains("hdrezka.inc"), "a clone on other infrastructure")
        XCTAssertEqual(DefaultSettings.knownMirrors.filter(\.needsLogin).map(\.host), ["hdrezka.cm", "standby-rezka.tv"])
    }

    func testMirrorIsReducedToItsHost() {
        XCTAssertEqual(MirrorSettingsView.normalizedMirror("rezka.ag"), "rezka.ag")
        XCTAssertEqual(MirrorSettingsView.normalizedMirror("  HTTPS://HDRezka.AG/films/ \n"), "hdrezka.ag")
        XCTAssertEqual(MirrorSettingsView.normalizedMirror("http://hdrezka.me"), "hdrezka.me")
        XCTAssertEqual(MirrorSettingsView.normalizedMirror("ijobs.app/"), "ijobs.app")
        XCTAssertEqual(MirrorSettingsView.normalizedMirror("new-mirror.co.uk"), "new-mirror.co.uk")
    }

    /// Every request is built as "https://<mirror>/…", so anything but a bare host would break or redirect them.
    func testMirrorRejectsWhatIsNotAHost() {
        for input in ["", "   ", "rezka", "re zka.ag", "ftp://rezka.ag", "user@rezka.ag", "rezka.ag:8080",
                      "-rezka.ag", "rezka..ag", "rezka.ag.", "резка.рф", "rezka.ag?q=1", "javascript:alert(1)",
                      // Clusters that start with an ASCII letter: a combining accent, a zero-width joiner, a keycap.
                      "rezq\u{301}a.ag", "rezka\u{200D}.ag", "1\u{20E3}.ag", "İjobs.app",
                      String(repeating: "a", count: 64) + ".ag"] {
            XCTAssertNil(MirrorSettingsView.normalizedMirror(input), input)
        }
    }

    /// A film page id is the absolute URL from the listing, with the host of the mirror it was listed on
    /// (or ijobs.app for hdr:// links); a retry after a mirror change must go to the new mirror.
    func testFilmPageIsRequestedFromTheCurrentMirror() {
        XCTAssertEqual(DetailsViewComponent.pageURL("https://ijobs.app/films/drama/93758-otmschenie-moe-1984.html", mirror: "hdrezka.me"),
                       "https://hdrezka.me/films/drama/93758-otmschenie-moe-1984.html")
        XCTAssertEqual(DetailsViewComponent.pageURL("https://ijobs.app/films/x.html?a=1", mirror: "ijobs.app"),
                       "https://ijobs.app/films/x.html?a=1")
        XCTAssertEqual(DetailsViewComponent.pageURL("not a url", mirror: "hdrezka.me"), "not a url")
    }

    // MARK: Home

    /// Pull to refresh starts over: the grid's paging cell asks for `page + 1`, so page must be back at 1. The list stays
    /// on screen until page 1 replaces it (CatalogSliceTests).
    @MainActor
    func testRefreshStartsHomeFromPageOne() {
        let network = Network()
        network.movies = [.placeholder]
        network.moviesLoadFailed = true
        let generation = network.moviesGeneration
        var page = 3
        HomeView.refresh(network, page: Binding(get: { page }, set: { page = $0 }), variation: .watching)
        XCTAssertEqual(page, 1, "setting page fetches page 1 through the views' onChange")
        XCTAssertEqual(network.movies.count, 1)
        XCTAssertFalse(network.moviesLoadFailed)
        XCTAssertEqual(network.moviesGeneration, generation + 1, "answers to earlier requests are dropped")
    }

    /// fetchMovies hands the request's failure to receivePage, which keeps it for Home's message.
    @MainActor
    func testReceivePageKeepsTheFailureReason() {
        let network = Network()
        let received = expectation(description: "failure kept")
        let subscription = network.$moviesLoadFailure.dropFirst().sink { if $0 == .offline { received.fulfill() } }
        network.receivePage(nil, failure: .offline)
        wait(for: [received], timeout: 2)
        subscription.cancel()
        XCTAssertTrue(network.moviesLoadFailed)
    }

    // MARK: sheets that trapped

    /// 1.6.0 took `movieVideo.last!`: an episode without qualities crashed the download sheet.
    func testNoQualitiesMeansNoDownloadLink() {
        XCTAssertEqual(DownloadParamsSheet.defaultVideo(in: []), "")
        XCTAssertNil(DownloadParamsSheet.downloadURL(""), "the Download button stays disabled")
        let qualities = [Quality(name: "720p", url: "https://cdn.example/720.mp4"), Quality(name: "1080p", url: "https://cdn.example/1080.mp4")]
        XCTAssertEqual(DownloadParamsSheet.defaultVideo(in: qualities), "https://cdn.example/1080.mp4")
        XCTAssertEqual(DownloadParamsSheet.downloadURL("https://cdn.example/1080.mp4")?.host, "cdn.example")
    }

    /// `voiceActing![…]` trapped on a page whose translators list has no items (re/IMPROVEMENTS.md).
    func testInitialVoiceActingSurvivesAnEmptyList() {
        XCTAssertNil(DownloadParamsSheet.initialActing(in: nil))
        XCTAssertNil(DownloadParamsSheet.initialActing(in: []))
        let first = acting("1", selected: false), chosen = acting("2", selected: true)
        XCTAssertEqual(DownloadParamsSheet.initialActing(in: [first, chosen]), chosen)
        XCTAssertEqual(DownloadParamsSheet.initialActing(in: [first]), first)
    }

    // MARK: settings defaults

    /// 1.6.0 gave some keys different defaults in different places: Player settings showed autoplay on while the quality
    /// sheet read it as off, and the player read saveHistory raw (false while unset) although Settings shows it on.
    /// The registration domain is process-wide, so the app host's launch has registered the same values already.
    func testRegisteredDefaultsAreWhatSettingsShow() {
        let defaults = UserDefaults(suiteName: "HardeningTests.defaults")!
        defaults.removePersistentDomain(forName: "HardeningTests.defaults")
        DefaultSettings.register(in: defaults)
        XCTAssertTrue(defaults.bool(forKey: "autoplayNextEpisode"))
        XCTAssertTrue(defaults.bool(forKey: "saveHistory"))
        XCTAssertEqual(defaults.object(forKey: "background_url_session") as? Bool, true,
                       "downloads keep running in the background as in 1.6.0; Behavior settings now show it on")
        XCTAssertEqual(Set(DefaultSettings.values.keys), ["autoplayNextEpisode", "background_url_session", "saveHistory"])
    }

    private func acting(_ id: String, selected: Bool) -> MovieVoiceActing {
        MovieVoiceActing(id: id, name: "Studio \(id)", translatorId: id, isCamrip: "", isAds: "", isDirector: "",
                         isSelected: selected, isPremium: false, url: nil)
    }
}
