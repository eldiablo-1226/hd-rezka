# Report b — playback, subtitles, progress, downloads

## Files changed
- `app/HDrezka/Player/CustomAVPlayer.swift`, `CustomAVAssetResourceLoaderDelegate.swift`, `PlayerViewComponent.swift`
- `app/HDrezka/Persistence/PlaybackProgressStore.swift`
- `app/HDrezka/Downloads/Download.swift`, `DownloadManager.swift`
- `app/HDrezka/App/AppDelegate.swift` (only `willPresent` options)
- new `app/HDrezkaTests/PlayerDownloadsTests.swift` (13 tests), `regen.sh` run once

No `unimplemented()` / `RECONSTRUCT` left in these files. `./build.sh b` succeeds.
`SIM_ID=713C06EF… ONLY=PlayerDownloadsTests ./build.sh b test` passes: 13 tests, 0 failures.

## HLS subtitles (CustomAVPlayer + loader)
- `CustomAVPlayer.init?(m3u8:subtitles:)`: queue `DispatchQueue(label: "resourceLoader")`; asset URL =
  `replaceURLWithScheme("mainm3u8", url:)`, which replaces everything before the first `:` (nil if there is no `:`).
  Then `AVURLAsset`, `resourceLoader.setDelegate(delegate, queue:)`, `replaceCurrentItem`, `preventsDisplaySleepDuringVideoPlayback = true`.
  The stub's `override init()`/`init(playerItem:)` are gone. In the binary those initializers are unimplemented traps.
- Loader schemes: `mainm3u8` downloads the real manifest with `URLSession.shared` (`[weak self]`), runs
  `processPlaylistWithData`, then answers with `getMainm3u8()`. `fragmentsm3u8` answers with `m3u8String`.
  `subtitlesm3u8` picks the subtitle whose `lang == url.host()`. Any other scheme returns false.
- Main playlist (exact):
  ```
  #EXTM3U\n
  per subtitle: #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="<name>",DEFAULT=NO,AUTOSELECT=NO,FORCED=NO,URI="subtitlesm3u8://<lang>",LANGUAGE="<lang ua→uk>"\n
  then  #EXT-X-STREAM-INF:BANDWIDTH=1280000,SUBTITLES="subs",CLOSED-CAPTIONS=NONE\nfragmentsm3u8://foo
  or, with no subtitles:  #EXT-X-STREAM-INF:BANDWIDTH=1280000,CLOSED-CAPTIONS=NONE\nfragmentsm3u8://foo   (no trailing newline)
  ```
  `LANGUAGE` is `lang.replacingOccurrences(of: "ua", with: "uk")` (literal `ua`/`uk` read from the disasm).
- Subtitle playlist: `#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-MEDIA-SEQUENCE:1\n#EXT-X-PLAYLIST-TYPE:VOD\n#EXT-X-ALLOW-CACHE:NO\n#EXT-X-TARGETDURATION:<Int(d)>\n#EXTINF:<String(format:"%.3f",d)>, no desc\n<subtitle.link>\n#EXT-X-ENDLIST`,
  where d = `playlistDuration` (d0 loaded from that field before the call).
- Duration: split the manifest on `"\n"` and reset `playlistDuration = 0`. For each line starting with `#EXTINF:`,
  add `Double(line.components(separatedBy: ":")[1].dropLast()) ?? 0`. A title after the comma makes the value
  unparsable, so it counts 0, as in the original. The next line becomes
  `URLComponents(manifest).query = nil → url.deletingLastPathComponent().absoluteString + segment`. Lines are joined with `"\n"`.

## CoreData (PlaybackProgressStore), from 0x1000f30c4
- Entity `PlaybackProgress`, `managedObjectClassName = NSStringFromClass(NSManagedObject)`.
- Attributes, in order, all `isOptional = false`:
  - `key` String (700)
  - `time` Double (500), defaultValue 0.0
  - `updatedAt` Date (900)

  Names come from the small-string immediates `0x79656b`, `0x656d6974`, `"updatedA"+"t"`.
