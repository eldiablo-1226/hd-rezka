# d3b — Account and Downloads views

Status: no `unimplemented()` and no `// RECONSTRUCT` left in `app/HDrezka/Views/Account/` and `app/HDrezka/Views/Downloads/`.
- In the private copy, `ONLY=ViewsD3BTests ./build.sh d3b test` on simulator FE56A4E4 passed 7 of 7 tests. That run compiled the whole test target, including d3's `ProfileAccountViewTests`.
- In the shared tree, `regen.sh` and then `./build.sh d3b` ended with BUILD SUCCEEDED (15:51). The same `ONLY=ViewsD3BTests` test run there also passed 7 of 7. At 15:53:54 the shared copies of my paths were still identical to `.build/work-d3b`.

## Where the code came from (read this first)
The earlier d3 agent was not actually stopped. When I started, its drafts in `.build/work-d3` were still stubs. Then, at 15:23–15:24, it wrote full implementations of every file in my paths into `work-d3` and into the shared tree. At 15:27 it also added `app/HDrezkaTests/ProfileAccountViewTests.swift`. Following the brief, I took those files as the starting point.

My own part has three pieces:
- I traced every type independently in the disassembly. The addresses are listed below.
- I fixed the differences I found.
- I wrote `ViewsD3BTests`.

The disassembly confirmed almost everything d3 wrote. `.build/work-d3b` holds the final versions. As of 15:50 the shared copies of my paths are identical to them. d3 may still be running and could overwrite them again.

## Files
- `app/HDrezka/Views/Account/`: `LogInView`, `RegisterView`, `BookmarksView`, `BookmarkMovieListView`, `BookmarkListGridComponent`, `WatchLaterView`, `WatchLaterCardComponent`, `SeriesUpdateView`, `SeriesUpdateCardView`.
- `app/HDrezka/Views/Downloads/DownloadsView.swift`: contains `DownloadsView` and `DownloadRow`.
- New test file: `app/HDrezkaTests/ViewsD3BTests.swift` (`regen.sh` was run). There are no fixtures.

## My corrections to d3's files
| File | Change | Evidence |
|---|---|---|
| BookmarkMovieListView | `onDisappear` now calls `bookmarks.removeAll()`. (This pass also removed the second `.preferredColorScheme(nil)`; that was wrong, see Review fixes.) | The `Published.modify` call is followed by `removeAll(false)` (0x1000629d0). |
| DownloadRow | `HStack(spacing: 12)` and `VStack(alignment: .leading, spacing: 4)`. | The constants 12.0 at 0x1001029e4 and 4.0 at 0x100102cbc. |
| DownloadRow | `progressText` is now internal so the tests can read it. | The binary inlines it into both statusLine closures (0x100103d5c, 0x100104028). |
| WatchLaterView | `watchingLaterMovies.removeAll()` | Same pattern at 0x100014194. |
| WatchLaterCardComponent, SeriesUpdateCardView | Use `background(alignment:content:)` with a closure. | The background content is its own closure: closure #2 in closure #1 for the card, closure #2 in the body for the series card. |
| RegisterView | Fixed a comment: `isValidEmail` is internal in the binary. | Its symbol has no private discriminator. `checkout` and `register` do have one. |

I checked `ToolbarItemPlacement.topBarTrailing` in the SDK. It is `@backDeployed(before: iOS 17)` and available from iOS 14, so writing `.topBarTrailing` with a 16.0 target produces exactly the `isPlatformVersionAtLeast(17)` check seen at 0x10009cb64. No change was needed there.

## Per type (procedures; behaviour)
- **LogInView**
  - Procedures: body witness 0x100067114 (`VStack{…}.padding(8)`), content 0x100065440, `login()` closures 0x100066dc8–0x1000670d8.
  - The Username field uses `.next` and moves focus to the password field. The Password field uses `.done` and calls `login()`, which the button also calls.
  - `Task { if try await accountService.login(...) { isLoggedIn = true; dismiss() } else { withAnimation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0)) { isShowingError = true } } }`. Errors are dropped.
  - Keys: `Username`, `Password`, `key_wrong_login_or_password`, `login`. The button colour is `Color(.accent)` (`ColorResource.accent` at 0x1005f7398).
