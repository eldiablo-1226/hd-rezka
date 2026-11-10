# d1a — app shell, home, common views

Status: no `unimplemented()` / `// RECONSTRUCT` left in my paths. Shared tree: `./build.sh d1a` → BUILD SUCCEEDED;
`SIM_ID=E2884B28-FE15-4A99-8F1F-3ABC3EDB8D6B ONLY=ViewsD1ATests ./build.sh d1a test` → 12/12 pass (the whole test
target, including the other areas' test files, compiles).

Starting point: an earlier d1 agent had already copied implementations of all my paths into the shared tree. I
re-derived every type from the binary and kept that code where it matched; the fixes are listed under "Changed".

## Files
- `app/HDrezka/App/HDRezkaApp.swift`, `app/HDrezka/App/SharedFilmId.swift` (SharedFilmId + SystemVersion)
- `app/HDrezka/Views/Common/`: AppleMusicStyleScrollView, BackButton (+ internal `Image.circleButtonLabel(color:)`, shared
  with ShareButton: the binary merged both label closures), Extensions (ViewDidLoadModifier, `View.onLoad`,
  `UINavigationController.viewDidLoad`), ForEachWithIndex (unchanged), HeaderScrollViewTitle,
  HideNotchAnimatedViewComponent, ScrollViews (FancyScrollView, HeaderScrollView + private geometry, private
  gesture NavigationConfigurator, BlurView, VisualEffectView, ScrollUp/DownHeaderBehavior), ShareButton.
  AppleMusicStyleScrollView.swift holds the private `NavigationConfigurator(hidden:)`.
- `app/HDrezka/Views/Shell/`: ContentView, ContentViewIpad
- `app/HDrezka/Views/Home/`: HomeView, HomeViewIpad, HomeGridViewIpad, TitleGridComponent(+Ipad), TitleCardComponent(+Ipad), MovieListView
- Removed `app/HDrezka/Views/Common/PosterImage.swift`: a helper type the earlier agent invented. The binary has the
  poster inline in each card's body. Ran `regen.sh`.
- New `app/HDrezkaTests/ViewsD1ATests.swift` (12 tests). No fixtures.

## Changed versus the earlier shared-tree code (all from the binary)
1. HeaderScrollView title bar: `.frame(height: max(elementsHeight, 44))`, not `max(…, 0)` (fcsel against 44.0 at 0x10003ef24).
2. TitleGridComponent (iPhone): the 3-second `startPaging` timer runs in `.onLoad` (`ViewDidLoadModifier` in the
   body type, 0x1000d9ff0). The iPad grid keeps `.onAppear` (`_AppearanceActionModifier`, 0x100079f98).
3. Title cards: `LazyImage(url:transaction: Transaction(animation: .easeInOut))` (0x1000d7324). The earlier code had
   no transaction. The poster is now inline again.
4. ContentViewIpad sidebar: `.navigationTitle(Text(verbatim: "HDRezka"))`. The binary builds a verbatim Text with no
   LocalizedStringKey (0x10010da44).

## Per type (main procedures)
- **HDRezkaApp** (0x1000fe7ac, onOpenURL 0x1000feaa0, init 0x1000feeb4). Injects `network` (`Network()`) and
  `downloadManager` (`StateObject(DownloadManager.shared)`) into ContentView.
  - `hdr://` links: if `url.description` minus `"hdr://"` is non-empty, `id = description.replacingOccurrences("hdr://", "https://ijobs.app/") + ".html"` and `isPresented = true`.
  - The host is hard-coded (not the mirror). Split out as `static filmURL(fromDeepLink:)`.
  - iPhone or iPad is decided in ContentView, not here.
- **SharedFilmId**: static `id = ""`. DetailsViewComponent(+Ipad) writes it; ShareButton and BookmarksSelection read it.
- **SystemVersion** (inlined at 0x1000e006c): `ProcessInfo().operatingSystemVersion` and `ProcessInfo().operatingSystemVersionString`.
- **ContentView** (0x1000891a8):
  - `idiom == .phone`, iOS 26 (0x100089784): `Tab("Home","house")` HomeView, `Tab("key_collections","square.grid.2x2.fill")` CollectionsView, `Tab("key_profile","person.circle.fill")` ProfileView(isPresentedDetail:), `Tab(role: .search)` SearchView `.tabPlacement(.sidebarOnly)`.
  - `idiom == .phone`, before iOS 26 (0x10008a6b8, labels 0x10008b3c0…): `.tabItem` Labels in the order Home, key_collections, Search ("magnifyingglass"), key_profile.
  - Any other idiom: ContentViewIpad.
- **ContentViewIpad** (0x10010cbac):
  - iOS 18+ (0x10010d170): Tab Home (HomeViewIpad with `.environmentObject(Network())`, a fresh Network as in the binary), key_collections (CollectionsViewIpad), key_profile ("person.crop.circle"), Search `.tabPlacement(.pinned)`.
  - Before iOS 18: NavigationSplitView. The sidebar is `HStack{VStack{List}}` with 4 NavigationLinks `.hoverEffect(.highlight)` (Home, collections, Search, profile; 0x10010da70). The detail is HomeViewIpad. Style `.automatic`.
- **HomeView** (0x1000ebff8):
  - `NavigationStack { ScrollView { VStack { TitleGridComponent(page:) }.navigationTitle(LocalizedStringKey(startupPageVariation.rawValue)) }.navigationDestination(isPresented:) { DetailsView(id:) } }`
  - `.preferredColorScheme(nil)` (`_PreferenceWritingModifier`, Optional.none stored)
  - `.onLoad { page = 1 }` (0x1000ec858)
  - `.onChange(of: scenePhase)`: `Task { if .active { remoteVersion = try await HeaderUpdater.updateHeader() } }` (0x1000ecb5c). This is the only call site of updateHeader in the binary.
  - `.onChange(of: page)`: `Task { try await network.fetchMovies(page: page, filter: String(describing: startupPageVariation)) }` (0x1000ecf3c). The filter is the case name: watching / last / popular / soon.
- **VPN**: the binary has no VPN detection and no popup. No string or API for it exists. The body type is NavigationStack plus the modifiers above, with no alert or sheet. `connectedToVpn`/`vpnPopup` are stored but never read; kept as is.
- **HomeViewIpad** (0x100057870): `VStack { HomeGridViewIpad(...).preferredColorScheme(nil) }`.
- **HomeGridViewIpad** (0x100031ae8): `NavigationStack { ScrollView { TitleGridComponentIpad(columns: [.adaptive(minimum: 160), spacing 16], page:).onLoad { page = 1 } } … }`
  - modifiers: `.navigationTitle(rawValue)`, `.onChange(of: page)` (fetchMovies as above), `.navigationDestination`
  - It never refreshes `remoteVersion`.
- **TitleGridComponent(+Ipad)** (0x1000d9e50 / 0x100079dfc):
  - `LazyVGrid(columns:)` holds `ForEach(network.movies) { NavigationLink(destination: DetailsView(id:)) { card } }.buttonStyle(PlainButtonStyle())`. The iPad card adds `.hoverEffect(.lift)`.
  - After the cards: `if startPaging { Color.clear.onAppear { page += 1 } }`.
  - Then `.padding()`, and a load/appear action: `asyncAfter(.now() + 3) { Task { startPaging = true } }` (0x1000da404, 0x10007ab78).
- **TitleCardComponent(+Ipad)** (0x1000d7248 / 0x1000db058):
  - The poster:
    - loaded state: `image.resizable()`, then `.transition(.asymmetric(insertion: .wipe(45°, blur 10), removal: .wipe(225°, blur 10)))`, using d2a's `AnyTransition.wipe` (inlined in the binary);
    - placeholder: `Rectangle().foregroundStyle(.quinary)`, overlaid with a shimmer. The shimmer is a 16-pt bar: height 200 (iPad 300), `.quaternary` and then a primary→gray gradient, rotated 30°, offset ±120, blur 15, `easeOut.repeatForever(false).speed(0.2)`. `onAppear { withAnimation { isAnimated = true } }`, then the same asymmetric wipe;
    - then `.scaledToFill().frame(113×171 | 164×247).clipShape(RoundedRectangle(8))`.
  - Texts in `VStack(.leading)`: the name (12 bold | `.body`, lineLimit 2) and the details (10 | `.footnote`, `.secondary`, lineLimit 1). Then `.frame(112×44 | 163×65, .topLeading).frame(maxWidth: .infinity)`.
- **MovieListView** (body 0x100090d80, root 0x10008e06c):
  - `NavigationStack` content:
    - `list` non-empty: `ScrollView(showsIndicators: false)` with the grid (iPad: 160/16 + TitleCardComponentIpad; otherwise 100/10 + TitleCardComponent), then `.onChange(of: page)`, `.padding(.horizontal)`, `.navigationTitle(name)`;
    - `list` empty: `ProgressView().onAppear`.
  - Items: `NavigationLink(destination: DetailsView(id:).onAppear { navId = movie.id }) { card.onAppear { if movie == list.last { page += 1 } } }`.
  - Requests: GET `id + "/page/" + n` with only `X-Hdrezka-Ios-App`/`-Version`. `responseString` hops to a MainActor Task and appends the parsed cards to `list` (0x10008fecc); errors are dropped.
  - Outer `.onAppear { navId = movieId }` and `.onDisappear { if navId == movieId { isPresentedMoreSheet.toggle() } }` (0x100090bf0 / 0x100090c54).
- **ShareButton** (0x10010f254):
  - The button shows only if `presentationMode.isPresented || hasBeenShownAtLeastOnce`. Its `onAppear` sets the flag.
  - `.url`: ShareLink to `SharedFilmId.id` with "ijobs.app" replaced by "rezka.ag".
  - `.universalLink`: `"hdr://" + id.removeMirror()` without ".html".
  - `.selectOption`: Menu with both, labelled "key_share+with+url" / "key_share+with+universal+link".
  - The label is "square.and.arrow.up", 18 pt high, with an ultraThin circle 30 pt.
- **BackButton** (0x100087aa8): the same visibility rule, "chevron.left", `presentationMode.wrappedValue.dismiss()`.
- **HeaderScrollView** (0x10003dbbc, geometry 0x10003e9ec, every branch re-derived): the embedded nerdsupremacist/FancyScrollView with the app's changes:
  - a white Back + Share HStack when the large-title weight is 1;
  - a title-bar HStack with Back · Spacer · Share and `Text(title.prefix(32))`, 17 pt semibold;
  - a clear rectangle on `.ultraThinMaterial`;
  - `zIndex(1000)`;
  - `.navigationBarTitle(Text(""), .inline).navigationBarHidden(true).background(NavigationConfigurator())`. The configurator keeps the swipe-back working (title "Some title", delegate proxy 0x100012814…).
- **AppleMusicStyleScrollView** (0x1000630cc): ScrollView offset probe, plus a BlurView over the status bar while scrolled, plus `.background(NavigationConfigurator(hidden: true))` (0x1000acc7c).
- **BlurView**: systemThinMaterial (style 7) at make time; on update `.dark`/`.light` from the colorScheme.
- **HideNotchAnimatedViewComponent**: values exactly as in 0x1000ad780/0x1000adcf0.

## Deviations from the stub defaults (no signature change)
The stub generator guessed @State defaults by type (Int → 1, Bool → false). The construction sites show other values: `HomeView.page = 0`, `HomeView.vpnPopup = true` (0x10008aa8c…, in ContentView) and `HomeGridViewIpad.page = 0` (0x1000579ac).
- `MovieListView.remoteVersion = "0.0.0"`, not the stub's `""`. Both construction sites call `AppStorage(wrappedValue: "0.0.0", "remoteVersion")`: 0x10004e5ec (DetailsViewComponent) and 0x1000d32d8 (DetailsViewComponentIpad). The stub took `""` from another `remoteVersion` site in the same body getter.
- This matters for paging. `.onLoad { page = 1 }` must change `page` so that `onChange` fetches the first page. With the guessed default of 1, page 1 would never be requested.
- The memberwise initializers are unchanged.
- `TitleGridComponentIpad.columns` keeps its stub default; HomeGridViewIpad passes the binary's `[.adaptive(160), spacing 16]` explicitly.

## `// shortcut:` guesses
1. `MovieListView` response handler. The binary inlined a Network method that returns a new array: `checkPremium()` + the file-private `getMovies`/`getId`/`getTitle`/`getDetails`/`getPoster` from Network.swift, with no append to `network.movies`. Network has no such method, so a throwaway `Network().parse(html:)` produces the same cards without touching the shared Network.
   - To verify: give Network that method and call it on the environment object.

## Contract requests
- Network (a2): `func parseList(html: String) throws -> [MovieSimple]`. It should do what `parse(html:)` does, but collect the cards into a new array instead of `movies`. Call site: the MovieListView response task (0x10008fecc).

## Notes
- `ShellCatalogViewTests.swift` in the shared test folder is from the earlier d1 agent and is not mine. It compiles now: it uses `HDRezkaApp.filmURL`, `ShareButton.siteLink/universalLink`, `HomeView.filter(for:)`, `MovieListView.pageRequest`, and d1b's `SearchView.quickSearchRequest`/`SearchResultsView.searchRequest`. ViewsD1ATests covers my part of it.
- New warnings: the throwing `Task { … }` in HomeView, HomeGridViewIpad and MovieListView is unused. That is faithful: the original drops these errors.
- Not checked: the screens in a simulator (layout was verified only by building) and live paging against the mirror.

## Review fixes
Four reviewer findings. I checked each against the disassembly and all four hold. Nothing was rejected.
1. **TitleCardComponent and TitleCardComponentIpad: the poster wipe is asymmetric.** This applies to the loaded image and to the placeholder. The new code is `.transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))`.
   - Evidence: the constants at 0x100439f80/f90/fa0/fb0 decode to (45°, 0), (45°, 1), (225°, 0) and (225°, 1). The blur is x26/x25 = 10.0.
   - The first `modifier(active:identity:)` call is the insertion and the second is the removal. Both go into `asymmetric` at four places: 0x1000d7ccc and 0x1000d8130 (iPhone), 0x1000dbae4 and 0x1000dbf48 (iPad).
   - d2a's own helper comment says the same.
2. **MovieListView: `@AppStorage("remoteVersion")` now defaults to `"0.0.0"`.**
   - At 0x10004e5b8…0x10004e5ec, x0 = `30 2e 30 2e 30` and x1 = 0xe5… This is a 5-byte small string, "0.0.0", passed with the key "remoteVersion". 0x1000d32d8 does the same.
   - The other defaults at these sites match the code: list = [], page = 1, navId = "".
   - The memberwise init is unchanged and the callers (d2a) are untouched. It is also listed under the stub-default deviations above.
3. **FancyScrollView.init(…header:content:) now sets `self.header = AnyView(header())`.**
   - 0x10001049c fetches the `Optional<A>: View` witness table and hands the Optional buffer to `AnyView.init`. There is no nil check, and the result is stored at +0x28.
   - The header-less init stores `xzr` at that offset.
   - The body (0x10000fb94) branches on `header != nil`. So with this init, `header` is never nil, which is also how upstream behaves. Its only caller always returns a header.
   - New test: `testHeaderInitWrapsTheOptionalSoTheHeaderBranchIsAlwaysTaken`. It failed before the fix.

Results:
- `./build.sh d1a`: BUILD SUCCEEDED.
- `ONLY=ViewsD1ATests ./build.sh d1a test`: 12/12 pass.

Open:
- `re/RECONSTRUCTION.md` (line 101, not mine) still says the LazyImage call sites use a symmetric `.wipe(angle: .degrees(45), blurRadius: 10)`. The binary shows the asymmetric 45°/225° form.
- The other LazyImage call sites outside d1a were not checked.