- `NSPersistentContainer(name: "PlaybackProgress", managedObjectModel:)`.
- Store: `urls(.applicationSupportDirectory(14), .userDomainMask)[0]/PlaybackProgress.sqlite`, with `try?` createDirectory.
  `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically` are true. Load errors print `PlaybackProgressStore load error: …`.
  `viewContext.automaticallyMergesChangesFromParent = true`.
- `save`/`time`: viewContext, `NSFetchRequest(entityName:)`, `"key == %@"`, fetchLimit 1, fetch errors swallowed (`try?`).
  `save` inserts via `entitiesByName[...]!` when nothing is found and sets `key`, then sets `time` and `updatedAt = Date()`.
  Save errors print `PlaybackProgressStore save error: …`.

## Player (PlayerViewComponent + Coordinator)
- `makeUIViewController` builds the player:
  - `localFileURL` set: `AVPlayer(playerItem: AVPlayerItem(url:))` with `preventsDisplaySleep`.
  - otherwise: `CustomAVPlayer(m3u8: URL("\(url):hls:manifest.m3u8")!, subtitles:)!`. Both force unwraps are in the binary.
- `externalMetadata = [title(name, lang "und"), iTunes subtitle(voiceActing), artwork]`.
  The artwork item is filled asynchronously: JPEG q=1.0, `dataType = kCMMetadataBaseDataType_PNG`, "und".
- Controller settings: `isAudioSpatializationAllowed = false`, PiP + `canStartPictureInPictureAutomaticallyFromInline`, `updatesNowPlayingInfoCenter = false`.
  `exitsFullScreenWhenPlaybackEnds = (no next episode)`.
- Audio session: `setCategory(.playback)` and `setActive(true)`. On error it prints `Error initializing audio:`.
  Then `coordinator.attach`, then `play()`.
- `dismantleUIViewController` calls `persistAndDetach()`; `deinit` calls it too.
- `Coordinator.init(progressKey:name:subtitle:poster:autoplay:)` (from the `__allocating_init` symbol). The 18 fields are kept in order.
- Progress restore runs on the KVO `status` observation (`[.initial, .new]`) once `.readyToPlay`. It seeks only when
  saved > 5 and (duration is not finite or duration − 10 > saved), using `CMTime(seconds:, 600)` with zero tolerance.
- Progress saving:
  - every 5 s from the periodic observer, only when `didRestore` and the time is finite and > 0;
  - in `persistAndDetach`;
  - 0 when the episode ends.
- Lifecycle: on background, `controller.player = nil` unless PiP or external playback is active. On foreground the player is re-attached.
- Now Playing:
  - title, artist (= subtitle if not empty), duration (finite and > 0), elapsed time, rate, artwork from `posterUrl`.
  - remote commands: play, pause, toggle, ±15 s skip, change position. A missing player returns `.commandFailed`.
  - everything is removed in `endManualNowPlaying`.
- Autoplay (`handlePlaybackEnded`):
  1. The next episode is `season.episodes[firstIndex(of: currentEpisode)+1]`. It sets `isAdvancing` and saves 0.
  2. A `Task { [weak self] }` calls `MovieDetailsService().getMovieVideo(voiceActing:season:episode:id:)`, then
     `getAvailableQualities().preferred(name: qualityName)`.
  3. If UserDefaults `isLoggedIn` and `saveHistory` are both true, it calls `try? AccountService().saveWatchingState(...)`.
  4. It builds the key `movieId|translatorId|seasonId|episodeId` and a new `AutoplayContext(qualityName: quality.name)`.
  5. On the MainActor it runs `swapToNext`.
  6. Errors print `Autoplay next episode failed:` and reset `isAdvancing`.
- `swapToNext`:
  - the subtitle is `voiceActing.name.isEmpty ? episode.name : "<va>, <episode>"`;
  - it rebuilds title/subtitle metadata, swaps the player, updates progressKey, autoplay and subtitle, then re-attaches observers.

## Downloads
- Correction to the brief: `me.keet.HDRezka.downloads.storage` is the **`storageQueue` label**. It is not a defaults key.
  Metadata is the JSON file `Application Support/Downloads/downloads.json`, written as `JSONEncoder` `[Download]` with
  `.atomic` on `storageQueue`. It is loaded with `JSONDecoder` in `init`. Finished `.app` files and `<uuid>.resume` files are in the same folder.
