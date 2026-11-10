# d2a: movie page (Views/Details core)

## Files
All under `app/HDrezka/Views/Details/`: `DetailsView`, `DetailsViewComponent`, `DetailsViewComponentIpad`, `InfoSheetViewComponent`,
`InfoTabView`, `BookmarksSelectionListViewComponent`, `StarsView`, `FranchiseRowView`, `SeasonRowView`, `YouTubePlayerViewComponent`,
`TextFirstLabel` (unchanged), `WipeTransition` (rewritten). New test file `app/HDrezkaTests/ViewsD2ATests.swift` (5 tests, regen.sh run).
No `unimplemented()` / `// RECONSTRUCT` left. `./build.sh d2a` succeeds in the shared tree; `ONLY=ViewsD2ATests` passes (5/5).

Method: closure trees decoded from the mangled opaque types (structure, modifier order), immediates and literal pools from the
disassembly (sizes, fonts, strings, SF Symbols, offsets of `self` / `MovieDetailed` fields), pseudocode for the closures with logic.

## Per type
- **DetailsView** (0x10007caa8, witness 0x10007d7e4): `VStack { phone ? DetailsViewComponent : DetailsViewComponentIpad }` each with
  its own `.environmentObject(MovieDetailsParser())`, then `.navigationBarBackButtonHidden(true)`.
