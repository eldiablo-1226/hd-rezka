import XCTest
import AVFoundation
import AVKit
import CoreData
@testable import HDrezka

final class PlayerDownloadsTests: XCTestCase {
    private let subtitles = [
        MovieSubtitles(name: "Русский", link: "https://cdn.example/sub_ru.vtt", lang: "ru"),
        MovieSubtitles(name: "Українська", link: "https://cdn.example/sub_ua.vtt", lang: "ua"),
    ]
    private let manifest = URL(string: "https://s.example/a/b/720.mp4:hls:manifest.m3u8?t=1")!

    // MARK: - HLS playlists

    func testMainPlaylistWithSubtitles() {
        let loader = CustomAVAssetResourceLoaderDelegate(m3u8: manifest, subtitles: subtitles)
        XCTAssertEqual(loader.getMainm3u8(), """
        #EXTM3U
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Русский",DEFAULT=NO,AUTOSELECT=NO,FORCED=NO,URI="subtitlesm3u8://ru",LANGUAGE="ru"
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Українська",DEFAULT=NO,AUTOSELECT=NO,FORCED=NO,URI="subtitlesm3u8://ua",LANGUAGE="uk"
        #EXT-X-STREAM-INF:BANDWIDTH=1280000,SUBTITLES="subs",CLOSED-CAPTIONS=NONE
        fragmentsm3u8://foo
        """)
    }

    func testMainPlaylistWithoutSubtitles() {
        let loader = CustomAVAssetResourceLoaderDelegate(m3u8: manifest, subtitles: [])
        XCTAssertEqual(loader.getMainm3u8(), "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1280000,CLOSED-CAPTIONS=NONE\nfragmentsm3u8://foo")
    }

    func testSubtitlePlaylist() {
        let loader = CustomAVAssetResourceLoaderDelegate(m3u8: manifest, subtitles: subtitles)
        XCTAssertEqual(loader.getSubtitlem3u8WithDuration(125.5, subtitle: subtitles[0]), """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-ALLOW-CACHE:NO
        #EXT-X-TARGETDURATION:125
        #EXTINF:125.500, no desc
        https://cdn.example/sub_ru.vtt
        #EXT-X-ENDLIST
        """)
    }

    func testProcessPlaylistSumsExtinfAndMakesSegmentsAbsolute() {
        let loader = CustomAVAssetResourceLoaderDelegate(m3u8: manifest, subtitles: [])
        let source = "#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXTINF:10.000,\nseg-1.ts\n#EXTINF:4.5,\nseg-2.ts\n#EXTINF:3.0,title\nseg-3.ts\n#EXT-X-ENDLIST"
        loader.processPlaylistWithData(Data(source.utf8))
        // "3.0,title" minus its last char is not a number, so the original counts it as 0.
        XCTAssertEqual(loader.playlistDuration, 14.5, accuracy: 0.0001)
        XCTAssertEqual(loader.m3u8String, "#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXTINF:10.000,\nhttps://s.example/a/b/seg-1.ts\n#EXTINF:4.5,\nhttps://s.example/a/b/seg-2.ts\n#EXTINF:3.0,title\nhttps://s.example/a/b/seg-3.ts\n#EXT-X-ENDLIST")
    }

    func testProcessPlaylistOnRealManifest() throws {
        // Real answer (after its 302) to the 360p link of video-film-205.json + ":hls:manifest.m3u8", fetched 2026-11-10.
        let source = try String(contentsOf: fixtureURL("hls-film-205-360p.m3u8"), encoding: .utf8)
        let folder = "https://stream.voidboost.one/57284fffdd282471fa65d7bb7106e774:2026111107:dTBOZTRadXltMGpEb3ZTbmtpQ0c5b2VwaWpOUkFkc1N2QmVxU2Z6c054NVNZRDdpTFVUUEdkeGcwTURQK0JIcm1PN2t1eHR0ZW5QZm5hOHdZMVFEdkE9PQ==/2/6/0/2/9/5/"
        let loader = CustomAVAssetResourceLoaderDelegate(m3u8: URL(string: folder + "i3exf.mp4:hls:manifest.m3u8")!, subtitles: subtitles)
        loader.processPlaylistWithData(Data(source.utf8))
        XCTAssertEqual(source.components(separatedBy: "#EXTINF:").count - 1, 1426)
        XCTAssertEqual(loader.playlistDuration, 1425 * 6 + 3.419, accuracy: 0.0005)
        // Every segment line ("./i3exf.mp4:hls:seg-N-v1-a1.ts") gets the manifest folder; tags and the trailing "" stay.
        let expected = source.components(separatedBy: "\n")
            .map { $0.isEmpty || $0.hasPrefix("#") ? $0 : folder + $0 }
            .joined(separator: "\n")
        XCTAssertEqual(loader.m3u8String, expected)
        XCTAssertTrue(loader.getSubtitlem3u8WithDuration(loader.playlistDuration, subtitle: subtitles[0])
            .contains("#EXT-X-TARGETDURATION:8553\n#EXTINF:8553.419, no desc\n"))
    }

