import XCTest
@testable import HDrezka

/// Non-UI logic of the playback / download sheets (area d2b).
final class ViewsD2BTests: XCTestCase {
    private func acting(_ name: String, translatorId: String = "56", premium: Bool = false, selected: Bool = false) -> MovieVoiceActing {
        MovieVoiceActing(id: "https://hdrezka.ag/films/fiction/205-golodnye-igry-2012.html", name: name, translatorId: translatorId,
                         isCamrip: "0", isAds: "0", isDirector: "0", isSelected: selected, isPremium: premium, url: nil)
    }

    private let season = MovieSeason(id: "2", name: "Сезон 2", episodes: [], isSelected: true, url: nil)
    private let episode = MovieEpisode(id: "7", name: "Серия 7", isSelected: true, url: nil)

    // MARK: - QualitySelectionSheet

    func testProgressKeyForSeriesAndFilm() {
        let id = "https://hdrezka.ag/series/1605-gavayi-5-0.html"
        XCTAssertEqual(QualitySelectionSheet.progressKey(id: id, acting: acting("X", translatorId: "111"), season: season, episode: episode),
                       id + "|111|2|7")
        XCTAssertEqual(QualitySelectionSheet.progressKey(id: id, acting: acting("X", translatorId: "111"), season: nil, episode: nil),
                       id + "|111|0|0")
    }

    func testInfuseURL() {
        let prefix = "infuse://x-callback-url/play?x-success=some-app://x-callback-url/playbackDidFinish&x-error=some-app://x-callback-url/playbackDidFail&url="
        let video = "https://stream.example/a/720.mp4"
        XCTAssertEqual(QualitySelectionSheet.infuseURL(video: video, subtitle: MovieSubtitles(name: "", link: "x", lang: "")),
                       prefix + video)
        XCTAssertEqual(QualitySelectionSheet.infuseURL(video: video, subtitle: MovieSubtitles(name: "Русский", link: "https://s.example/ru.vtt", lang: "ru")),
                       prefix + video + "&sub=https://s.example/ru.vtt")
    }

    func testCoverActingName() {
        XCTAssertEqual(QualitySelectionSheet.coverActingName(acting: acting("Дубляж"), episode: episode), "Дубляж, Серия 7")
        XCTAssertEqual(QualitySelectionSheet.coverActingName(acting: acting(""), episode: episode), "Серия 7")
        XCTAssertEqual(QualitySelectionSheet.coverActingName(acting: acting("Дубляж"), episode: nil), "Дубляж")
        XCTAssertEqual(QualitySelectionSheet.coverActingName(acting: acting(""), episode: nil), "")
    }

    // MARK: - DownloadParamsSheet

    func testDownloadSubtitle() {
        XCTAssertEqual(DownloadParamsSheet.downloadSubtitle(seasons: [season], season: season, episode: episode, acting: acting("Дубляж")),
                       "S2 E7 [Дубляж]")
        // A film (no seasons) only names the voice acting.
        XCTAssertEqual(DownloadParamsSheet.downloadSubtitle(seasons: nil, season: season, episode: episode, acting: acting("Дубляж")),
                       "Дубляж")
        // Only non-digits at both ends are trimmed.
        let odd = MovieSeason(id: "1", name: "1 сезон", episodes: [], isSelected: false, url: nil)
        XCTAssertEqual(DownloadParamsSheet.downloadSubtitle(seasons: [odd], season: odd, episode: MovieEpisode(id: "1", name: "Серия 10a", isSelected: false, url: nil), acting: acting("")),
                       "S1 E10 []")
    }

    func testQualityNameOfSelectedLink() {
        let qualities = [Quality(name: "480p", url: "https://s/480.mp4"), Quality(name: "720p", url: "https://s/720.mp4")]
        XCTAssertEqual(DownloadParamsSheet.qualityName(of: "https://s/720.mp4", in: qualities), "720p")
        XCTAssertEqual(DownloadParamsSheet.qualityName(of: "https://s/1080.mp4", in: qualities), "")
        XCTAssertEqual(DownloadParamsSheet.qualityName(of: "", in: []), "")
    }

    func testDownloadByteProgress() {
        let sheet = DownloadParamsSheet(id: "", name: "", poster: "", voiceActing: nil)
        func download(_ received: Int64, _ total: Int64) -> Download {
            Download(id: UUID(), title: "t", subtitle: "", poster: "", quality: "720p", sourceURL: "https://s/a.mp4",
                     fileName: "a.mp4", state: .downloading, createdAt: Date(), destination: .app,
                     receivedBytes: received, totalBytes: total)
        }
        let received = ByteCountFormatter.string(fromByteCount: 1_500_000, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: 3_000_000, countStyle: .file)
        XCTAssertEqual(sheet.downloadByteProgress(download(1_500_000, 3_000_000)), received + " / " + total)
        // No known size: only the received bytes.
        XCTAssertEqual(sheet.downloadByteProgress(download(1_500_000, 0)), received)
    }
}
