# d1b: search and collections views

Status: all 12 types are reconstructed; no `unimplemented()` or `// RECONSTRUCT` is left in
`app/HDrezka/Views/Search/` or `app/HDrezka/Views/Collections/`.
- Shared tree: `./build.sh d1b` → `** BUILD SUCCEEDED **`; `ONLY=ViewsD1BTests ./build.sh d1b test` → 3/3 pass.
  `ONLY=ShellCatalogViewTests` (run on a snapshot of the shared tree) → 10/10 pass, including the two search-request
  tests that file has for my views.

## Files
- `app/HDrezka/Views/Search/{SearchView,SearchResultsView,SearchGridComponent,SearchGridComponentIpad}.swift`
- `app/HDrezka/Views/Collections/{CollectionsView,CollectionsViewIpad,CollectionsListViewComponent,CollectionsListViewComponentIpad,CollectionsMovieListViewComponent,CollectionsMovieListViewComponentIpad,CollectionsCardViewComponent,CollectionsCardViewComponentIpad}.swift`
- `app/HDrezkaTests/ViewsD1BTests.swift` (new; regen.sh run). There are no fixtures.

## How the evidence was read
Most SearchView procedures appear in INDEX.tsv under truncated mangled names. I took the full symbols from `nm.txt`
and decoded the opaque return types by hand; they give the exact modifier chain of each closure. Constants come from
the disassembly: `fmov`/`movk` immediates and `__const` reads (GridItem sizes at 0x100439de0/0x10043cf00/0x100438c40/0x100439df0,
the delay at 0x10043a690 = 0.2). I resolved the `@Published` key paths through their field-offset references (fixups → nm),
e.g. 0x10043c858 → `Network._quickSearch` and 0x10043c940 → `Network._search`.