- `Download.init(from:)`: all keys are required except `destination` (`decodeIfPresent … ?? .app`). The 76 KB is
  partial-init cleanup. `encode(to:)` is the synthesized one (all 12 keys, `encode`). It lives in an extension so the memberwise init survives.
- `displayName = subtitle.isEmpty ? title : title + " — " + subtitle`.
  `fractionCompleted = total > 0 ? min(received/total, 1) : (completed ? 1 : 0)`.
- `download(...)`, inlined into `DownloadParamsSheet`:
  1. `requestAuthorization()`. It asks for alert|badge|sound unless the status is authorized or provisional.
  2. For `.gallery`, it asks for Photos `.addOnly` access when the status is `.notDetermined`.
  3. It creates `Download(fileName: "<uuid>.mp4", state: .downloading, bytes 0)`.
  4. The task comes from the background session if `background_url_session` (default true), otherwise from the default session.
     `taskDescription = id`. The task is stored under `tasksLock`.
  5. On main it runs `insert(at: 0)` and `saveMetadata`, then `task.resume()`.
- Pause, resume, delete, localURL:
  - `pause`: `cancel(byProducingResumeData:)`, writes `<id>.resume`, sets the state to `.paused` on main.
  - `resume`: uses non-empty resume data (and deletes the file), or `sourceURL`.
  - `delete`: cancels, removes the file and the resume data, removes the entry on main.
  - `localURL`: only for completed `.app` downloads whose file exists.
- Delegate:
  - `didWriteData`: received/total on main. The JSON is persisted at most every 2 s per id (`lastProgressPersist`).
  - `didFinishDownloadingTo` calls `persistDownloadedFile`:
    - `.app` → Downloads folder;
    - `.gallery` → tmp `<uuid>.mp4`, then album "HDrezka" (`fetchAlbum` / create placeholder / `saveVideo`), then the tmp file is deleted (defer);
    - `.files` → Documents with `suggestedFileName`.
    It then sets `.completed` or `.failed` and sends a notification ("Download successfully" or "Download failed",
    subtitle "<displayName> downloaded/failed to download\n<error>").
  - `didCompleteWithError` for `NSURLErrorCancelled`: keeps the resume data and sets `.paused` only when
    `NSURLErrorBackgroundTaskCancelledReasonKey == 0` (user force quit). Otherwise it ignores it.
  - Other errors: `.failed` plus a notification.
  - `urlSessionDidFinishEvents` calls `(UIApplication.shared.delegate as? AppDelegate)?.backgroundCompletionHandler?()` on main (not cleared).
- On launch (`reconcileOnLaunch`, inlined in `init`): background tasks are re-adopted. Entries still marked downloading
  without a task become `.paused` if resume data exists, otherwise `.failed`.
- `suggestedFileName`: `displayName` (UUID if empty), with `/\:?%*|"<>` replaced by spaces, plus ` [<quality>].mp4`.
- AppDelegate `willPresent` → `[.banner, .list, .sound, .badge]` (0x1b; the stub had `[.banner, .sound]`).

## Deviations from the stubs, all inside my files
- The Coordinator observer fields are `NSObjectProtocol?`: the binary mangling is `So8NSObject_pSg`. `swift-interface.txt` simplifies this to `NSObject?`.
- Made non-private for tests:
  - `PlaybackProgressStore.container` is internal;
  - `m3u8String` and `playlistDuration` are `private(set)`;
  - `DownloadManager.suggestedFileName(for:)` is internal.
- New private helpers with no behaviour change: `observeRate()` (named by its closure symbol), `notificate(_:_:_:)`, `skip(by:)`,
  `setState`, `task(for:)`/`setTask`, `resumeDataURL`, `setPlaybackTimes`, and a `private extension AutoplayContext { followingEpisode }`.
- The order of the private `notificate` parameters (title, identifier, subtitle) is my naming choice. The binary only gives
  the types `(String, String, String?)`; the closure context slots confirm which value is which.