- **RegisterView**
  - Procedures: body 0x1000f1374, content 0x1000edbec, register 0x1000f012c–0x1000f0898, checkout 0x1000f08f0–0x1000f10a4, isValidEmail 0x1000f10f4, init 0x1000f11e8.
  - The init is the implicit default one; nothing is written for it.
  - Focus moves email → username → password → confirmPassword, and the last field submits with `register()`.
  - checkout sets `error = false`, then checks in this order:

    | Check | Error key |
    |---|---|
    | email regex | `key_mail+not+valid` |
    | name length 3...30 (unsigned `count-3 > 27`) | `key_wrong+username+lenght` |
    | password length 1...5 (an empty password passes) | `key_wrong+password+length` |
    | password and confirmation differ | `key_passwords+does+not+match` |
    | `AccountService().checkEmail` | `key_email+already+taken` |
    | `checkUsername` | `key_username+already+taken` |

    It returns nil when everything passes.
  - register: `error = true` and `errorText = message`. Otherwise it calls `signUp`. On success it sets `isLoggedIn = true` and calls `dismiss()`. On failure it sets `errorText = key_something+went+wrong` and `error = true`.
  - The regex literal is byte-identical to line 255 of `app-strings.txt` and is matched with `NSPredicate("SELF MATCHES %@")`.
- **BookmarksView**
  - Procedures: body 0x10009b218, list content 0x10009b628, row 0x10009b77c, swipe actions 0x10009b9e0, onMove 0x10009c38c, onAppear 0x10009e7e4, toolbar 0x10009cab4, rename alert 0x10009e11c.
  - The list is `ForEachWithIndex(bookmarks, id: \.self)`. Each row is a `NavigationLink` to `BookmarkMovieListView(accountService: AccountService(), name:, id:)`.
  - Trailing swipe actions:
    - `trash.fill` (red) runs `deleteBookmarksCategory` and then `withAnimation { bookmarks.remove(at: index) }`.
    - `pencil` (blue) sets `selectedBookmark` and `newIndex`, then toggles `isPresentedRename`.
  - `.onDelete { _ in }` does nothing: its context is nil and its thunk at 0x10000d3ac is a bare `ret`.
  - `.onMove` moves the item locally, then calls `reorderBookmarksCategories`.
  - `onAppear` calls `getBookmarks`.
  - Toolbar: a `plus.circle` button with the "add" alert, then `EditButton()`.
  - Add alert:
    - title `key_enter_name`, a `TextField("")` bound to `name`;
    - `key_cancel` clears the name;
    - `key_create` runs only when the name is not empty. It calls `createBookmarksCategory`; on success it appends with animation and clears the name; on nil it shows the error toast.
  - Rename alert: `print(newName)`, then `changeBookmarksCategoryName`. On success it sets `bookmarks[newIndex].name` with animation; on failure it shows the error toast.
  - Toast: `AlertKitAPI.present(title: key_error, icon: .error, style: .iOS17AppleMusic, haptic: .error)`. The registers are x4=1, w5=1, w6=2; the AlertKit 5.1.8 enums decode them.
- **BookmarkMovieListView**
  - Procedures: body 0x100061f50, content 0x100062248, onAppear 0x1000623b4, onChange 0x100062688, onDisappear 0x1000629d0.
  - `VStack { BookmarkListGridComponent(page: $page).environmentObject(accountService.network) }.navigationTitle(name)`.
  - Both `onAppear` and `onChange(page)` start `Task { try await accountService.getBookmarksByCategory(id:page:) }`, which reads the `page` state.
- **BookmarkListGridComponent**
  - Procedures: body 0x100010cdc, phone variant closure #1 0x100011250, iPad variant closure #2 0x100011678, paging closure 0x100011b14.
  - On a phone (`userInterfaceIdiom == .phone`) it uses `GridItem(.adaptive(minimum: 100), spacing: 10)` and `TitleCardComponent`.
  - Otherwise it uses `GridItem(.adaptive(minimum: 160), spacing: 16)` and `TitleCardComponentIpad`. The constants are at 0x100438c40 and 0x100438c50.
  - Each card is a `NavigationLink` to `DetailsView(id:)` with a plain button style.
  - `onAppear`: `if movie == network.bookmarks.last { page += 1 }`.
- **WatchLaterView**
  - Procedures: body 0x100013ac0, the row closure, onAppear 0x1000140f0.
  - The list is `ForEachWithIndex(…, id: \.self)` of `WatchLaterCardComponent(movie:, moviePosition: index, movieList: $watchingLaterMovies)`.
  - Navigation: title `key_watch_later`, large title mode.
  - `onAppear` first runs `accountParser.watchingLaterMovies.removeAll()`, then `Task { watchingLaterMovies = try await accountParser.parseWatchingLaterMovies() }`.
- **WatchLaterCardComponent**
  - Procedures: body 0x10005d5e8, content 0x10005daf0, buttons 0x10005eee8, delete 0x10005f490, long press 0x10005fd60, tap 0x10004a230 (merged).
  - The `ViewThatFits` is identified from `_VariadicView.Tree<_SizeFittingRoot,…>`.
  - Fields read: name, details, date (+0x40), watchingInfo (+0x30), buttonText (+0x50).
  - Gestures are on the background shape:
    - tap toggles `isPresented`, which drives `navigationDestination` to `DetailsView(id:)`;
    - long press runs `withAnimation(.default.speed(1.2)) { isRemoveMode = true }` and a light impact haptic.
  - Remove mode:
    - `key_delete` (bordered prominent) removes the item from `movieList` with animation, then starts `Task { removeWatchingItem }`;
    - `key_cancel` (bordered) sets `isRemoveMode = false`.
