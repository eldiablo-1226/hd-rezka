# d2b: playback and download sheets, premium notice, person screens

## Files
- `app/HDrezka/Views/Details/VideoParamsSheet.swift`. Also holds `extension Array where Element == MovieVoiceActing { getPremiumActingList(actingList:), getNonPremiumActingList(actingList:) }`. Both are internal, as in the binary (0x100076b24 / 0x100076c64). VideoParamsSheet is their only caller.
- `app/HDrezka/Views/Details/QualitySelectionSheet.swift`
- `app/HDrezka/Views/Details/DownloadParamsSheet.swift`
- `app/HDrezka/Views/Details/PremiumUnavailableView.swift`
- `app/HDrezka/Views/Person/{PersonView,PersonPosterView,PersonCardComponent,PersonGridComponent,PesonHorizontalGrid}.swift`
- `app/HDrezkaTests/ViewsD2BTests.swift`: 7 tests, all passing. There are no fixtures.

No `unimplemented()` or `// RECONSTRUCT` is left. Every stub stored property is unchanged.
- `./build.sh d2b` succeeds in the shared tree.
- `SIM_ID=B9CABEA9-… ONLY=ViewsD2BTests ./build.sh d2b test`: 7 tests, 0 failures.

The PremiumUnavailableView and Person drafts from `.build/work-d2` were reviewed against the binary. Two of them were fixed (see below). The three sheets were written from the evidence. They were then compared with a newer work-d2 draft that appeared during the session, and the evidence decided every difference.

## VideoParamsSheet (body 0x1000a25fc, content 0x1000a3308…0x1000a687c)
- `if detailsNetwork.movieDetailed.isEmpty`: shows `ProgressView().progressViewStyle(.circular)`. Its onAppear (0x1000a2af8) sends `AF.request(id, .get, headers: X-Hdrezka-Ios-App: 1, X-Hdrezka-Ios-App-Version)`, with no Content-Type.
  - The response handler runs `Task { @MainActor }`, then `try detailsNetwork.parseMovieDetails(html:movieId: id)`.
  - It then sets `voiceActing = details[0].voiceActing`, then `seasons = details[0].seasons`.
  - `id` is therefore the page URL.
- Otherwise it shows `NavigationStack { VStack { Form { … } } }`, titled `"key_watch"` (inline).
  - The Form holds:
    - `Section(footer: useInfuse ? Text("key_infuse_reminder").font(.footnote).foregroundStyle(.secondary) : nil)` (`init(footer:content:)` at 0x1000a3bbc), containing:
      - `Picker("voice acting")` with `Section(header: Text(verbatim: "Premium"))` (premium actings) and an unnamed Section (the rest). Both use `ForEach(…, id: \.name)`.
      - when `seasons != nil`: `Picker("season")` (`id: \.name`) and `Picker("episode")` (`id: \.self`).
    - a `NavigationLink`:
      - label: `"key_watch"` in `Color(.accent)`, `.headline`, `frame(maxWidth: screen width / 1.2, maxHeight: 20)`, `.plain` style.
      - destination: `selectedActing.isPremium && hasPremium.isEmpty` → `PremiumUnavailableView`. Otherwise `QualitySelectionSheet`, with the selected season and episode when `seasons != nil`, else `nil` for both (`_ConditionalContent<PUV, _ConditionalContent<QSS, QSS>>`).
- onAppear (0x1000a5d40):
  - nonPremium, then premium lists from `voiceActing!`;
  - the first `isSelected` voice acting, season and episode;
  - `asyncAfter(.now() + 1) { canProceed = true }`.
- `onChange(selectedActing)`: when `canProceed`, `seasons = try await detailService.getSeriesSeasons(movieId: id, voiceActing: selectedActing)` in a `Task { @MainActor }`.
- `onChange(selectedSeason)`: the first `isSelected` episode.

## QualitySelectionSheet (body 0x10001d924, play 0x10001f7c4…0x1000206c4)
- `qualitySelectionPresent` (field 16) chooses between two views:
  - The Form, titled `"key_select_quality"` (inline):
    - `if !proceedSubtitles.isEmpty && useInfuse`: `Picker("key_subtitle_language")`. Rows show the subtitle name, or `String(localized: "key_no_subtitles")` when the name is empty (`id: \.name`).
    - A Section of quality `Button`s (`id: \.name`), black or white by colorScheme. Each sets `video = quality.url`, then calls `play`.
  - Or `ViewThatFits { ProgressView() }.frame(max ∞).background(Color(UIColor.systemGray6))`, with an onAppear Task (0x10001f208) that does the following:
    1. `getMovieVideo(voiceActing:season:episode:id:)`.
    2. `movieVideo = getAvailableQualities()`, `proceedSubtitles = subtitles ?? []`, then `selectedSubtitle = [0]`.
    3. If `preferredQuality != .ask && !useInfuse && !didAutoPlay` and `movieVideo.preferred(name: rawValue)` finds a quality, it autoplays that quality (`didAutoPlay`, `video`, `play`).
    4. Otherwise it sets `qualitySelectionPresent = true`.