## Faithful quirks kept (not fixed)
- `swapToNext` looks for the old artwork after `replaceCurrentItem(with: nil)`, so the artwork is never carried over to the next episode.
- `#EXTINF` lines with a title count 0 s. Absolute segment URLs would be prefixed with the manifest folder.
- `delete` removes only `Downloads/<fileName>`, also for gallery and files destinations.
- The background observer for the end of playback uses the literal `"AVPlayerItemDidPlayToEndTimeNotification"`.

## `// shortcut:` guesses
None. Everything above comes from the pseudocode or the disassembly.

## Contract requests and notes for other areas
- Called, not changed: `MovieVideo.getAvailableQualities()`, `Array<Quality>.preferred(name:)`,
  `MovieDetailsService.getMovieVideo(voiceActing:season:episode:id:)`, `AccountService.saveWatchingState(...)`.
  The autoplay path needs these implemented (owners: a1b and the account area).
- The callers that build `PlayerViewComponent`/`CoverData` should use the same progressKey format for series:
  `movieId|translatorId|seasonId|episodeId`. The original `QualitySelectionSheet.play` also joins with `"|"`.
  If the format differs, restore after autoplay will not find the progress.
- `PlayerDownloadsTests` relies on the synthesized memberwise inits `MovieSubtitles(name:link:lang:)` and `Download(id:…)`.
  Please do not add an explicit init to `MovieSubtitles` (or the models file) without keeping them.
- `DownloadParamsSheet` should call `downloadManager.download(title:subtitle:poster:quality:url:destination:)`
  with the `downloadDestination` AppStorage value. It shows the AlertKit "Download started" itself.

## Review fixes
Two reviews, ten findings. Each claim was checked against the binary before any change.

Applied:
1. `DownloadDestination.id` is now `String` (`rawValue`), as in the binary.
   - The `Identifiable.id` and `RawRepresentable.rawValue` witnesses share 0x10005bc88. Both are `b 0x1000595dc`, which builds `app`, `gallery` and `files`.
   - The `ID: Hashable` witness (0x100032ce0) returns `_$sSSSHsWP`.
   - The binary's settings picker is a `ForEach<[DownloadDestination], String, …>`.
2. `Download.CodingKeys` no longer has a `String` raw type.
   - swift-interface lists only CodingKey, CustomDebugStringConvertible, CustomStringConvertible, Equatable and Hashable.
   - nm has no `rawValue` or `init(rawValue:)` for it.
   - The JSON keys are unchanged (round-trip test).
3. `CustomAVPlayer.loaderQueue` is now `var`. The fieldmd IsVar flag is set; the loader's three scheme constants are `let`.
4. Tests now use real input.
   - `Fixtures/hls-film-205-360p.m3u8` is the live answer to the 360p link of `video-film-205.json` + `:hls:manifest.m3u8`, fetched 2026-11-10.
     The request gets a 302 to `nexus.stream.voidboost.one`. The manifest has 1426 `#EXTINF` and segments `./i3exf.mp4:hls:seg-N-v1-a1.ts`.
   - The test checks three things:
     - the duration (1425 × 6 + 3.419 = 8553.419);
     - the rewritten playlist, against an expectation built a different way (literal folder + line);
     - the subtitle playlist header for that duration.
   - One rewritten segment URL answered 206 `video/MP2T` on the live CDN.
   - New edge case: an absolute segment URL also gets the folder prefix (0x1000aa1c0 calls `hasPrefix` once, for `#EXTINF:`).
   - New edge case: an `#EXTINF` on the last line is kept and not counted. The `temp_0 == 1` exit comes before `dropLast`/`Double`.
   - I re-derived the `getMainm3u8` and `getSubtitlem3u8WithDuration` literals from their digests. Their lengths (0x32, 0x3a, 0x4c, 0x5d, 0x76) match the test strings.
5. Progress store test.
   - The round trip calls `viewContext.reset()` after each save. The read now has to come from the SQLite store and not from pending changes.
   - The model test checks the loaded store (`NSSQLiteStoreType`, `Application Support/PlaybackProgress.sqlite`) and not only its description.
   - Cleanup deletes every `test|…` row, including rows left by earlier runs.
