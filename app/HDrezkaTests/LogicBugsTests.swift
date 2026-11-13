import XCTest
import AVKit
import CoreData
@testable import HDrezka

/// Logic bugs found by the whole-app hunt of 2026-11-13. Each test names the symptom a user saw.
@MainActor
final class LogicBugsTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)"), encoding: .utf8)
    }

    private func acting(_ id: String, _ name: String, selected: Bool = false) -> MovieVoiceActing {
        MovieVoiceActing(id: "page", name: name, translatorId: id, isCamrip: "0", isAds: "0", isDirector: "0",
                         isSelected: selected, isPremium: false, url: nil)
    }

    private func episode(_ id: String) -> MovieEpisode {
        MovieEpisode(id: id, name: id, isSelected: false, url: nil)
    }

    private func season(_ id: String, selected: Bool = false, _ episodes: [MovieEpisode]) -> MovieSeason {
        MovieSeason(id: id, name: id, episodes: episodes, isSelected: selected, url: nil)
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    private var downloadsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Removes the rows of a test title, under its old full-address keys and its post-number keys.
    private func deleteProgress(post: Int) {
        let context = PlaybackProgressStore.shared.container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlaybackProgress")
        request.predicate = NSPredicate(format: "key CONTAINS %@", "\(post)")
        (try? context.fetch(request))?.forEach(context.delete)
        try? context.save()
    }

    // MARK: - Qualities

    /// The site sends a guest the literal link "null" for a quality that needs an account (1080p of film 205): it was
    /// offered, preselected for download and auto-played by a «1080p» preference, and nothing played.
    func testAQualityTheSiteLocksIsNotOffered() throws {
        let qualities = try fixture("video-film-205.json").getMovieVideo().getAvailableQualities()
        XCTAssertEqual(qualities.map(\.name), ["360p", "480p", "720p", "1080p Ultra"])
        XCTAssertEqual(qualities.preferred(name: "1080p")?.name, "720p")
    }

    // MARK: - Quick search

    /// «1984» lost the year: the title was cut out of the whole line, not just its start.
    func testASuggestionKeepsTheYearWhenTheTitleIsANumber() throws {
        let html = #"<div class="b-search__live_section"><ul class="b-search__section_list"><li><a href="https://ijobs.app/films/drama/1-1984.html"><span class="enty">1984</span> (Nineteen Eighty-Four, 1984)<span class="rating"><i>7.20</i></span></a></li></ul></div>"#
        let result = try XCTUnwrap(Network().parseQuickSearch(html: html).first)
        XCTAssertEqual(result.name, "1984")
        XCTAssertEqual(result.originalTitle, "Nineteen Eighty-Four")
        XCTAssertEqual(result.kindAndYear, "Фильм · 1984")
    }

    // MARK: - Facts

    /// A page without «Страна» read «Драма · 2012 · nil»: "nil" is the parser's placeholder, not a country.
    func testAMissingCountryIsNotShownAsNil() {
        let detail = MovieDetailed(id: "", nameRussian: "Фильм", nameOriginal: nil, poster: "", hPoster: "", duration: "nil",
                                   description: "", releaseDate: "21 марта 2012 года", country: "nil", ageRestriction: "16+",
                                   imdbRating: nil, kpRating: nil, genres: [MovieGenre(id: "g", name: "Драма")], lists: nil,
                                   collections: nil, schedule: nil, franchise: nil, producer: nil, actors: nil, ytTrailerLink: nil,
                                   ytTrailerPreview: nil, availability: .AVAILABLE_ON_REZKA, comingSoon: false, voiceActing: nil,
                                   singleVoiceActingName: nil, voiceActingRating: nil, seasons: nil, video: nil, bookmarks: [:],
                                   commentsCount: 0)
        XCTAssertEqual(detail.factsLine, "Драма · 2012")
    }

    // MARK: - Sign-up

    /// The site's own form sends `data` through jQuery's serialize(), and quick_register.php reads it like PHP's
    /// parse_str. Unescaped, «p&s=1+2%» arrived as «p» and «neo+hd@…» as «neo hd@…».
    func testSignUpSendsSpecialCharactersAsTyped() {
        let fields = Self.parseStr(AccountService.signUpData(email: "neo+hd@matrix.io", username: "neo", password: "p&s=1+2%"))
        XCTAssertEqual(fields["password1"], "p&s=1+2%")
        XCTAssertEqual(fields["email"], "neo+hd@matrix.io")
        XCTAssertEqual(fields["name"], "neo")
        XCTAssertEqual(fields["do"], "register")
    }

    /// PHP's parse_str: pairs split on "&", "+" is a space, %XX decoded.
    private static func parseStr(_ query: String) -> [String: String] {
        var fields: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            func decode(_ part: Substring) -> String {
                let spaced = part.replacingOccurrences(of: "+", with: " ")
                return spaced.removingPercentEncoding ?? spaced
            }
            fields[decode(parts[0])] = parts.count > 1 ? decode(parts[1]) : ""
        }
        return fields
    }

    // MARK: - «Досмотреть»

    /// Coming back to the list while its last load was still on its way showed every title twice: the parser added each
    /// answer to the one before.
    func testReadingTheWatchLaterPageTwiceListsItOnce() throws {
        let parser = AccountParser()
        let html = try fixture("catalog-account-watch-later.html")
        let first = try parser.parseWatchingLaterMovies(html: html)
        let second = try parser.parseWatchingLaterMovies(html: html)
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(second.map(\.id), first.map(\.id))
    }

    // MARK: - Playback positions

    /// A position saved on a page opened from Home («…/<post>-y.html» on one mirror) was missing on the same title opened
    /// from «Досмотреть» («…-latest.html») or after a mirror change: no «с 15:00», and playback started from 0.
    func testAPositionIsFoundFromAnyAddressOfTheTitle() {
        let post = Int.random(in: 900_000_000...999_999_999)
        let store = PlaybackProgressStore.shared
        defer { deleteProgress(post: post) }
        store.save(time: 900, forKey: "https://a.test/series/drama/\(post)-y-2025.html|111|1|3")
        let other = "https://b.test/series/drama/\(post)-y-2025-latest.html"
        XCTAssertEqual(store.time(forKey: other + "|111|1|3"), 900)
        XCTAssertTrue(store.hasProgress(forTitle: other))
        XCTAssertEqual(store.latestTime(forTitle: other, season: "1", episode: "3"), 900)
        XCTAssertNil(store.time(forKey: "https://a.test/series/drama/1\(post)-y-2025.html|111|1|3"), "another title")
    }

    /// Rows saved under a page address before this fix move to the title's post number; where two addresses of one
    /// episode meet, the newest position stays.
    func testOldAddressKeysMoveToThePostNumberKeepingTheNewest() throws {
        let post = Int.random(in: 900_000_000...999_999_999)
        let store = PlaybackProgressStore.shared
        let context = store.container.viewContext
        defer { deleteProgress(post: post) }
        func insert(_ key: String, _ time: Double, secondsAgo: Double) {
            let row = NSManagedObject(entity: store.container.managedObjectModel.entitiesByName["PlaybackProgress"]!,
                                      insertInto: context)
            row.setValue(key, forKey: "key")
            row.setValue(time, forKey: "time")
            row.setValue(Date(timeIntervalSinceNow: -secondsAgo), forKey: "updatedAt")
        }
        insert("https://a.test/series/drama/\(post)-y.html|111|1|3", 100, secondsAgo: 100)
        insert("https://b.test/series/drama/\(post)-y-latest.html|111|1|3", 200, secondsAgo: 10)
        insert("https://a.test/series/drama/\(post)-y.html|111|1|4", 300, secondsAgo: 50)
        try context.save()
        store.migrateAddressKeys()
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlaybackProgress")
        request.predicate = NSPredicate(format: "key CONTAINS %@", "\(post)")
        let rows = try context.fetch(request)
        XCTAssertEqual(Set(rows.compactMap { $0.value(forKey: "key") as? String }), ["\(post)|111|1|3", "\(post)|111|1|4"])
        XCTAssertEqual(store.time(forKey: "\(post)|111|1|3"), 200)
        XCTAssertEqual(store.time(forKey: "\(post)|111|1|4"), 300)
    }

    /// After autoplay went on from S1E1 to S1E3, the page still offered S1E1 from 0:00. The page follows the episode the
    /// player saved last, and only one saved while it was open: a play that never started leaves the page as it was.
    func testThePageFollowsTheEpisodeThePlayerEndedOn() {
        let post = Int.random(in: 900_000_000...999_999_999)
        let id = "https://a.test/series/drama/\(post)-y.html"
        let store = PlaybackProgressStore.shared
        defer { deleteProgress(post: post) }
        store.save(time: 600, forKey: id + "|111|1|2")
        let opened = Date()
        XCTAssertNil(store.latestEpisode(forTitle: id, translatorId: "111", since: opened), "nothing played since it opened")
        store.save(time: 0, forKey: id + "|111|1|1")
        store.save(time: 42, forKey: id + "|111|1|3")
        let last = store.latestEpisode(forTitle: id, translatorId: "111", since: opened)
        XCTAssertEqual(last?.season, "1")
        XCTAssertEqual(last?.episode, "3")
        XCTAssertNil(store.latestEpisode(forTitle: id, translatorId: "222", since: opened), "another voice acting")
    }

    /// A film closed at its end stored about its whole length. The page and «Досмотреть» then offered «с 1:39:55», and
    /// the player, which never resumes in the last 10 s, started from 0:00.
    func testClosingThePlayerAtTheEndLeavesNoResumePoint() {
        XCTAssertEqual(closePlayer(at: 5995, of: 6000), 0)
        XCTAssertFalse(PlaybackChoice(acting: acting("1", "A"), season: nil, episode: nil).isResume(0))
    }

    func testClosingThePlayerMidwayKeepsThePosition() {
        XCTAssertEqual(closePlayer(at: 3000, of: 6000), 3000)
    }

    /// Plays `item` at `seconds`, closes the player and returns what it saved.
    private func closePlayer(at seconds: Double, of duration: Double) -> Double? {
        let key = "test|\(UUID().uuidString)"
        defer {
            let context = PlaybackProgressStore.shared.container.viewContext
            let request = NSFetchRequest<NSManagedObject>(entityName: "PlaybackProgress")
            request.predicate = NSPredicate(format: "key == %@", key)
            (try? context.fetch(request))?.forEach(context.delete)
            try? context.save()
        }
        let item = TimedItem(duration: duration)
        let player = TimedPlayer(item: item, at: seconds)
        let coordinator = PlayerViewComponent.Coordinator(progressKey: key, name: "Movie", subtitle: "", poster: "", autoplay: nil)
        coordinator.attach(player: player, controller: AVPlayerViewController())
        item.becomeReady()
        drainMainQueue()
        coordinator.persistAndDetach()
        return PlaybackProgressStore.shared.time(forKey: key)
    }

    // MARK: - Downloads

    /// A download cut off by the network (-1005) lost what it had: Resume started again from byte 0.
    func testAFailedDownloadKeepsWhatItDownloaded() {
        let id = UUID()
        let resume = downloadsDirectory.appendingPathComponent(id.uuidString + ".resume")
        defer { try? FileManager.default.removeItem(at: resume) }
        let task = URLSession.shared.downloadTask(with: URL(string: "https://example.invalid/movie.mp4")!)
        task.taskDescription = id.uuidString
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost,
                            userInfo: [NSURLSessionDownloadTaskResumeData: Data([1, 2, 3])])
        let delivered = expectation(description: "delegate returned")
        DispatchQueue.global().async {
            DownloadManager.shared.urlSession(URLSession.shared, task: task, didCompleteWithError: error)
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 5)
        drainMainQueue()
        XCTAssertEqual(try? Data(contentsOf: resume), Data([1, 2, 3]))
    }

    /// An expired link answers 403 with a page; URLSession hands that page over as a finished download, and it was saved
    /// as the film, marked downloaded.
    func testAnErrorPageIsNotSavedAsTheDownload() throws {
        let manager = DownloadManager.shared
        let id = UUID()
        let download = Download(id: id, title: "Movie", subtitle: "S1E2", poster: "", quality: "720p",
                                sourceURL: "https://x/y.mp4", fileName: id.uuidString + ".mp4", state: .downloading,
                                createdAt: Date(), destination: .app, receivedBytes: 0, totalBytes: 0)
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("<html>403 Forbidden</html>".utf8).write(to: location)
        let saved = downloadsDirectory.appendingPathComponent(download.fileName)
        defer {
            try? FileManager.default.removeItem(at: location)
            manager.delete(download)
            drainMainQueue()
        }
        manager.downloads.insert(download, at: 0)
        let task = AnsweredTask(id: id, status: 403)
        let finished = expectation(description: "delegate returned")
        DispatchQueue.global().async {
            manager.urlSession(URLSession.shared, downloadTask: task, didFinishDownloadingTo: location)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        drainMainQueue()
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
        XCTAssertEqual(manager.downloads.first { $0.id == id }?.state, .failed)
    }

    /// `UIApplication.shared.delegate` is SwiftUI's own delegate, not AppDelegate (checked in this host on 2026-11-13), so
    /// the handler AppDelegate kept for background downloads was never found and never called.
    func testBackgroundDownloadsTellTheSystemTheyAreDone() {
        let called = expectation(description: "completion handler called")
        AppDelegate().application(UIApplication.shared, handleEventsForBackgroundURLSession: "test") { called.fulfill() }
        DownloadManager.shared.urlSessionDidFinishEvents(forBackgroundURLSession: URLSession.shared)
        wait(for: [called], timeout: 5)
    }

    // MARK: - Sign-out

    /// Offline, or on another mirror, «Выйти» cleared only the flag: the session cookie stayed, and every request was
    /// still signed in.
    func testSigningOutForgetsTheSessionWhenTheSiteIsUnreachable() async throws {
        let storage = HTTPCookieStorage.shared
        let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "mirror.test", .path: "/", .name: "dle_user_id", .value: "1",
                                                           .expires: Date().addingTimeInterval(3600)]))
        storage.setCookie(cookie)
        defer { storage.deleteCookie(cookie) }
        try? await AccountService().logout(network: OfflineAccountNetwork())
        XCTAssertEqual(storage.cookies(for: URL(string: "https://mirror.test/")!)?.count ?? 0, 0)
    }

    // MARK: - The page's choice

    /// Signing in from the bookmark sheet reloaded the page with the account's marks, but «Смотреть» kept the guest's.
    func testAResetLetsThePageTakeTheAccountsChoice() {
        let guest = acting("1", "LostFilm", selected: true)
        let studio = acting("111", "HDrezka Studio", selected: true)
        let selection = PlaybackSelection()
        selection.configure(actings: [guest], seasons: nil, initial: PlaybackChoice(acting: guest, season: nil, episode: nil)) { _ in nil }
        selection.reset()
        selection.configure(actings: [guest, studio], seasons: nil,
                            initial: PlaybackChoice(acting: studio, season: nil, episode: nil)) { _ in nil }
        XCTAssertEqual(selection.choice?.acting, studio)
    }

    /// The site marks a season tab that has no episodes yet: the page had no voice acting, and no season could play.
    func testAMarkedSeasonWithoutEpisodesStillLetsAnotherSeasonPlay() {
        let only = acting("111", "HDrezka Studio", selected: true)
        let seasons = [season("1", selected: true, []), season("2", [episode("1")])]
        let selection = PlaybackSelection()
        selection.configure(actings: [only], seasons: seasons,
                            initial: PlaybackChoice.default(voiceActing: [only], seasons: seasons)) { _ in nil }
        selection.select(season: seasons[1])
        XCTAssertEqual(selection.choice?.acting, only)
        XCTAssertEqual(selection.choice?.episode?.id, "1")
    }

    /// Picking the season on screen again from its menu jumped back to its first episode.
    func testPickingTheSameSeasonAgainKeepsTheEpisode() {
        let only = acting("111", "HDrezka Studio", selected: true)
        let second = season("2", selected: true, [episode("1"), episode("7")])
        let selection = PlaybackSelection()
        selection.configure(actings: [only], seasons: [second],
                            initial: PlaybackChoice(acting: only, season: second, episode: second.episodes[0])) { _ in nil }
        selection.select(episode: second.episodes[1])
        selection.select(season: second)
        XCTAssertEqual(selection.episode?.id, "7")
    }

    // MARK: - Lists

    /// A «Входит в списки» list asked for page 1 twice (its loading view appeared twice) and showed every title twice.
    func testAListShowsATitleOnceWhenAPageArrivesTwice() {
        func movie(_ id: String) -> MovieSimple { MovieSimple(id: id, name: id, details: "", poster: "") }
        XCTAssertEqual(MovieListView.merged([movie("a"), movie("b")], [movie("b"), movie("c")]).map(\.id), ["a", "b", "c"])
    }
}