## Per type
| Type | Procedures | Notes |
|---|---|---|
| SearchView | body witness 0x10007275c, closures 0x100070158, 0x100070590, 0x100070cac, 0x100070fac, 0x100071438, 0x10007167c, 0x100071814, 0x1000719a4, 0x100071b04, 0x100071ccc, 0x100071fac, 0x1000723d0 | `NavigationStack { VStack { Color.clear.foregroundStyle(.clear).frame(0×0).searchable(text: $search)…textInputAutocapitalization(.never).autocorrectionDisabled(true).onChange(of: search).submitLabel(.search).onSubmit(of: .search).navigationDestination($isPresentedResult) { SearchResultsView(request: $search) } }; ScrollView { ForEach(network.quickSearch) rows }.animation(.spring(0.5, 1, 0)) }.navigationTitle("Search").navigationDestination($isPresented) { DetailsView(id: id) }` |
| SearchView: quick search | onChange → `DispatchQueue.main.asyncAfter(.now() + 0.2)` → `AF.request` GET `https://<mirror>/engine/ajax/search.php/` with `["q": search]` (the current text when the timer fires, not the onChange value), `URLEncodedFormParameterEncoder.default`, headers `X-Hdrezka-Ios-App: 1` and `-Version: <remoteVersion>` only (no Content-Type) → `responseString` → `Task { @MainActor in quickSearch = []; if let html { try parseQuickSearch } }` | There is no empty-text guard and no debounce cancel: every keystroke fires its own request. |
| SearchView: submit | 0x100071814 | `network.search = []`, `isPresentedResult.toggle()` |
| SearchView: row | 0x100071ccc/0x100071fac/0x1000723d0 | `HStack { NavigationLink(destination: DetailsView(id: result.id)) { Image("arrowshape.turn.up.left.fill").foregroundStyle(.primary); VStack(.leading) { Text(name).padding(.leading, 5).foregroundStyle(.primary).lineLimit(2); Text(details).foregroundStyle(.secondary).lineLimit(3) } }.buttonStyle(.plain) }.padding().frame(maxWidth: .infinity, alignment: .leading)` |
| SearchResultsView | 0x100079034 (body), 0x100077694, 0x1000781f4, 0x100078448, 0x1000793c4, 0x100078b30, 0x100078df8, 0x100078f0c | `NavigationStack { if !network.search.isEmpty { ScrollView { VStack { phone ? SearchGridComponent() : SearchGridComponentIpad() } }.navigationTitle(request) } else if isShowingUnavailableView { if #available(iOS 17) ContentUnavailableView.search(text: request) else Image("magnifyingglass").font(.system(size: 50)).foregroundStyle(.secondary).padding(4) + Text("key_nothing+found").font(.title3).bold() } }`. onAppear: `asyncAfter(.now() + 4) { isShowingUnavailableView = true }`, then GET `https://<mirror>/search/?do=search&subaction=search` + `q=<request>` with the same two headers; the handler does `print(response)`, then `Task { @MainActor in if let html { try parseSearch } }`. onDisappear: `network.search = []`, `isShowingUnavailableView = false`. |
| SearchGridComponent(+Ipad) | 0x100013670/0x1000132b8/0x1000134bc, 0x1000ba4b0/0x1000ba0f8/0x1000ba2fc | `LazyVGrid(columns) { ForEach(network.search) { NavigationLink(destination: DetailsView(id: movie.id)) { TitleCardComponent(Ipad)(model: movie) }.buttonStyle(.plain) } }.padding()` |
| CollectionsView(+Ipad) | 0x100086d54, 0x1000a95d4 | `CollectionsListViewComponent(Ipad)(isPresented: $isPresented, id: $id).environmentObject(CollectionsParser())`. A new parser is created on every body evaluation, as in the original. |
| CollectionsListViewComponent | 0x100034888 (body), 0x100032cf8, 0x100032ee0, 0x1000330dc, 0x100033320, 0x10003384c, 0x1000339dc, 0x100033e0c…, 0x100034310…, init 0x100034a54 | `NavigationStack { ScrollView(showsIndicators: false) { LazyVGrid(columns) { ForEach(collections) { NavigationLink(destination: CollectionsMovieListViewComponent(id:, name:).environmentObject(CollectionsParser())) { CollectionsCardViewComponent(collection:).onAppear { if collection == collections.last { page += 1 } } }.buttonStyle(.plain) } }.navigationTitle("key_collections") }.padding(.horizontal, 16).navigationDestination($isPresented) { DetailsView(id: id) } }`. `.onAppear` and `.onChange(of: page)` both run `Task { try await parseCollections(CollectionsNetwork().getCollections(page: page)) }` (on the main actor; errors are dropped). Because onAppear reloads the current page, reappearing appends that page again (original behavior). |
| CollectionsListViewComponentIpad | 0x100057030, 0x100055f40, 0x100056128, 0x100056324, 0x100056530, 0x100056a24, 0x100056af4… | Same layout without paging. `ForEach(collections, id: \.name)` (key path 0x10043b358: struct offset 16 = `name`), destination `CollectionsMovieListViewComponentIpad(name:, id:)`, card `CollectionsCardViewComponentIpad`, and onAppear loads `getCollections(page: 1)` only. |
| CollectionsMovieListViewComponent | 0x1000ac6a0, 0x1000abe68, 0x1000ac020, 0x1000ac13c, 0x1000ac340…, item 0x1000134bc (shared with SearchGridComponent) | `NavigationStack { ScrollView(showsIndicators: false) { LazyVGrid { ForEach(moviesInCollections) → DetailsView / TitleCardComponent } }.padding(.horizontal).onAppear { Task { try await getWatchingNowMoviesInCollection(collectionId: id, page: 1) } }.navigationTitle(name) }` |
| CollectionsMovieListViewComponentIpad | 0x1000f6ab8, 0x1000f6cb4, 0x1000f6dd0, 0x1000f6fd4… | It has no NavigationStack; the order is `.navigationTitle(name).padding(.horizontal).onAppear{…page: 1}`, with TitleCardComponentIpad. |
| CollectionsCardViewComponent(+Ipad) | 0x10008d860 (body), 0x10008be0c, 0x10008c920, 0x10008d180, 0x10008d800, 0x10008daf8; iPad 0x1000b7898, 0x1000b83ac (overlay/onAppear closures shared) | `VStack { LazyImage(url: URL(string: poster), transaction: Transaction(animation: .easeInOut)) { image.resizable().transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))) / else Rectangle().foregroundStyle(.quinary).overlay { Rectangle().frame(height: 200).frame(width: 16).foregroundStyle(.quaternary).foregroundStyle(LinearGradient([.primary, .gray], top→bottom)).rotationEffect(.degrees(30)).offset(x: isAnimated ? 120 : -120).blur(radius: 15).animation(.easeOut.repeatForever(autoreverses: false).speed(0.2), value: isAnimated) }.onAppear { withAnimation { isAnimated = true } }.transition(.wipe…) }.scaledToFill().frame(170×98).scaleEffect(1.1).clipShape(RoundedRectangle(8, .continuous)); VStack(.leading) { Text(name).font(.system(size: 12, weight: .medium)).lineLimit(2) }.frame(170 × 30, .topLeading).frame(maxWidth: .infinity) }`. The iPad variant differs only in the title height (60). Both branches build the asymmetric wipe inline (Wipe consts 0x100439f80…fb0: insertion 45°, removal 225°, blur 10; see Review fixes). |

