import XCTest
@testable import HDrezka

final class VideoServiceTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private let dub = MovieVoiceActing(id: "205", name: "Дубляж", translatorId: "56", isCamrip: "0", isAds: "0", isDirector: "0",
                                       isSelected: true, isPremium: false, url: nil)

    // MARK: String.getMovieVideo()

    /// Live answer of POST /ajax/get_cdn_series/ (action=get_movie, id=205, translator_id=56) with the iOS app headers.
    func testDecodesLiveGetMovieResponse() throws {
        let video = try fixture("video-film-205.json").getMovieVideo()
        let base = "https://stream.voidboost.one/"
        let token = ":2026111107:dTBOZTRadXltMGpEb3ZTbmtpQ0c5b2VwaWpOUkFkc1N2QmVxU2Z6c054NVNZRDdpTFVUUEdkeGcwTURQK0JIcm1PN2t1eHR0ZW5QZm5hOHdZMVFEdkE9PQ=="
        XCTAssertEqual(video, MovieVideo(
            name: "",
            _360p: base + "57284fffdd282471fa65d7bb7106e774" + token + "/2/6/0/2/9/5/i3exf.mp4",
            _480p: base + "5b9cdbbf0162c2d5aa7a507653a1b8e3" + token + "/2/6/0/2/9/5/k153o.mp4",
            _720p: base + "7bf351edcdd944d72cd8b9f0a4d3d031" + token + "/2/6/0/2/9/5/jt8ns.mp4",
            _1080p: "null", // label is <span class="pjs-registered-quality">1080p<img ...></span>, link is the literal "null"
            _1080pUltra: base + "b42eaec6d683261809a6bfebee7028b2" + token + "/1/5/3/6/4/2/4/zrkms.mp4",
            _1440p: nil,
            _2160p: nil,
            subtitles: [], // "subtitle": false
            position: 0))
    }

    /// A details page: the player JSON is taken from `{"id":` up to `});`. The page is built from the keys the parser reads,
    /// not captured from the site: the archived details-*.html carry `{"url":false,...}` and no `{"id":`, so the force-unwrapped
    /// `range(of:)` crashes both builds on them. Replace it with a live page once a VPN or device run can fetch one.
    func testDecodesPlayerJsonInsidePageWithSubtitles() {
        let page = """
        <html><body><script>$(function () { sof.tv.initCDNMoviesEvents(205, 56, 0, 0, 0, 'rezka.ag', false, {"id":"cdnplayer","cdn_url":"","streams":"[360p]https://s.test/360.mp4,[720p]https://s.test/720.mp4,[2K]https://s.test/1440.mp4,[4K]https://s.test/2160.mp4","default_quality":"720p","subtitle":"[Русский]https://s.test/ru.vtt,[English]https://s.test/en.vtt,[Deutsch]https://s.test/de.vtt","subtitle_lns":{"off":"","Русский":"ru","English":"en"},"subtitle_def":"ru"}); });</script></body></html>
        """
        let video = page.getMovieVideo()
        XCTAssertEqual(video._360p, "https://s.test/360.mp4")
        XCTAssertNil(video._480p)
        XCTAssertEqual(video._720p, "https://s.test/720.mp4")
        XCTAssertEqual(video._1440p, "https://s.test/1440.mp4")
        XCTAssertEqual(video._2160p, "https://s.test/2160.mp4")
        // "Deutsch" has no entry in subtitle_lns, so it is dropped.
        XCTAssertEqual(video.subtitles, [
            MovieSubtitles(name: "Русский", link: "https://s.test/ru.vtt", lang: "ru"),
            MovieSubtitles(name: "English", link: "https://s.test/en.vtt", lang: "en"),
        ])
    }

    /// A subtitle item without "]" has no link, so it is skipped; the original trapped on `parts[1]`, even for a known name.
    func testSubtitleItemWithoutClosingBracketIsSkipped() {
        let answer = #"{"url":"[720p]https://s.test/720.mp4","subtitle":"[Русский]https://s.test/ru.vtt,[English],broken,[Deutsch]https://s.test/de.vtt","subtitle_lns":{"Русский":"ru","English":"en","broken":"xx","Deutsch":"de"}}"#
        let video = answer.getMovieVideo()
        XCTAssertEqual(video._720p, "https://s.test/720.mp4")
        XCTAssertEqual(video.subtitles, [
            MovieSubtitles(name: "Русский", link: "https://s.test/ru.vtt", lang: "ru"),
            MovieSubtitles(name: "Deutsch", link: "https://s.test/de.vtt", lang: "de"),
        ])
    }

    // MARK: Qualities

    func testAvailableQualitiesKeepBinaryOrderAndSkipMissing() {
        let video = MovieVideo(name: "", _360p: "a", _480p: nil, _720p: "c", _1080p: "d", _1080pUltra: "e", _1440p: "f", _2160p: "g",
                               subtitles: nil, position: 0)
        XCTAssertEqual(video.getAvailableQualities(), [
            Quality(name: "360p", url: "a"), Quality(name: "720p", url: "c"), Quality(name: "1080p", url: "d"),
            Quality(name: "1080p Ultra", url: "e"), Quality(name: "2K", url: "f"), Quality(name: "4K", url: "g"),
        ])
    }

    func testPreferredQualityFallsBackToHighest() {
        let qualities = [Quality(name: "360p", url: "a"), Quality(name: "720p", url: "c"), Quality(name: "1080p Ultra", url: "e")]
        XCTAssertEqual(qualities.preferred(name: "720p"), Quality(name: "720p", url: "c"))
        XCTAssertEqual(qualities.preferred(name: "4K"), Quality(name: "1080p Ultra", url: "e"))
        XCTAssertNil([Quality]().preferred(name: "720p"))
    }

    // MARK: Request builders

    func testFilmParams() {
        XCTAssertEqual(MovieDetailsService.videoParams(voiceActing: dub, season: nil, episode: nil, id: "https://hdrezka.ag/films/action/205-golodnye-igry-2012.html"),
                       ["id": "205", "translator_id": "56", "is_camrip": "0", "is_ads": "0", "is_director": "0", "action": "get_movie"])
    }

    func testEpisodeParamsUseMovieIdWhenTranslatorHasNone() {
        let lostfilm = MovieVoiceActing(id: "", name: "лостфильм (LostFilm)", translatorId: "1", isCamrip: "", isAds: "", isDirector: "",
                                        isSelected: true, isPremium: false, url: nil)
        let season = MovieSeason(id: "1", name: "Сезон 1", episodes: [], isSelected: true, url: nil)
        let episode = MovieEpisode(id: "2", name: "Серия 2", isSelected: false, url: nil)
        XCTAssertEqual(MovieDetailsService.videoParams(voiceActing: lostfilm, season: season, episode: episode,
                                                       id: "https://hdrezka.ag/series/action/1605-gavayi-50-2010.html"),
                       ["id": "1605", "translator_id": "1", "season": "1", "episode": "2", "action": "get_stream"])
        // A season without an episode is still a movie request.
        XCTAssertEqual(MovieDetailsService.videoParams(voiceActing: lostfilm, season: season, episode: nil, id: "1605")["action"], "get_movie")
        XCTAssertEqual(MovieDetailsService.seasonsParams(movieId: "https://hdrezka.ag/series/action/1605-gavayi-50-2010.html", voiceActing: lostfilm),
                       ["id": "1605", "translator_id": "1", "action": "get_episodes"])
    }

    /// getMovieVideo(voiceActing:season:episode:id:) GETs episode.url, else voiceActing.url, else POSTs the form.
    func testPageUrlPrefersEpisodeLinkOverTranslatorLink() {
        let linked = MovieVoiceActing(id: "205", name: "Дубляж", translatorId: "56", isCamrip: "0", isAds: "0", isDirector: "0",
                                      isSelected: true, isPremium: false, url: "https://ijobs.app/t.html")
        let episode = MovieEpisode(id: "2", name: "Серия 2", isSelected: false, url: "https://ijobs.app/e.html")
        let bare = MovieEpisode(id: "2", name: "Серия 2", isSelected: false, url: nil)
        XCTAssertEqual(MovieDetailsService.pageURL(voiceActing: linked, episode: episode), "https://ijobs.app/e.html")
        XCTAssertEqual(MovieDetailsService.pageURL(voiceActing: linked, episode: bare), "https://ijobs.app/t.html")
        XCTAssertEqual(MovieDetailsService.pageURL(voiceActing: linked, episode: nil), "https://ijobs.app/t.html")
        XCTAssertNil(MovieDetailsService.pageURL(voiceActing: dub, episode: bare)) // no link on either side: POST
    }

    func testCdnSeriesUrlUsesWholeSeconds() {
        XCTAssertEqual(MovieDetailsService.cdnSeriesURL(mirror: "ijobs.app", date: Date(timeIntervalSince1970: 1794299956.4)),
                       "https://ijobs.app/ajax/get_cdn_series/?t=1794299956")
    }

    // MARK: Small String helpers

    func testGetMovieId() {
        XCTAssertEqual("https://ijobs.app/films/comedy/93744-moya-luchshaya-podruga-2026.html".getMovieId(), "93744")
        XCTAssertEqual("".getMovieId(), "")
    }

    func testRemoveMirror() {
        XCTAssertEqual("https://ijobs.app/films/drama/93758-otmschenie-moe-1984.html".removeMirror(), "films/drama/93758-otmschenie-moe-1984.html")
        XCTAssertEqual("/films/drama/93758-otmschenie-moe-1984.html".removeMirror(), "/films/drama/93758-otmschenie-moe-1984.html")
    }

    /// Vote counts as printed on details pages (`<i>(1 043 261)</i>`).
    func testToShortNumber() {
        XCTAssertEqual("(503 278)".toShortNumber(), "503K")
        XCTAssertEqual("(81 514)".toShortNumber(), "81K")
        XCTAssertEqual("(9 715)".toShortNumber(), "9,7K")
        XCTAssertEqual("(999)".toShortNumber(), "999")
        XCTAssertEqual("(12 345 678)".toShortNumber(), "12M")
        XCTAssertEqual("(123 456 789)".toShortNumber(), "123456789")
        // The binary takes the first digit of `n % 1_000_000`, so 1 043 261 reads "1,4M".
        XCTAssertEqual("(1 043 261)".toShortNumber(), "1,4M")
        // Every range is closed at both ends and the larger one is checked first.
        XCTAssertEqual("(1 000)".toShortNumber(), "1,0K")
        XCTAssertEqual("(10 000)".toShortNumber(), "10K")
        XCTAssertEqual("(1 000 000)".toShortNumber(), "1,0M")
        XCTAssertEqual("(10 000 000)".toShortNumber(), "10M")
        XCTAssertEqual("(100 000 000)".toShortNumber(), "100M")
        XCTAssertEqual("(100 000 001)".toShortNumber(), "100000001")
        XCTAssertEqual("—".toShortNumber(), "0")
    }

    func testIsSuccess() throws {
        XCTAssertTrue(try fixture("video-film-205.json").isSuccess())
        XCTAssertFalse(#"{"success":false,"message":"Ошибка"}"#.isSuccess())
        XCTAssertFalse("<html></html>".isSuccess())
    }
}