- **DetailsViewComponent** (body 0x1000431c0, closure #1 0x1000437c4):
  - empty `movieDetailed`: `ProgressView(value: 0.5).progressViewStyle(.circular)` with two `.onAppear`: the page GET (closure #2,
    0x10004f004) and `SharedFilmId.id = id` (closure #3, 0x100051fbc).
  - page GET: `AF.request(id, method: .get, headers: [X-Hdrezka-Ios-App: 1, X-Hdrezka-Ios-App-Version: remoteVersion])` — `id` is
    the full page URL; `responseString` → `Task { @MainActor }` → `parseMovieDetails(html:movieId: id)`, retried once on throw
    (0x10004f59c), result unused (the parser appends to `movieDetailed`).
  - otherwise `ForEach(movieDetailed.prefix(1))` → `FancyScrollView(title, .white, headerHeight 650, .parallax, .offset)` with
    `navigationDestination($isPresentedPersonInfoView) { PersonView(id: personId, isPresentedMoreSheet: $isPresentedMoreSheet) }`,
    `navigationDestination($isPresentedList) { MovieListView(id: listData.id, name: listData.name, movieId: id, …) }`,
    `.onAppear { bookmarks = detail.bookmarks }`, `.task(priority: .userInitiated)` trailer (0x10004e7e0): POST
    `https://<mirror>/engine/ajax/gettrailervideo.php`, form `id = id.getMovieId()`, only the two X-Hdrezka headers; on success
    `DispatchQueue.main.async { trailer = try? parseTrailerId(response:) }`.
  - title everywhere: `preferOriginalTitle ? nameOriginal ?? nameRussian : nameRussian`.
  - header: `GeometryReader { LazyImage(hPoster) → fallback LazyImage(poster) → quinary Rectangle with the shimmer }` (each wrapped in
    the asymmetric wipe), `.onAppear { withAnimation(.default) { isAnimated = true } }`; overlay VStack: title (largeTitle tight,
    bold, 4 lines), first genre line `"\(genre) • \(releaseDate ?? "unknown") • \(country)".uppercased()`, then
    `!comingSoon ? (AVAILABLE ? [Watch, Bookmark] + Download : globe "Video is unavailable in this region") : clock key_comingsoon`
    (both fallbacks keep `add_to_bookmarks`). Two `onGeometryChange` feed innerHeight/outerHeight; the blur background mask stops are
    clear @ (outer−inner)/outer·0.75, black 0.96 @ (outer−inner)/outer, black 0.96 @ 1 (0x10004af10).
  - sheets: Watch → `VideoParamsSheet(id:coverData:video:)` + `MovieDetailsService()`, detents [.medium], drag indicator;
    `fullScreenCover(item: $coverData)` → `PlayerViewComponent(url: body, subtitles, name: title, voiceActing: actingName,
    poster: detail.hPoster, progressKey, autoplay)` ignoring safe area, overlays hidden; Download →
    `DownloadParamsSheet(id:name: title, poster: hPoster, voiceActing:, seasons: detail.seasons)` + `MovieDetailsService()`;
    Bookmark → `BookmarksSelectionListViewComponent($bookmarks)`; "key_more" → full-screen `InfoSheetViewComponent`;
    "key_episodes+schedule" label → schedule sheet (NavigationStack/ScrollView of all groups, xmark close, iOS 26 AnyView branch).
  - content: `InfoTabView.padding(.top)`, description (3 lines) with the "key_more" fade button, `schedule[..<1]` (first group,
    first 5 items), franchise list.
- **DetailsViewComponentIpad** (0x1000c8efc / 0x1000c9548): same data flow and requests; `ScrollView { VStack { HStack { poster
  311×470 r11, info column }, InfoTabView, schedule, franchise }, Spacer }`, toolbar back button (`dismiss()`, chevron.left on an
  ultraThin circle) + `ShareButton(color: .primary)`; icon buttons (bordered, capsule, red): key_watch/play.fill (sheet
  VideoParamsSheet), Download/arrow.down.circle, key_bookmarks/bookmark, key_more/ellipsis.circle (full-screen InfoSheet); genre line
  NOT uppercased; coming soon uses gauge.with.needle; schedule sheet has a "done" text (accent color), title "schedule".
- **InfoSheetViewComponent** (0x100004000…): NavigationView/ScrollView/VStack(spacing 8): names, Divider, trailer
  `YouTubePlayerViewComponent(YouTubePlayer(source: .video(id:)))`, selectable description, key_information rows (country,
  release date, genres, directors, actors + key_and+others, lists) in HFlow with commas; person tap = `personId = id.removeMirror()`,
  toggle `isPresentedPersonInfo`, toggle `isPresentedMoreSheet` (0x100008de0); list tap = `listData = list`, toggle list, toggle
  sheet (0x100009908); toolbar "done" → dismiss.
- **InfoTabView** (0x1001094cc): IMDb (`%.1f`) / КиноПоиск (`%.2f`) value, votes `"(" + votesCount + ")"` when `showVotesCount`,
  `StarsView`, tap opens the rating link; Duration/Minutes, Age/Years; Dividers only when the idiom is not phone; `.padding(.bottom, 8)`.
- **BookmarksSelectionListViewComponent** (0x1000686e8): logged out / no categories states; rows toggle with animation and send
  `AccountService().addToBookmarks(movieId: SharedFilmId.id.components("/").last!.components(".").first!, bookmarkUserCategory:)`
  in a `@MainActor` Task (0x1000698dc; note "." not "-"); iOS 17+ symbol replace transition (0x100069d1c).
- **StarsView / SeasonRowView** (0x10010c00c / 0x1000d8f7c): previous drafts verified unchanged (bar width rating/5·0.5·width,
  size 9 stars; line limits 1/2/1, bottom padding 8).
- **FranchiseRowView** (0x10007afc4): `VStack(.leading) { HStack(spacing: 10) }`; NavigationLink(destination: DetailsView) +
  plain style for other parts, plain row (no 2-line limit on the name) for the current one; Divider unless position == 1; rating
  colored `UIColor(resource: .accent).blended(with: .green, weight: rating/10)`; `blended` fileprivate (0x1000dfcc0, blend 0x1000dfba8).
- **YouTubePlayerViewComponent** (0x1000acefc): README overlay, `Text(verbatim:)` error, 16:9 fill, corner 10.
- **WipeTransition**: `wipe` (0x100042754) is ONE `.modifier(active: (angle, 0, r), identity: (angle, 1, r))`, r clamped to 0…30;
  `Wipe.body` (0x10005045c / closure 0x10004f8cc) masks with `GeometryReader { mask(size:).blur(second·(1−first)).compositingGroup() }
  .padding(−second).animation(nil, value:)`; `mask(size:)` (0x10004fcbc) and `boundingSize` (0x100050638) as before.

## Stub deviations (no signature change)
- `DetailsViewComponent.innerHeight` / `outerHeight` default **1** instead of 0: the binary initializes both to 1.0 (0x10007d398) and
  the gradient divides by `outerHeight`; only DetailsView constructs the type.
- `AnyTransition.wipe` semantics now match the binary (single modifier, see contract requests).
- Internal static helpers for tests: `DetailsViewComponent.title/genreLine/headerFadeLocation`, `BookmarksSelectionListViewComponent.postId`.

## `// shortcut:` guesses (all marked in code)
1. BookmarksSelectionList: `bookmarks.map { $0 }` as the ForEach data (specialized map at 0x100068334 not decoded).
2. BookmarksSelectionList: `.navigationBarTitleDisplayMode(.inline)` (argument at 0x1000692ec not decoded).
3. Phone schedule sheet xmark taps toggle `isPresentedScheduleSheet` (merged thunk behind 0x100055b94).
4. iPad schedule sheet "done" tap toggles the flag (closure behind 0x1000d23b4).
5. iPad schedule sheet `.navigationBarTitleDisplayMode(.inline)`.
6. InfoSheet `YouTubePlayer` uses the default `Configuration()` (all arguments at 0x100004834 look like defaults).
Layout values not listed were read from the binary; remaining small layout guesses (RoundedRectangle style, ScrollView indicators
in the phone schedule sheet) are approximations allowed by the brief.

## Contract requests / notes for other areas
- **All LazyImage call sites** (binary: PersonCardComponent, CollectionsCardViewComponent(+Ipad), PersonPosterView,
  TitleCardComponent(+Ipad), the two Details views): the original writes
  `.transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))`
  (20 sites, checked). The shared tree's TitleCardComponent(+Ipad), PersonPosterView, PersonCardComponent,
  CollectionsCardViewComponent(+Ipad) currently use `.transition(.wipe(angle: .degrees(45), blurRadius: 10))`, which now wipes back
  along the same angle on removal; switch them to the asymmetric form to match the binary.
- d1a: the binary constructs `MovieListView` with `@AppStorage("remoteVersion")` default `"0.0.0"` (closure 0x10004e49c); the stub
  has `""`.
- Callers: `DetailsView(id:)` must receive the full page URL (the page GET requests `id` as is; `SharedFilmId.id` keeps it).
- Faithful traps kept: `detail.genres[..<1]` and `schedule[..<1]` trap on empty arrays like the binary's bounds checks
  (`getSchedule` returns nil when the block is missing, so only an empty `genres` can trap).

## Review fixes
Applied (both in `DetailsViewComponentIpad.swift`):
- Main iPad `ScrollView` now `ScrollView(.vertical, showsIndicators: false)`: `Axis.Set.vertical` → x25 (0x1000c969c), `mov w1, #0x0`
  (0x1000c96f8) into `ScrollView.init(_:showsIndicators:content:)` at 0x1000c9700. The other d2a ScrollViews pass `w1 = 1` and already
  match: InfoSheet 0x100004150, phone schedule sheet 0x10004d578 (so its indicators are verified, no longer a guess),
  BookmarksSelection 0x100068918, iPad schedule sheet 0x1000d1b90.
- iPad genre line now `Text(verbatim: "\(genre.name) • \(releaseDate ?? "unknown") • \(country)")` (no uppercasing, unlike the phone):
  closure 0x1000cded4 builds a plain String (`_StringGuts.grow(16)`, name@genre+0x10, " • ", releaseDate@0x70 ?? "unknown", " • ",
  country@0x80) and passes `Text.font` an inlined Text (String, Storage tag 0 = `.verbatim`, `__swiftEmptyArrayStorage` modifiers),
  i.e. `Text(verbatim:)`; there is no LocalizedStringKey call. The two reviewer findings on this line were the same issue.

Not applied:
- RECONSTRUCTION.md:101 (symmetric `.wipe` guidance): the claim is right but the file is outside d2a. Since the review the 12 other-area
  LazyImage sites (Home, Person, Collections) have been switched to the asymmetric 45°/225° form by their owners (grep verified), so only
  the guide line is still stale; it is the main session's to update. WipeTransition.swift stays as is.

`./build.sh d2a`: BUILD SUCCEEDED. `ONLY=ViewsD2ATests ./build.sh d2a test`: 5/5 passed.