/// Answers the player's links can't be read from. They trapped the app; now they give no qualities, which the sheets
/// show as an error with Retry.
final class UnreadableAnswersTests: XCTestCase {
    /// get_cdn_series refuses with `success: false` (no `url`).
    func testARefusalGivesNoQualities() {
        XCTAssertEqual(#"{"success":false,"message":"Время сессии истекло"}"#.getMovieVideo().getAvailableQualities(), [])
    }

    func testAnAnswerWithoutLinksGivesNoQualities() {
        XCTAssertEqual(#"{"success":true,"url":false}"#.getMovieVideo().getAvailableQualities(), [])
    }

    /// A voice acting or episode with its own address GETs a page; the archived pages carry `{"url":false` and no
    /// `{"id":`, and a 403 or block page carries neither.
    func testAPageWithoutThePlayerGivesNoQualities() throws {
        let page = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/details-film-hunger-games.html"), encoding: .utf8)
        XCTAssertEqual(page.getMovieVideo().getAvailableQualities(), [])
        XCTAssertEqual("<html><body><h1>403 Forbidden</h1></body></html>".getMovieVideo().getAvailableQualities(), [])
    }

    func testAStreamItemWithoutItsLinkIsSkipped() {
        XCTAssertEqual(#"{"url":"[720p]https://s.test/720.mp4,[1080p]"}"#.getMovieVideo().getAvailableQualities(),
                       [Quality(name: "720p", url: "https://s.test/720.mp4")])
    }

    /// The version feed is the Android app's; a number or null in it trapped the app on every return to the foreground.
    func testTheVersionFeedMayCarryOtherValues() throws {
        XCTAssertEqual(try HeaderUpdater.version(fromUpdates: #"{"code":45,"version":"2.2.5","newFeatures":null}"#), "2.2.5")
        XCTAssertThrowsError(try HeaderUpdater.version(fromUpdates: #"{"code":"45"}"#))
        XCTAssertThrowsError(try HeaderUpdater.version(fromUpdates: #"["2.2.5"]"#))
    }
}

/// An item with a duration and a status only the test changes.
private final class TimedItem: AVPlayerItem {
    private let fixedDuration: CMTime
    nonisolated(unsafe) private var reportedStatus: AVPlayerItem.Status = .unknown

    init(duration: Double) {
        fixedDuration = CMTime(seconds: duration, preferredTimescale: 600)
        super.init(asset: AVURLAsset(url: FileManager.default.temporaryDirectory.appendingPathComponent("missing.mp4")),
                   automaticallyLoadedAssetKeys: nil)
    }

    override var duration: CMTime { fixedDuration }
    override var status: AVPlayerItem.Status { reportedStatus }

    func becomeReady() {
        willChangeValue(forKey: "status")
        reportedStatus = .readyToPlay
        didChangeValue(forKey: "status")
    }
}

/// Shows `item` at a fixed time without handing it to AVFoundation.
private final class TimedPlayer: AVPlayer {
    private let item: AVPlayerItem
    private let time: Double

    init(item: AVPlayerItem, at time: Double) {
        self.item = item
        self.time = time
        super.init()
    }

    override var currentItem: AVPlayerItem? { item }
    override func currentTime() -> CMTime { CMTime(seconds: time, preferredTimescale: 600) }
}

/// A finished download task with the server's answer.
private final class AnsweredTask: URLSessionDownloadTask {
    private let id: UUID
    private let answer: URLResponse?

    init(id: UUID, status: Int) {
        self.id = id
        answer = HTTPURLResponse(url: URL(string: "https://x/y.mp4")!, statusCode: status, httpVersion: nil, headerFields: nil)
        super.init()
    }

    override var response: URLResponse? { answer }
    override var taskDescription: String? {
        get { id.uuidString }
        set {}
    }
}

private final class OfflineAccountNetwork: AccountNetwork {
    override var settingStore: String { get { "mirror.test" } set {} }
    override func send(_ request: URLRequest) async throws -> String { throw URLError(.notConnectedToInternet) }
}

/// The listing grids (Home, «Каталог») ask Network for the page after the last one in the list.
@MainActor
final class ListingPagingTests: XCTestCase {
    private func listing() throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/catalog-listing.html"), encoding: .utf8)
    }

    /// Pages 1–3 on screen and a pull to refresh that failed: the list stays, so the next page is 4. The grid's own
    /// counter had been set back by the refresh: it asked for page 2, added nothing, and the list stalled.
    func testAFailedRefreshGoesOnAfterTheLastPageShown() throws {
        let network = Network()
        for page in 1...3 { network.finishMoviesRequest(html: try listing(), page: page) }
        network.beginRefresh()
        network.finishMoviesRequest(html: nil, page: 1)
        XCTAssertEqual(network.nextPage, 4)
    }

    /// Page 3 timed out: it is asked for again. The grid had counted it and asked for page 4 next, so page 3's titles
    /// never showed.
    func testAFailedPageIsAskedForAgain() throws {
        let network = Network()
        for page in 1...2 { network.finishMoviesRequest(html: try listing(), page: page) }
        network.finishMoviesRequest(html: nil, page: 3)
        XCTAssertEqual(network.nextPage, 3)
    }

    /// Page 3 answered 502 with an HTML body (or a block page with 200): no titles, so it is asked for again too.
    func testAnErrorPageWithABodyIsAskedForAgain() throws {
        let network = Network()
        for page in 1...2 { network.finishMoviesRequest(html: try listing(), page: page) }
        network.finishMoviesRequest(html: "<html><body><h1>502 Bad Gateway</h1></body></html>", page: 3)
        XCTAssertEqual(network.nextPage, 3)
    }

    func testARefreshThatArrivedGoesOnFromPageTwo() throws {
        let network = Network()
        for page in 1...3 { network.finishMoviesRequest(html: try listing(), page: page) }
        network.beginRefresh()
        network.finishMoviesRequest(html: try listing(), page: 1)
        XCTAssertEqual(network.nextPage, 2)
    }

    /// Another listing empties the list first; its failed first page and the Retry start again from page 1.
    func testAnotherListingStartsOverEvenAfterAFailure() throws {
        let network = Network()
        for page in 1...3 { network.finishMoviesRequest(html: try listing(), page: page) }
        network.movies.removeAll()
        network.beginRefresh()
        network.finishMoviesRequest(html: nil, page: 1)
        XCTAssertEqual(network.nextPage, 1)
        network.finishMoviesRequest(html: try listing(), page: 1)
        XCTAssertEqual(network.nextPage, 2)
    }
}