    func testProcessPlaylistEdgeCases() {
        let loader = CustomAVAssetResourceLoaderDelegate(m3u8: manifest, subtitles: [])
        // The original prefixes absolute segment URLs too.
        loader.processPlaylistWithData(Data("#EXTM3U\n#EXTINF:4.0,\nhttps://cdn.example/seg-1.ts".utf8))
        XCTAssertEqual(loader.m3u8String, "#EXTM3U\n#EXTINF:4.0,\nhttps://s.example/a/b/https://cdn.example/seg-1.ts")
        XCTAssertEqual(loader.playlistDuration, 4)
        // An #EXTINF on the last line is kept and ends the loop before its duration is added (the sum restarts at 0).
        loader.processPlaylistWithData(Data("#EXTM3U\n#EXTINF:5.0,".utf8))
        XCTAssertEqual(loader.m3u8String, "#EXTM3U\n#EXTINF:5.0,")
        XCTAssertEqual(loader.playlistDuration, 0)
    }

    func testReplaceURLWithSchemeAndPlayerAsset() throws {
        let player = try XCTUnwrap(CustomAVPlayer(m3u8: manifest, subtitles: subtitles))
        XCTAssertEqual(player.replaceURLWithScheme("mainm3u8", url: manifest)?.absoluteString,
                       "mainm3u8://s.example/a/b/720.mp4:hls:manifest.m3u8?t=1")
        XCTAssertNil(player.replaceURLWithScheme("mainm3u8", url: URL(string: "relative")!))
        XCTAssertEqual((player.currentItem?.asset as? AVURLAsset)?.url.scheme, "mainm3u8")
    }

    // MARK: - Player decisions

    func testFollowingEpisode() {
        let episodes = (1...3).map { MovieEpisode(id: "\($0)", name: "Серия \($0)", isSelected: false, url: nil) }
        let season = MovieSeason(id: "1", name: "Сезон 1", episodes: episodes, isSelected: true, url: nil)
        let voiceActing = MovieVoiceActing(id: "56", name: "Дубляж", translatorId: "56", isCamrip: "0", isAds: "0",
                                           isDirector: "0", isSelected: true, isPremium: false, url: nil)
        func context(_ current: MovieEpisode) -> AutoplayContext {
            AutoplayContext(movieId: "46000", voiceActing: voiceActing, season: season, currentEpisode: current, qualityName: "720p")
        }
        XCTAssertEqual(context(episodes[0]).followingEpisode, episodes[1])
        XCTAssertNil(context(episodes[2]).followingEpisode)
        XCTAssertNil(context(MovieEpisode(id: "9", name: "Серия 9", isSelected: false, url: nil)).followingEpisode)
    }

    func testRestorePosition() {
        XCTAssertNil(PlayerViewComponent.restorePosition(saved: nil, duration: 100))
        XCTAssertNil(PlayerViewComponent.restorePosition(saved: 5, duration: 100))
        XCTAssertEqual(PlayerViewComponent.restorePosition(saved: 5.5, duration: 100), 5.5)
        XCTAssertNil(PlayerViewComponent.restorePosition(saved: 90, duration: 100))
        XCTAssertEqual(PlayerViewComponent.restorePosition(saved: 89.5, duration: 100), 89.5)
        XCTAssertEqual(PlayerViewComponent.restorePosition(saved: 90, duration: CMTime.indefinite.seconds), 90)
        XCTAssertEqual(PlayerViewComponent.restorePosition(saved: 90, duration: .infinity), 90)
    }

    func testProgressKeyFormat() {
        XCTAssertEqual(PlayerViewComponent.progressKey(movieId: "46000", translatorId: "56", seasonId: "2", episodeId: "7"), "46000|56|2|7")
    }

    /// An item whose status only the test changes, reported through KVO on the calling thread as AVFoundation may do.
    private final class StatusItem: AVPlayerItem {
        nonisolated(unsafe) private var reportedStatus: AVPlayerItem.Status = .unknown
        override var status: AVPlayerItem.Status { reportedStatus }

