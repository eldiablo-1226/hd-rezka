import XCTest
import SwiftUI
@testable import HDrezka

/// improvement (Details redesign, «Два режима одной страницы»): the selection behind «Смотреть», the voice acting
/// signals, the half the page opens on and the text of its primary button.
@MainActor
final class DetailsRedesignTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)"), encoding: .utf8)
    }

    /// The fixtures are region-restricted pages, which skip voice actings; opened as CatalogSliceTests does.
    private func detail(_ fixtureName: String, id: String) throws -> MovieDetailed {
        let html = try fixture(fixtureName).replacingOccurrences(of: "b-player__restricted", with: "b-player__open")
        return try XCTUnwrap(MovieDetailsParser().parseMovieDetails(html: html, movieId: id).first)
    }

    private func acting(_ id: String, _ name: String, selected: Bool = false, premium: Bool = false,
                        camrip: String = "0", ads: String = "0", director: String = "0") -> MovieVoiceActing {
        MovieVoiceActing(id: "page", name: name, translatorId: id, isCamrip: camrip, isAds: ads, isDirector: director,
                         isSelected: selected, isPremium: premium, url: nil)
    }

    private func episode(_ id: String, selected: Bool = false) -> MovieEpisode {
        MovieEpisode(id: id, name: id, isSelected: selected, url: nil)
    }

    private func season(_ id: String, selected: Bool = false, _ episodes: [MovieEpisode]) -> MovieSeason {
        MovieSeason(id: id, name: id, episodes: episodes, isSelected: selected, url: nil)
    }

    // MARK: PlaybackSelection

    func testSeriesVoiceChangeLoadsItsSeasonsAndPicksTheMarkedEpisode() async {
        let studio = acting("111", "HDrezka Studio", selected: true)
        let lost = acting("1", "LostFilm")
        let page = [season("1", selected: true, [episode("1", selected: true)])]
        let lostSeasons = [season("1", [episode("1")]), season("2", selected: true, [episode("1"), episode("8", selected: true)])]
        let calls = Calls()
        let selection = PlaybackSelection()
        selection.configure(actings: [studio, lost], seasons: page,
                            initial: PlaybackChoice(acting: studio, season: page[0], episode: page[0].episodes[0])) { acting in
            calls.ids.append(acting.translatorId)
            return lostSeasons
        }
        await selection.select(lost)
        XCTAssertEqual(calls.ids, ["1"])
        XCTAssertEqual(selection.choice?.acting, lost)
        XCTAssertEqual(selection.choice?.season?.id, "2")
        XCTAssertEqual(selection.choice?.episode?.id, "8")
        XCTAssertFalse(selection.isLoadingSeasons)
    }

    func testUnmarkedSeasonsStartAtTheFirstSeasonAndEpisode() async {
        let a = acting("1", "A", selected: true), b = acting("2", "B")
        let selection = PlaybackSelection()
        selection.configure(actings: [a, b], seasons: [season("1", [episode("1")])], initial: nil) { _ in
            [self.season("3", [self.episode("5"), self.episode("6")]), self.season("4", [self.episode("7")])]
        }
        await selection.select(b)
        XCTAssertEqual(selection.season?.id, "3")
        XCTAssertEqual(selection.episode?.id, "5")
    }

    func testSeasonChangePicksItsMarkedEpisode() {
        let a = acting("1", "A", selected: true)
        let seasons = [season("1", [episode("1")]), season("2", [episode("1"), episode("4", selected: true)])]
        let selection = PlaybackSelection()
        selection.configure(actings: [a], seasons: seasons, initial: PlaybackChoice(acting: a, season: seasons[0], episode: seasons[0].episodes[0])) { _ in nil }
        selection.select(season: seasons[1])
        XCTAssertEqual(selection.choice?.season?.id, "2")
        XCTAssertEqual(selection.choice?.episode?.id, "4")
    }

    func testALaterVoiceTapWins() async {
        let a = acting("1", "A", selected: true), b = acting("2", "B"), c = acting("3", "C")
        let gate = Gate()
        let selection = PlaybackSelection()
        selection.configure(actings: [a, b, c], seasons: [season("1", selected: true, [episode("1")])], initial: nil) { acting in
            if acting.translatorId == "2" { await gate.enter() }
            return [self.season(acting.translatorId, [self.episode("e" + acting.translatorId)])]
        }
        let slow = Task { await selection.select(b) }
        let entered = await gate.waitUntilEntered()
        XCTAssertTrue(entered, "the first voice acting's seasons never started loading")
        await selection.select(c)
        await gate.open()
        await slow.value
        XCTAssertEqual(selection.acting, c)
        XCTAssertEqual(selection.season?.id, "3")
        XCTAssertEqual(selection.episode?.id, "e3")
        XCTAssertFalse(selection.isLoadingSeasons)
    }

    func testFailedSeasonsBlockWatchingUntilARetrySucceeds() async {
        let a = acting("1", "A", selected: true), b = acting("2", "B")
        let attempts = Calls()
        let selection = PlaybackSelection()
        selection.configure(actings: [a, b], seasons: [season("1", selected: true, [episode("1")])], initial: nil) { acting in
            attempts.ids.append(acting.translatorId)
            if attempts.ids.count == 1 { throw URLError(.timedOut) }
            return [self.season("9", [self.episode("1")])]
        }
        await selection.select(b)
        XCTAssertTrue(selection.seasonsFailed)
        XCTAssertNil(selection.choice)
        await selection.select(b)
        XCTAssertFalse(selection.seasonsFailed)
        XCTAssertEqual(selection.choice?.season?.id, "9")
        XCTAssertEqual(attempts.ids, ["2", "2"])
    }

    func testFilmVoiceChangeLoadsNothing() async {
        let a = acting("1", "A", selected: true), b = acting("2", "B")
        let calls = Calls()
        let selection = PlaybackSelection()
        selection.configure(actings: [a, b], seasons: nil, initial: PlaybackChoice(acting: a, season: nil, episode: nil)) { acting in
            calls.ids.append(acting.translatorId)
            return nil
        }
        await selection.select(b)
        XCTAssertEqual(calls.ids, [])
        XCTAssertEqual(selection.choice?.acting, b)
        XCTAssertNil(selection.choice?.season)
    }

    func testFourRowsKeepTheChosenVoiceVisible() {
        let list = (1...6).map { acting("\($0)", "V\($0)") }
        XCTAssertEqual(PlaybackSelection.visibleVoices(list, chosen: list[1], showsAll: false, limit: 4).map(\.translatorId),
                       ["1", "2", "3", "4"])
        XCTAssertEqual(PlaybackSelection.visibleVoices(list, chosen: list[5], showsAll: false, limit: 4).map(\.translatorId),
                       ["1", "2", "3", "6"])
        XCTAssertEqual(PlaybackSelection.visibleVoices(list, chosen: nil, showsAll: true, limit: 4).count, 6)
        XCTAssertEqual(PlaybackSelection.visibleVoices(Array(list.prefix(3)), chosen: nil, showsAll: false, limit: 4).count, 3)
    }

    // MARK: voice acting signals

    func testPopularityMatchesNamesWithoutFlagsCaseOrRepeatedSpaces() {
        let signals = VoiceActingSignals(ratings: [MovieVoiceActingRating(name: "Украинский (1+1) 🇺🇦", percent: 0.34),
                                                  MovieVoiceActingRating(name: "лостфильм (LostFilm)", percent: 98.49)])
        XCTAssertEqual(signals.percent(for: acting("389", "Украинский (1+1)  🇺🇦")), 0.34)
        XCTAssertEqual(signals.percent(for: acting("1", "Лостфильм (LostFilm)")), 98.49)
        XCTAssertNil(signals.percent(for: acting("232", "TVShows")))
    }

    func testMostWatchedFirstAndUnratedKeepThePageOrder() {
        let signals = VoiceActingSignals(ratings: [MovieVoiceActingRating(name: "B", percent: 10),
                                                  MovieVoiceActingRating(name: "C", percent: 80)])
        let list = [acting("1", "A"), acting("2", "B"), acting("3", "C"), acting("4", "D")]
        XCTAssertEqual(signals.ordered(list).map(\.translatorId), ["3", "2", "1", "4"])
        XCTAssertEqual(VoiceActingSignals(ratings: nil).ordered(list).map(\.translatorId), ["1", "2", "3", "4"])
    }

    func testRealPageGivesEveryTranslatorItsShare() throws {
        let series = try detail("details-series-hawaii.html", id: "1605")
        let actings = try XCTUnwrap(series.voiceActing)
        let signals = VoiceActingSignals(ratings: series.voiceActingRating)
        XCTAssertEqual(actings.count, 6)
        XCTAssertEqual(actings.compactMap { signals.percent(for: $0) }.count, actings.count)
        XCTAssertEqual(signals.ordered(actings).first?.translatorId, "1")
    }

    func testFlagsAreTheSitesOwn() {
        XCTAssertEqual(VoiceFlag.flags(of: acting("1", "A", camrip: "1", director: "1")), [.camrip, .directorsCut])
        XCTAssertEqual(VoiceFlag.flags(of: acting("1", "A", ads: "1")), [.ads])
        XCTAssertEqual(VoiceFlag.flags(of: acting("1", "A")), [])
    }

    // MARK: the half the page opens on

    func testPageOpensOnWatchWithProgressOrToContinueElseOnAbout() {
        XCTAssertEqual(DetailsMode.initial(canPlay: true, opensOnWatch: false, hasProgress: true), .watch)
        XCTAssertEqual(DetailsMode.initial(canPlay: true, opensOnWatch: true, hasProgress: false), .watch)
        XCTAssertEqual(DetailsMode.initial(canPlay: true, opensOnWatch: false, hasProgress: false), .about)
        XCTAssertEqual(DetailsMode.initial(canPlay: false, opensOnWatch: true, hasProgress: true), .about)
    }

    func testProgressOfATitleIsFoundByItsKeyPrefix() {
        let id = "https://example.test/films/\(UUID().uuidString).html"
        XCTAssertFalse(PlaybackProgressStore.shared.hasProgress(forTitle: id))
        PlaybackProgressStore.shared.save(time: 120, forKey: id + "|111|0|0")
        XCTAssertTrue(PlaybackProgressStore.shared.hasProgress(forTitle: id))
        XCTAssertFalse(PlaybackProgressStore.shared.hasProgress(forTitle: id + "x"))
    }

    // MARK: the facts strip

    /// One row of equal cells only while every cell fits whole, else two by two: the cells used to shrink one by one,
    /// so at xxLarge the four values came out in four sizes.
    func testFactsWrapRatherThanShrinkWhenFourDontFitWhole() throws {
        let detail = try self.detail("details-film-hunger-games.html", id: "https://example.test/films/x.html")
        func height(_ size: DynamicTypeSize, width: CGFloat) -> CGFloat {
            UIHostingController(rootView: InfoTabView(detail: detail).environment(\.dynamicTypeSize, size))
                .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        XCTAssertEqual(height(.large, width: 600), height(.large, width: 700), "one row when there is room")
        XCTAssertGreaterThan(height(.xxLarge, width: 280), height(.xxLarge, width: 700), "two rows, not four shrunk cells")
    }

    // MARK: what the primary button says

    func testBareNumbersReadAsSeasonAndEpisode() {
        let seasonTwo = String(format: NSLocalizedString("key_season_number", comment: ""), "2")
        let episodeEight = String(format: NSLocalizedString("key_episode_number", comment: ""), "8")
        XCTAssertEqual(EpisodeNames.season(season("2", [])), seasonTwo)
        XCTAssertEqual(EpisodeNames.episode(episode("8")), episodeEight)
        XCTAssertEqual(EpisodeNames.season(MovieSeason(id: "2", name: "Сезон 2", episodes: [], isSelected: false, url: nil)), "Сезон 2")
        XCTAssertEqual(EpisodeNames.episode(MovieEpisode(id: "8", name: "Серия 8", isSelected: false, url: nil)), "Серия 8")
    }

    func testResumeClock() {
        XCTAssertEqual(EpisodeNames.clock(1394), "23:14")
        XCTAssertEqual(EpisodeNames.clock(3730), "1:02:10")
        XCTAssertEqual(EpisodeNames.clock(59), "0:59")
    }

    func testButtonDetailNamesEpisodeVoiceAndResumePoint() {
        let studio = acting("111", "HDrezka Studio")
        let seasonTwo = MovieSeason(id: "2", name: "Сезон 2", episodes: [], isSelected: false, url: nil)
        let episodeEight = MovieEpisode(id: "8", name: "Серия 8", isSelected: false, url: nil)
        let choice = PlaybackChoice(acting: studio, season: seasonTwo, episode: episodeEight)
        // A wrap lands after «·», never before it («· с 0:29» alone on a line) or inside «с 23:14»: no-break spaces.
        let from = String(format: NSLocalizedString("key_resume_from", comment: ""), "23:14")
            .replacingOccurrences(of: " ", with: "\u{00A0}")
        XCTAssertEqual(choice.detailLine(resume: 1394), "Сезон 2, Серия 8\u{00A0}· HDrezka Studio\u{00A0}· \(from)")
        XCTAssertEqual(choice.detailLine(resume: nil), "Сезон 2, Серия 8\u{00A0}· HDrezka Studio")
        XCTAssertEqual(choice.detailLine(resume: 5), "Сезон 2, Серия 8\u{00A0}· HDrezka Studio",
                       "a few seconds is not a resume point")
        XCTAssertEqual(PlaybackChoice(acting: studio, season: nil, episode: nil).detailLine(resume: nil), "HDrezka Studio")
        let nameless = PlaybackChoice(acting: acting("5", ""), season: seasonTwo, episode: episodeEight)
        XCTAssertEqual(nameless.detailLine(resume: nil, voiceName: "Дубляж"), "Сезон 2, Серия 8\u{00A0}· Дубляж",
                       "a page without a translator list names its one voice acting")
        XCTAssertTrue(choice.isResume(1394))
        XCTAssertFalse(choice.isResume(5))
        XCTAssertFalse(choice.isResume(nil))
    }

    /// The player writes its last position as it closes, and nothing else on the page changes then: the button must
    /// still turn into «Продолжить … · с 0:29» by itself.
    func testTheWatchButtonPicksUpAPositionSavedWhileItIsOnScreen() throws {
        let wasOn = try setAccessibilityAutomation(true)
        defer { _ = try? setAccessibilityAutomation(wasOn) }
        let studio = acting("111", "HDrezka Studio", selected: true)
        let page = [season("1", selected: true, [episode("1", selected: true)])]
        let selection = PlaybackSelection()
        selection.configure(actings: [studio], seasons: page,
                            initial: PlaybackChoice(acting: studio, season: page[0], episode: page[0].episodes[0])) { _ in page }
        let key = "https://example.test/series/\(UUID().uuidString).html|111|1|1"
        let detail = try self.detail("details-series-hawaii.html", id: "https://example.test/series/x.html")
        let panel = DetailsWatchPanel(detail: detail, selection: selection,
                                      resumeSeconds: { _ in PlaybackProgressStore.shared.time(forKey: key) },
                                      isBookmarked: false, play: { _ in }, download: {}, bookmark: {})
        let host = UIHostingController(rootView: panel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        let from = String(format: NSLocalizedString("key_resume_from", comment: ""), "0:29")
        XCTAssertFalse(accessibilityLabels(in: host.view).isEmpty, "SwiftUI exposed no accessibility elements")
        XCTAssertFalse(accessibilityLabels(in: host.view).contains { $0.contains(from) })

        PlaybackProgressStore.shared.save(time: 29, forKey: key)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.view.layoutIfNeeded()
        XCTAssertTrue(accessibilityLabels(in: host.view).contains { $0.contains(from) },
                      "the button still names no resume point: \(accessibilityLabels(in: host.view))")
    }
}

/// A reference box, so the async loader closures can record their calls.
private final class Calls {
    var ids: [String] = []
}

/// Holds the first loader call until the test opens it, so a later call can finish first.
private actor Gate {
    private var isEntered = false
    private var isOpen = false
    private var enteredWaiter: CheckedContinuation<Bool, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func enter() async {
        isEntered = true
        enteredWaiter?.resume(returning: true)
        enteredWaiter = nil
        if !isOpen { await withCheckedContinuation { releaseWaiter = $0 } }
    }

    /// false when no loader call arrives within `seconds`, so a broken selection fails the test instead of hanging it
    /// (XCTest has no default timeout).
    func waitUntilEntered(seconds: Double = 2) async -> Bool {
        if isEntered { return true }
        return await withCheckedContinuation { continuation in
            enteredWaiter = continuation
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                await self.giveUpWaiting()
            }
        }
    }

    private func giveUpWaiting() {
        enteredWaiter?.resume(returning: false)
        enteredWaiter = nil
    }

    func open() {
        isOpen = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