## Deliberate deviations from the stubs (signatures unchanged)
- **`columns` defaults.** The stub generator used one placeholder for every `columns` property
  (`gen_view_stubs.py:106`, adaptive 100/10). I replaced it with the binary's values, which callers inline when they construct the view:
  SearchGridComponent adaptive(min 110)/10; SearchGridComponentIpad adaptive(150)/16; CollectionsListViewComponent
  2 × `.flexible()`/10; CollectionsListViewComponentIpad adaptive(160)/16; CollectionsMovieListViewComponent adaptive(110)/10;
  CollectionsMovieListViewComponentIpad adaptive(160)/16. Names, types, order, `var` and the memberwise initializers are unchanged.
- **Testable request builders.** The original called `AF.request(url, method: .get, parameters: ["q": …], headers: …)`
  inline. I build the same request through `SearchView.Request` (a `URLRequestConvertible` over Network.swift's
  `siteRequest`/`siteHeaders`), so Alamofire still builds it lazily and a failure still reaches the response handler.
  I also added `SearchView.quickSearchRequest(mirror:version:text:)` and
  `SearchResultsView.searchRequest(mirror:version:query:)`, because the shared `ShellCatalogViewTests.swift` (written for the
  former combined d1 area) calls them and the test target does not compile without them.

## `// shortcut:` guesses
None. Every value above comes from the binary.

## Contract requests
None. Everything I call already exists: `Network.parseQuickSearch/parseSearch`, `CollectionsNetwork.getCollections`,
`CollectionsParser.parseCollections/getWatchingNowMoviesInCollection`, `siteRequest`/`siteHeaders`,
`AnyTransition.wipe`, and the memberwise initializers of DetailsView and TitleCardComponent(Ipad).

## Environment note (resolved upstream)
`app/HDrezka/.omc/` and `app/HDrezka/Views/.omc/` hold oh-my-claudecode hook state. xcodegen added them as app resources,
so for a while every tag failed with "Multiple commands produce …/HDrezka.app/idle-notif-cooldown.json". The owner of
project.yml has since added `**/.omc` excludes, which fixed it. I touched neither the directories nor project.yml.
Until that fix landed, I verified my code on an `.omc`-free snapshot of the shared tree.

## Review fixes
Two reviewer findings, both checked against the binary and **confirmed**. Both are fixed.

| Finding | Evidence I checked | Fix |
|---|---|---|
| CollectionsCardViewComponent: both LazyImage branches used a symmetric 45° wipe | 0x10008c920: image branch `AnyTransition.modifier` ×2 (0x10008ca40, 0x10008ca78), then `asymmetric(insertion:removal:)` (0x10008ca88); placeholder branch the same at 0x10008cea4/0x10008cedc/0x10008ceec. `__TEXT,__const` read from the IPA: 0x100439f80/f90 = (0.7853981633974483 rad = 45°, progress 0/1), 0x100439fa0/fb0 = (3.9269908169872414 rad = 225°, progress 0/1); blur `0x4024000000000000` = 10 in both branches. | `private var wipe = .asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))`, used as `.transition(wipe)` at both sites (same form as DetailsViewComponent). |
| CollectionsCardViewComponentIpad: same defect | 0x1000b83ac: `modifier` ×2 + `asymmetric` at 0x1000b84cc/0x1000b8504/0x1000b8514 and 0x1000b8930/0x1000b8968/0x1000b8978; same consts and blur 10. | Same change. |

At these four call sites the original builds the modifiers inline. It does not call the out-of-line
`wipe(angle:blurRadius:)`. That helper, as d2a reconstructed it in WipeTransition.swift (I did not read 0x100042754),
only clamps the blur to 0...30. The clamp leaves 10 unchanged, so calling the helper gives the same values.

Results: `./build.sh d1b` → `** BUILD SUCCEEDED **`; `ONLY=ViewsD1BTests ./build.sh d1b test` → 3/3 pass.

Outside d1b, not changed by me: the disassembly has 20 `asymmetric(insertion:removal:)` calls in 10 procedures, two
per procedure. Besides the Collections cards and the Details views (already asymmetric), they are in
`TitleCardComponent(Ipad)` (0x1000d7b64, 0x1000db97c; owner d1a) and `PersonPosterView` / `PersonCardComponent`
(0x100097b90, 0x1000364e4; owner d2b). All four files still use the symmetric `.transition(.wipe(angle: .degrees(45), blurRadius: 10))`.
I did not check their constants. The `LazyImage call sites use .transition(.wipe(...45...))` note in re/RECONSTRUCTION.md
also contradicts the binary.