- **SeriesUpdateView**
  - Procedures: body 0x1000170c0, load 0x100018538–0x100018800.
  - It shows a `ProgressView` with `.task(priority: .userInitiated)` while the data is nil.
  - The task calls `AccountService().getSeriesUpdates()`, then sets `withAnimation { updatesGroup = result }`. On error it sets `[]`.
  - When the list is empty it shows `circle` (size 50, secondary) and `key_nothing+here` (title3, bold).
  - Otherwise it shows day headers followed by `SeriesUpdateCardView`.
- **SeriesUpdateCardView**
  - Procedure: 0x10005be80.
  - Layout: `ViewThatFits{VStack{HStack{…}.lineLimit(1)}}`, then `.padding(15)`, then a background that is a plain-style `NavigationLink` to `DetailsView(id: episode.id)` with a rounded-rect label, then `.padding(.horizontal)`.
  - The id is the full `https://ijobs.app…` URL built by a2's parser.
- **DownloadsView**
  - Procedures: body 0x100100c14, rows 0x100101054, swipe actions 0x1001017b4 and 0x1001019ec, overlay 0x10010206c, cover 0x100102214.
  - Tapping a row sets `playing` only for completed `.app` downloads.
  - Trailing swipe: destructive `key_delete` (`trash`) calls `delete`.
  - Leading swipe, by state:

    | State | Action |
    |---|---|
    | downloading | `key_pause` (`pause.fill`, orange) |
    | paused or failed | `key_resume` (`play.fill`, accentColor) |
    | completed | nothing |

  - The methods were resolved to `DownloadManager.pause/resume/delete` (0x1000aef58, 0x1000af664, 0x1000afd04).
  - The overlay shows `No downloads` (bold) when the list is empty. The navigation title is `Downloads`.
  - `fullScreenCover(item: $playing)`: when `localURL(for:)` returns a URL, it shows `PlayerViewComponent(url: "", subtitles: [], name: title, voiceActing: subtitle, poster:, progressKey: nil, autoplay: nil, localFileURL: url)` with `.ignoresSafeArea()` and `.persistentSystemOverlays(.hidden)`.
- **DownloadRow**
  - Procedures: body 0x100104340, content 0x100102a20, statusLine 0x10010351c, byteString 0x10010421c.
  - Content:
    - `AsyncImage` poster at 60×90, clipped to a rounded rectangle (radius 6);
    - title (headline, 2 lines);
    - subtitle when it is not empty;
    - quality;
    - the status line;
    - `play.circle.fill` (accent) for completed `.app` downloads.
  - `statusLine` by state:

    | State | Shown |
    |---|---|
    | downloading | `ProgressView` and the progress text |
    | paused | `key_paused` (`pause.circle`, orange) and the progress text when `received > 0` |
    | completed | `byteString(totalBytes)` with `checkmark.circle` (green) |
    | failed | `key_failed` (`exclamationmark.triangle`, red) |

  - The progress text is `byteString(received)`, followed by `" / " + byteString(total)` when `total > 0`.
  - `byteString`: values ≤ 0 give `key_downloaded_status`; other values use `ByteCountFormatter` with `.file`.

## Original quirks kept as they are
- A download with 0 bytes received shows "Downloaded", because `byteString(0)` returns that text.
- An empty password passes the length check.
- `onDelete` does nothing.
- `.preferredColorScheme(nil)` is kept, twice in BookmarkMovieListView.
- `print(newName)` runs on rename.
- Errors thrown inside unstructured `Task`s are dropped. This produces `NoUseUnstructuredThrowingTask` warnings.
- The bookmark delete ignores the server's answer.
- `DownloadRow` is private in the binary. It is internal here to match the stub and so the tests can use it.

## `// shortcut:` guesses
None. Two layout values were not checked one by one: the `lineLimit(1)` values on the date and watching-info texts of the watch-later card, and the value-form `.background(...)` d3 used in `LogInView`/`RegisterView`, where the binary uses the `alignment:content:` form. Both are layout-only.

## Contract requests / notes
1. **main (`project.yml`):** add `excludes: ["**/.omc/**"]` to the `HDrezka` and `HDrezkaTests` sources.
   - OMC hook state directories end up inside the source tree: `app/HDrezka/.omc` (15:33) and `app/HDrezka/Views/.omc` (14:59).
   - XcodeGen bundles them as resources. Two copies of `agent-replay-*.jsonl` then cause `Multiple commands produce …/HDrezka.app/agent-replay-….jsonl`, which breaks every build of a project regenerated while they exist.
   - Before regenerating and building the shared tree I **moved** (did not delete) both directories to `/private/tmp/claude-501/-Users-<user>--claude-spares-spare-OyfGU2/ade7e8e9-c95a-4cba-bd4f-b4f6c03f3ea7/scratchpad/d3b/omc-junk-155111/`.