        nonisolated func becomeReady() {
            willChangeValue(forKey: "status")
            reportedStatus = .readyToPlay
            didChangeValue(forKey: "status")
        }
    }

    /// Shows `item` without handing it to AVFoundation and records where each seek runs.
    private final class SeekSpyPlayer: AVPlayer {
        private let item: AVPlayerItem
        var seeks: [(seconds: Double, onMain: Bool)] = []

        init(item: AVPlayerItem) {
            self.item = item
            super.init()
        }

        override var currentItem: AVPlayerItem? { item }

        override func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) {
            seeks.append((time.seconds, Thread.isMainThread))
        }
    }

    /// F9: the restore reads viewContext and sets didRestore, so it must run on main even when the status arrives elsewhere.
    @MainActor
    func testProgressRestoreRunsOnMainWhenStatusArrivesOffMain() {
        let key = "test|\(UUID().uuidString)"
        PlaybackProgressStore.shared.save(time: 42, forKey: key)
        defer { deleteTestProgress() }
        let item = StatusItem(url: FileManager.default.temporaryDirectory.appendingPathComponent("missing.mp4"))
        let player = SeekSpyPlayer(item: item)
        let coordinator = PlayerViewComponent.Coordinator(progressKey: key, name: "Movie", subtitle: "", poster: "", autoplay: nil)
        coordinator.attach(player: player, controller: AVPlayerViewController())
        defer { coordinator.persistAndDetach() }

        let reported = expectation(description: "status reported off main")
        DispatchQueue.global().async {
            item.becomeReady()
            reported.fulfill()
        }
        wait(for: [reported], timeout: 5)
        drainMainQueue()
        XCTAssertEqual(player.seeks.map(\.seconds), [42])
        XCTAssertEqual(player.seeks.map(\.onMain), [true])
    }

    // MARK: - Download

    func testDownloadDestinationIdIsRawValue() {
        XCTAssertEqual(DownloadDestination.allCases.map(\.id), ["app", "gallery", "files"])
    }

    func testLocalURLOnlyForCompletedAppDownloadOnDisk() throws {
        let manager = DownloadManager.shared
        let completed = makeDownload(state: .completed, destination: .app)
        let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(completed.fileName)
        XCTAssertNil(manager.localURL(for: completed))
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(manager.localURL(for: completed), file)
        var paused = completed
        paused.state = .paused
        XCTAssertNil(manager.localURL(for: paused))
        var files = completed
        files.destination = .files
        XCTAssertNil(manager.localURL(for: files))
    }

    func testForceQuitResumeData() {
        let data = Data([1, 2, 3])
        func cancelled(_ userInfo: [String: Any]) -> NSError {
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: userInfo)
        }
        XCTAssertEqual(DownloadManager.forceQuitResumeData(cancelled([NSURLSessionDownloadTaskResumeData: data,
            NSURLErrorBackgroundTaskCancelledReasonKey: NSURLErrorCancelledReasonUserForceQuitApplication])), data)
        XCTAssertNil(DownloadManager.forceQuitResumeData(cancelled([NSURLSessionDownloadTaskResumeData: data,
            NSURLErrorBackgroundTaskCancelledReasonKey: NSURLErrorCancelledReasonBackgroundUpdatesDisabled])))
        // pause()/delete() cancel without a reason key.
        XCTAssertNil(DownloadManager.forceQuitResumeData(cancelled([NSURLSessionDownloadTaskResumeData: data])))
        XCTAssertNil(DownloadManager.forceQuitResumeData(cancelled([NSURLSessionDownloadTaskResumeData: Data(),
            NSURLErrorBackgroundTaskCancelledReasonKey: NSURLErrorCancelledReasonUserForceQuitApplication])))
    }

    // MARK: - Delegate callbacks on the session queue (F8)

    /// Progress, then a failure, arrive on the session queue while main is busy. Once main catches up the 2 s throttle
    /// entry must be gone; the original cleared it off main, before the pending progress block set it again.
    func testFailureClearsProgressThrottleAfterPendingProgress() {
        let manager = DownloadManager.shared
        let id = UUID()
        let task = idleTask(for: id)
        let delivered = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            manager.urlSession(URLSession.shared, downloadTask: task, didWriteData: 1, totalBytesWritten: 1, totalBytesExpectedToWrite: 10)
            manager.urlSession(URLSession.shared, task: task, didCompleteWithError: URLError(.networkConnectionLost))
            delivered.signal()
        }
        delivered.wait()
        drainMainQueue()
        XCTAssertNil(manager.lastProgressPersist[id])
    }

    /// download() inserts its entry with main.async; a task can finish before that block runs. The finished file must
    /// still be kept: the original read `downloads` on the session queue, missed the entry and dropped the file.
    func testFinishedFileIsKeptWhileItsEntryIsStillPendingOnMain() throws {
        let manager = DownloadManager.shared
        let download = makeDownload(state: .downloading, destination: .app)
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("video".utf8).write(to: location)
        let saved = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(download.fileName)
        defer {
            try? FileManager.default.removeItem(at: location)
            manager.delete(download)
            drainMainQueue()
        }
        let task = idleTask(for: download.id)
        DispatchQueue.main.async { manager.downloads.insert(download, at: 0) }
        let finished = expectation(description: "delegate returned")
        DispatchQueue.global().async {
            manager.urlSession(URLSession.shared, downloadTask: task, didFinishDownloadingTo: location)
            finished.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.3) // main is busy while the session queue handles the finished task
        wait(for: [finished], timeout: 5)
        drainMainQueue()
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path))
        XCTAssertEqual(manager.downloads.first { $0.id == download.id }?.state, .completed)
    }

    // MARK: - downloads.json (F10)

    func testMetadataKeepsDecodableEntriesAndBacksUpTheRawFile() throws {
        let good = makeDownload(destination: .files)
        let raw = "[" + String(decoding: try JSONEncoder().encode(good), as: UTF8.self) + "," + storedJSON + #",{"id":"broken"}]"#
        let url = try metadataFile(raw)
        let loaded = DownloadManager.loadMetadata(from: url)
        XCTAssertEqual(loaded.downloads.map(\.id.uuidString), [good.id.uuidString, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"])
        XCTAssertFalse(loaded.intact, "launch must not overwrite a file that lost entries")
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("bak"), encoding: .utf8), raw)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), raw)
    }

    func testUndecodableMetadataIsBackedUpAndNotIntact() throws {
        let url = try metadataFile("{not json")
        let loaded = DownloadManager.loadMetadata(from: url)
        XCTAssertEqual(loaded.downloads, [])
        XCTAssertFalse(loaded.intact)
        XCTAssertEqual(try String(contentsOf: url.appendingPathExtension("bak"), encoding: .utf8), "{not json")
    }

    func testIntactOrMissingMetadataNeedsNoBackup() throws {
        let downloads = [makeDownload(), makeDownload(destination: .gallery)]
        let url = try metadataFile(String(decoding: try JSONEncoder().encode(downloads), as: UTF8.self))
        let loaded = DownloadManager.loadMetadata(from: url)
        XCTAssertEqual(loaded.downloads, downloads)
        XCTAssertTrue(loaded.intact)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.appendingPathExtension("bak").path))
        // First launch: no file yet, nothing to protect.
        let missing = DownloadManager.loadMetadata(from: url.deletingLastPathComponent().appendingPathComponent("none.json"))
        XCTAssertEqual(missing.downloads, [])
        XCTAssertTrue(missing.intact)
    }

    private let storedJSON = """
    {"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","title":"Movie","subtitle":"S1E2","poster":"p","quality":"720p","sourceURL":"https://x/y.mp4","fileName":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F.mp4","state":"completed","createdAt":0,"receivedBytes":10,"totalBytes":20}
    """

    func testDownloadDecodesStoredJSONWithoutDestination() throws {
        let download = try JSONDecoder().decode(Download.self, from: Data(storedJSON.utf8))
        XCTAssertEqual(download.destination, .app)
        XCTAssertEqual(download.state, .completed)
        XCTAssertEqual(download.id.uuidString, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        XCTAssertEqual(download.createdAt, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(download.receivedBytes, 10)
    }

    func testDownloadMissingRequiredKeyThrows() {
        let json = storedJSON.replacingOccurrences(of: "\"title\":\"Movie\",", with: "")
        XCTAssertThrowsError(try JSONDecoder().decode(Download.self, from: Data(json.utf8)))
    }

    func testDownloadRoundTrip() throws {
        let original = makeDownload(destination: .files)
        let decoded = try JSONDecoder().decode(Download.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        let keys = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
        XCTAssertEqual(keys.map { Set($0.keys) }, ["id", "title", "subtitle", "poster", "quality", "sourceURL", "fileName", "state", "createdAt", "destination", "receivedBytes", "totalBytes"])
    }

    func testDisplayName() {
        XCTAssertEqual(makeDownload(title: "Movie", subtitle: "S1E2").displayName, "Movie — S1E2")
        XCTAssertEqual(makeDownload(title: "Movie", subtitle: "").displayName, "Movie")
    }

    func testFractionCompleted() {
        XCTAssertEqual(makeDownload(state: .downloading, received: 50, total: 100).fractionCompleted, 0.5)
        XCTAssertEqual(makeDownload(state: .downloading, received: 150, total: 100).fractionCompleted, 1)
        XCTAssertEqual(makeDownload(state: .downloading, received: 0, total: 0).fractionCompleted, 0)
        XCTAssertEqual(makeDownload(state: .completed, received: 0, total: 0).fractionCompleted, 1)
    }

    func testSuggestedFileName() {
        let manager = DownloadManager.shared
        XCTAssertEqual(manager.suggestedFileName(for: makeDownload(title: "Movie: Part/1", subtitle: "S1E2", quality: "1080p")),
                       "Movie  Part 1 — S1E2 [1080p].mp4")
        let unnamed = makeDownload(title: "", subtitle: "", quality: "720p")
        XCTAssertEqual(manager.suggestedFileName(for: unnamed), "\(unnamed.id.uuidString) [720p].mp4")
    }

    // MARK: - PlaybackProgressStore

    func testProgressModelMatchesOriginalStore() throws {
        let container = PlaybackProgressStore.shared.container
        let entity = try XCTUnwrap(container.managedObjectModel.entitiesByName["PlaybackProgress"])
        XCTAssertEqual(entity.managedObjectClassName, "NSManagedObject")
        let attributes = entity.attributesByName
        XCTAssertEqual(Set(attributes.keys), ["key", "time", "updatedAt"])
        XCTAssertEqual(attributes["key"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(attributes["time"]?.attributeType, .doubleAttributeType)
        XCTAssertEqual(attributes["time"]?.defaultValue as? Double, 0)
        XCTAssertEqual(attributes["updatedAt"]?.attributeType, .dateAttributeType)
        XCTAssertFalse(attributes.values.contains { $0.isOptional })
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // The store actually loaded (load errors are only printed).
        let loaded = try XCTUnwrap(container.persistentStoreCoordinator.persistentStores.first)
        XCTAssertEqual(loaded.type, NSSQLiteStoreType)
        XCTAssertEqual(loaded.url, appSupport.appendingPathComponent("PlaybackProgress.sqlite"))
    }

    func testProgressSaveLoadRoundTrip() {
        let store = PlaybackProgressStore.shared
        let context = store.container.viewContext
        let key = "test|\(UUID().uuidString)"
        defer { deleteTestProgress() }
        XCTAssertNil(store.time(forKey: key))
        store.save(time: 42.5, forKey: key)
        context.reset() // drop pending changes: the read must come from PlaybackProgress.sqlite
        XCTAssertEqual(store.time(forKey: key), 42.5)
        store.save(time: 50, forKey: key)
        context.reset()
        XCTAssertEqual(store.time(forKey: key), 50)
    }

    // MARK: - Helpers

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/" + name)
    }

    /// Removes every `test|…` progress row, including rows left in the host app's store by earlier runs.
    private func deleteTestProgress() {
        let context = PlaybackProgressStore.shared.container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "PlaybackProgress")
        request.predicate = NSPredicate(format: "key BEGINSWITH %@", "test|")
        (try? context.fetch(request))?.forEach(context.delete)
        try? context.save()
    }

    /// Runs every block already queued on main.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    /// A task that is never resumed; like the real ones it carries the download id.
    private func idleTask(for id: UUID) -> URLSessionDownloadTask {
        let task = URLSession.shared.downloadTask(with: URL(string: "https://example.invalid/movie.mp4")!)
        task.taskDescription = id.uuidString
        return task
    }

    /// `contents` as downloads.json in a fresh temporary folder, removed after the test.
    private func metadataFile(_ contents: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("downloads.json")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func makeDownload(title: String = "Movie", subtitle: String = "S1E2", quality: String = "720p",
                              state: DownloadState = .downloading, destination: DownloadDestination = .app,
                              received: Int64 = 0, total: Int64 = 0) -> Download {
        let id = UUID()
        return Download(id: id, title: title, subtitle: subtitle, poster: "https://p/poster.jpg", quality: quality,
                        sourceURL: "https://x/y.mp4", fileName: id.uuidString + ".mp4", state: state,
                        createdAt: Date(timeIntervalSinceReferenceDate: 1000), destination: destination,
                        receivedBytes: received, totalBytes: total)
    }
}