- `private play(quality:)` runs a `Task { @MainActor }`:
  1. When `isLoggedIn && saveHistory`, it runs `_ = try await AccountService().saveWatchingState(…)`. A throw ends the Task, so nothing plays (original).
  2. With `useInfuse`, it opens `openURL(URL(string: "infuse://x-callback-url/play?x-success=some-app://x-callback-url/playbackDidFinish&x-error=some-app://x-callback-url/playbackDidFail&url=\(video)")!)`. It appends `&sub=\(selectedSubtitle.link)` when `selectedSubtitle.name != ""`. Nothing is percent-encoded.
  3. Otherwise it calls `dismiss()`, then `DispatchQueue.main.async` sets `coverData = CoverData(…)` with:
     - body: `video`
     - actingName: `"<acting>, <episode>"`, or whichever of the two exists
     - subtitles: `proceedSubtitles`
     - progressKey (see below)
     - autoplay: `AutoplayContext(movieId: id, …, qualityName: quality.name)` only when `autoplayNextEpisode` is on and the season and episode exist.
- **progressKey** (0x1000206c4): `id + "|" + translatorId + "|" + (season?.id ?? "0") + "|" + (episode?.id ?? "0")`.
  - Films use `<id>|<translatorId>|0|0`.
  - Series match agent b's `movieId|translatorId|seasonId|episodeId`. b's autoplay uses `AutoplayContext.movieId`, which equals this `id` (the page URL VideoParamsSheet received).
- These are static helpers so they can be tested; the binary builds them inline: `infuseURL`, `progressKey`, `coverActingName`.

## DownloadParamsSheet (body 0x10002af1c)
- `VStack { Form { … } }`:
  - Section 1:
    - when `seasons != nil`: the season and episode pickers;
    - `Picker("voice acting")` over `voiceActing!`;
    - `Picker("quality", selection: $video)`, tagged with `quality.url`.
  - Section 2:
    - `Label("Download", systemImage: "square.and.arrow.down")` (0x10002c9ec):
      - It computes `quality = movieVideo.first { url == video }?.name ?? ""`.
      - The subtitle is `"S<season digits> E<episode digits> [<acting>]"`, using `trimmingCharacters(in: .decimalDigits.inverted)`. A film uses the acting name.
      - It then calls `downloadManager.download(title: name, …, url: URL(string: video)!, destination: downloadDestination)`. This is the `@EnvironmentObject`, as in the binary, where `download` is inlined.
      - It shows the toast `"Download started"` (AlertKit `.done`, `.iOS17AppleMusic`, `.success`).
    - `Label("key_copy", systemImage: "doc.on.doc")`: `UIPasteboard.general.string = video`, then the toast `"key_copied"` with the same style.
  - A `List` over `downloads.filter { title == name }`, with `onDelete` deleting from that same filtered list. Each row is a `VStack(.leading, spacing: 8)` containing:
    - `displayName` (caption, lineLimit 1);
    - when completed: `Label("key_downloaded_status", "checkmark.circle")` (caption, green);
    - otherwise: `ProgressView(value: fractionCompleted)`, plus `downloadByteProgress` (caption2, secondary) when `receivedBytes > 0`.
- onAppear (0x10002e8a8):
  - `selectedActing = voiceActing![firstIndex(isSelected) ?? 0]`;
  - the first selected season;
  - `downloadManager.requestAuthorization()`.
- `onChange(selectedActing)` (0x10002ecd8) starts two Tasks:
  1. `seasons = getSeriesSeasons(movieId: id, …)`;
  2. `getMovieVideo` (with the season and episode when `seasons != nil`, else without), then `movieVideo = qualities` and `video = movieVideo.last!.url`.
- `onChange(selectedSeason)`: picks the first selected episode, then loads the qualities. `onChange(selectedEpisode)` only loads the qualities. The binary merged their resume partials (0x100031708), so here they share the private `loadQualities()`.
- `downloadByteProgress(_:)` (0x100030ce8) returns `ByteCountFormatter(.file)` for the received bytes, plus `" / " + total` when `totalBytes > 0`. It is private in the binary and internal here so the tests can call it.

## PremiumUnavailableView (0x1000a6980, 0x1000a7240, 0x1000a7370)
- The draft is kept, and it matches the binary:
  - three texts with `.padding(.bottom, 6/12)`;
  - a `"key_buy"` Label with `star.fill`, `TextFirstLabel`, `.bold`, padding 6 and `maxWidth ∞`;
  - the button is `.bordered`, with horizontal padding 12, purple tint and bottom padding 6;
  - it opens `https://hdrezka.ag/payments`;
  - the outer view has `.padding(6)` and `.multilineTextAlignment(.center)`.