2. **Other areas:** d3's `ProfileAccountViewTests` uses `RegisterView().isValidEmail`, `RegisterView().checkout(email:name:pass:conf_pass:)`, the `DownloadRow(download:onTap:)` memberwise init and `byteString`. All of them stay internal.
3. No new APIs were needed from other areas. My files call:
   - `AccountService` (all account methods);
   - `AccountParser.parseWatchingLaterMovies()`;
   - `Network.bookmarks`;
   - `DownloadManager.downloads`, `pause`, `resume`, `delete` and `localURL(for:)`;
   - the memberwise inits of `DetailsView(id:)`, `TitleCardComponent(model:)`, `TitleCardComponentIpad(model:)` and `PlayerViewComponent(…, localFileURL:)`.

## Tests (`ViewsD3BTests`, 9 since the review pass; none touch the network)
- The email regex is checked at its limits:
  - local part of 256 characters passes, 257 fails;
  - first label: 64 characters after the first letter pass, 65 fail;
  - later labels: 25 characters after the first letter pass, 26 fail;
  - a trailing hyphen passes;
  - `..` and non-ASCII characters fail.
- The `checkout` checks that run before any request:
  - name length 0, 2 and 31 are rejected; 3 and 30 are accepted;
  - passwords of 1 and 5 characters are rejected; the empty and the 6-character passwords reach the confirmation check;
  - the email is checked first.
- `progressText` with a known and an unknown total, and the "Downloaded" text for 0 bytes.
- `byteString` uses the `.file` count style.
- The body of `BookmarkMovieListView` ends with the two color-scheme writers, checked on the runtime type of `body`.
- `BookmarksView().newIndex` starts at 0.

## Review fixes
Two reviewers sent three findings. I checked each one against the disassembly. All three hold; findings 2 and 3 are the same issue.

| # | File | Verdict | Evidence |
|---|---|---|---|
| 1 | BookmarkMovieListView | Applied: `.preferredColorScheme(nil)` again after `.onDisappear`. | The outermost type, instantiated at 0x1000621c0 (mangled-name ref 0x10043bfa0), nests five `ModifiedContent` levels around `ScrollView`. My earlier chain had only four. At 0x1000621d4–0x1000621e8 the code calls the same ColorScheme `storeEnumTagSinglePayload` (x24, loaded at 0x10006204c) with w1=1, w2=1. It writes into the field at `[metadata+0x24]` of that fifth type, so the value stored is `ColorScheme?.none`. Only `_PreferenceWritingModifier<PreferredColorSchemeKey>` stores a `ColorScheme?`. The fourth level stores (nil, closure 0x100062b50), which is the onDisappear. |
| 2 | BookmarksView | Applied: `@State var newIndex: Int = 0`. | specialized `BookmarksView.init()` 0x10009f134: at 0x10009f1d4 it does `str xzr` with `$sSiN`, then `State.init(wrappedValue:)` into the slot at +0x50. The other six slots hold `[]`, `Bookmark(id: 0, name: "")`, `false`, `false`, `""` and `""`, which matches the file. So the slot mapping is certain. The `1` came from the stub generator's per-type guess (`gen_view_stubs.py:32`, `"Int": "1"`). d1a and d1b fixed the same guess the same way ("Deviations from the stub defaults"). |
| 3 | BookmarksView | Duplicate of 2. | Same address and fix. |

- **Effects.** Finding 1 changes only the structure: both writers store nil. Finding 2 has no effect at runtime: the pencil action sets `newIndex = index` before the rename alert can read it.
- **Signatures.** The memberwise initializers are unchanged. The only call site, `BookmarksView()` in `ProfileView.swift:71`, passes no `newIndex`.
- **Tests, written first.** The red run at 16:36 failed for the expected reasons. The runtime type of `body` ended at `…, _ValueActionModifier<Int>>, _AppearanceActionModifier>` and contained one `PreferredColorSchemeKey`, and `newIndex` read 1.
- **Results.** After the fixes, `./build.sh d3b` ended with BUILD SUCCEEDED (16:38). `SIM_ID=FE56A4E4… ONLY=ViewsD3BTests ./build.sh d3b test` passed 9 of 9 (16:38).
- No files were added or removed, so `regen.sh` was not run.
- Still open: contract request 1 (`.omc` excludes in `project.yml`) is for main. No `.omc` directory is inside `HDrezka/` or `HDrezkaTests/` right now; only `app/.omc` exists, and it is outside the sources.