6. Player decisions are now pure internal helpers; behaviour is unchanged.
   - New: `PlayerViewComponent.progressKey(movieId:translatorId:seasonId:episodeId:)` and `PlayerViewComponent.restorePosition(saved:duration:)`.
     Both are `nonisolated`, because the autoplay `Task` calls the key helper off the main actor.
   - The `AutoplayContext.followingEpisode` extension is now internal.
   - Re-checked against the binary:
     - 0x100080c50: `fccmp` against 5.0 with `b.gt`, a finite mask, then `duration - 10 > saved`;
     - 0x100080e4c: `firstIndex(of:)` plus a bounds check;
     - 0x100081c2c: the three `|` appends, the last one being `MovieEpisode.id`.
   - Tests:
     - last or missing episode → nil;
     - saved = 5 → no seek;
     - 90 of 100 → no seek;
     - NaN or infinite duration → seek;
     - the key format.
7. Download tests.
   - New `localURL(for:)` test: a URL comes back only for a completed `.app` download whose file exists.
   - New `DownloadManager.forceQuitResumeData(_:)` holds the force-quit decision of `didCompleteWithError` (0x1000b5df4):
     - a missing reason key or a failed cast is ignored;
     - reason 0 keeps the resume data;
     - empty data is ignored.
     It is tested with hand-built `NSError`s.
   - New `testDownloadDestinationIdIsRawValue`.

Rejected or left as is:
- Finding 4, the real site JSON with subtitles: not added.
  - It needs a live POST to `/ajax/get_cdn_series/` for a title with subtitles, and film pages are 403 from here.
  - Subtitle parsing belongs to a1b (`String+Video.swift`, covered by `VideoServiceTests`). The loader only reads `name`, `link` and `lang`.
- Finding 6, the next-episode subtitle text: stays inline.
  - It is a single ternary.
  - Re-checked at 0x1000822f8: an empty `voiceActing.name` gives `episode.name`, otherwise `name + ", " + episode.name`.
- Finding 7, the reconcile choice and the 2 s throttle: no helpers. Each is one comparison, and a test would only restate it.
  - Reconcile (0x1000b172c): the state defaults to 3 (failed) and becomes 1 (paused) when `<id>.resume` exists.
  - Throttle (0x1000b280c): `d8 < 2.0` skips the save. The check runs whether or not the id is found.
- Findings 8, 9 and 10: the code is faithful to the binary, so it stays for the fidelity pass. They are improvement-pass items.
  - Finding 8: the dictionary setter runs before `dispatch_async` in 0x1000b51c4 and 0x1000b5df4.
  - Finding 9: `time(forKey:)` and the seek run inline in 0x100080c50.
  - Finding 10: 0x1000ae728 uses `try?` on both Data and decode, and reconcile calls `saveMetadata` on both paths.

Contract note: callers may build `CoverData.progressKey` with `PlayerViewComponent.progressKey(...)`, or inline the same `|` format as the original `QualitySelectionSheet.play` does.
Contract note for views: `DownloadDestination.id` is now the `String` rawValue. In `ForEach(DownloadDestination.allCases)` pickers, tag with `.tag($0)`, as the binary's `tag<DownloadDestination>` does. `.tag($0.id)` would never match the selection.

Results (2026-11-10, shared tree):
- `SIM_ID=713C06EF… ONLY=PlayerDownloadsTests ./build.sh b test`: 21 tests, 0 failures. That is 13 + 8 new: real manifest, playlist edge cases, following episode, restore position, key format, destination id, localURL, force-quit resume data.
- `./build.sh b`: BUILD SUCCEEDED, no warnings in area-b files. The autoplay `Task` call caused a main-actor warning; marking the helpers `nonisolated` fixed it.
- Between 15:39 and 15:48 every shared build failed with "Multiple commands produce …/HDrezka.app/idle-notif-cooldown.json" (and two more files). Hook state in `app/HDrezka/.omc` and `app/HDrezka/Views/.omc` had been regenerated in as resources. `project.yml` now excludes `**/.omc`. Area b did not touch this.