## Person screens
- **PersonView** (0x100092b60…0x100097428):
  - If the details are loaded, it shows a `ScrollView(.vertical, showsIndicators: false)` with `.onDisappear { if !isNavigated { isPresentedMoreSheet.toggle() } }`.
  - Otherwise it shows `ProgressView().onAppear { Task { @MainActor in personDetails = try await PeopleRepository().getPersonDetails(id: id) } }`.
  - **Fix to the draft:** the binary orders the info rows career, birth date, birth place, **height**, death date, death place (closures #2–#6 in 0x100093e8c, fields checked at offsets 0x40/0x50/0x80/0x60/0x70). The career blocks come in the order actor, director, producer, screenwriter, operator, editor, artist (verified).
- **PersonPosterView** (0x10009784c):
  - `LazyImage(… .easeInOut)`, `aspectRatio(.fill)`, `frame(140×213)`, `clipShape(RoundedRectangle(11, .continuous))`.
  - The shimmer placeholder is verified: 350/30 bars, 30° rotation, offset ±120, blur 15, `easeOut.repeatForever(false).speed(0.3)`.
- **PersonCardComponent** (0x100035aa4):
  - **Fix to the draft:** the image uses `.cornerRadius(50)` (opaque `cornerRadius(_:antialiased:)`), not `clipShape`.
  - The rest is verified: frame 76, padding 16, a 108×108 clear placeholder, title3/semibold, caption opacity 0.6, callout with top padding 0.1, then frame ∞, `.quinary`, RoundedRectangle(20, .continuous), padding 16/12.
- **PesonHorizontalGrid / PersonGridComponent**: the drafts are verified.
  - "more" opens `PersonGridComponent(movies:title:)` with `.environmentObject(Network())`, `onAppear { isNavigated = true }` and `onDisappear { false }`.
  - Each row shows `DetailsView(id:)` with the same appear and disappear handlers.
  - Each card is `TitleCardComponent(model:)` with `.padding(.leading)`, and the list shows `prefix(15)`.
  - The grid is a `LazyVGrid(columns:)` with `.padding()`, the navigation title and `.large`.

## `// shortcut:` guesses
None. Every value above was read from the pseudocode or the disassembly.

## Contract requests
None.

## Notes for other areas
- d2a (DetailsViewComponent):
  - `VideoParamsSheet.id` must be the full page URL (it is GET-requested as is).
  - Both sheets need `.environmentObject(MovieDetailsService)`.
  - `DownloadParamsSheet` also needs `DownloadManager`, which HDRezkaApp injects at the root. It force-unwraps `voiceActing` in onAppear and in its picker, as in the binary.
- Faithful crashes kept:
  - `details[0]` when the page parses to nothing;
  - `URL(string: video)!` for a download before a quality is chosen;
  - `movieVideo.last!` when a title has no links.
- The new `#NoUseUnstructuredThrowingTask` warnings come from the original's unhandled throwing Tasks; I left them in place.

## Review fixes
I checked all three reviewer findings against the disassembly and confirmed each one. None was rejected.

1. **PersonPosterView: the wipe transition is asymmetric** (closure #1 in body, 0x100097b90). Both branches, the image and the shimmer placeholder, call `AnyTransition.modifier(active:identity:)` twice, then `AnyTransition.asymmetric(insertion:removal:)`. Decoding the `__TEXT,__const` pairs gives these values:
   - 0x100439f80/f90 are (0.785398 rad = 45°, progress 0/1), the insertion.
   - 0x100439fa0/fb0 are (3.926991 rad = 225°, progress 0/1), the removal.
   - The blur is `0x4024000000000000` = 10.

   Both `.transition`s are now `.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))`.
2. **PersonCardComponent: same fix** (closure #1 in closure #1 in body, 0x1000364e4). The image branch and the `Color.clear` 108×108 branch use the same four constants and the same modifier/modifier/asymmetric sequence.
3. **VideoParamsSheet: the Infuse reminder is the footer of the pickers' Section, not a Form row.**
   - At 0x1000a3a08, the code reads `_useInfuse` (self+0x10) through the `AppStorage.wrappedValue` getter. When it is true, it builds `Text("key_infuse_reminder")`, then `.font(.footnote)`, then `HierarchicalShapeStyle.secondary`. When it is false, it zero-fills the value (nil).
   - That optional is passed as the value to `Section<EmptyView, _, _>.init(footer:content:)` at 0x1000a3bbc.
   - The demangled body type agrees: `Form<TupleView<(Section<EmptyView, …, (<<opaque foregroundStyle>>)?>, <<opaque buttonStyle>> NavigationLink)>>`. That is exactly two Form children.
   - I removed the separate `if useInfuse { … }` row. The reminder now goes through the value-based `Section(footer: useInfuse ? … : nil) { … }`, which is the same init the binary calls. The VideoParamsSheet bullet above is corrected.

All three are layout changes, so there is no new test.
- `./build.sh d2b`: BUILD SUCCEEDED.
- `SIM_ID=B9CABEA9-… ONLY=ViewsD2BTests ./build.sh d2b test`: 7 tests, 0 failures.

Still open, outside d2b:
- The "Known facts" line in `re/RECONSTRUCTION.md` says LazyImage call sites use the symmetric `.transition(.wipe(angle: .degrees(45), blurRadius: 10))`. The binary uses the 45°/225° asymmetric pair. d2a's `WipeTransition.swift` header already says so.
- d1a's `Views/Home/TitleCardComponent.swift` and `TitleCardComponentIpad.swift` still use the symmetric form (lines 15 and 31). Their owners should check those against the binary.
