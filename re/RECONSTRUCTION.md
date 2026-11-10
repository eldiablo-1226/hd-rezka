# Reconstruction guide (HDRezka.ipa → app/)

Goal: rebuild the source of `me.keet.HDRezka` 1.6.0 (570) from the shipped binary so that the
rebuilt app behaves like the original. Firebase is removed on purpose; everything else stays.
Improvements come later. Fidelity first: copy the original logic, strings, selectors,
request parameters and defaults; do not "fix" or redesign anything in this pass.

## Where the evidence is
| What | Where |
|---|---|
| Every type with stored properties (exact order, names, types) and conformances | `re/swift-interface.txt` |
| Full method signatures (incl. `async throws`, return types) | `re/api-signatures.txt` |
| Pseudocode of all 1826 app procedures (Hopper) | `re/decompiled/<addr>_<name>.c`, index in `re/decompiled/INDEX.tsv` (addr, size, demangled name) |
| Readable digest of a procedure (decodes Swift small strings like `0x2f2f3a7370747468/*"https://"*/`, strips ARC noise) | `python3 -I re/tools/digest.py re/decompiled/<file>.c` |
| @AppStorage keys and defaults per construction site | `re/appstorage-keys.tsv` (already applied to stubs) |
| App strings (selectors, URLs, keys) | `re/app-strings.txt`; localizations in `app/HDrezka/Resources/*.lproj` |
| Overview, endpoints, open questions | `re/RE-NOTES.md` |
| Full disassembly with symbols (when pseudocode loses an argument) | `otool -tV app-binary` → already at `/private/tmp/claude-501/-Users-<user>--claude-spares-spare-OyfGU2/ade7e8e9-c95a-4cba-bd4f-b4f6c03f3ea7/scratchpad/disasm.txt` |

Reading pseudocode:
- Async Swift functions are split into several procedures with the same demangled name (resume
  partials). Read all of them, plus `closure #N in <name>` entries — the network/parse logic usually
  sits in the closures (Alamofire completion handlers, `withCheckedThrowingContinuation`).
- Large literal strings show as `"text" - 0x20 | 0x8000000000000000` with a count word `0xd0000000000000NN`.
  Small strings (≤15 bytes) are immediates; `digest.py` decodes them.
- Calls through `(*(*rX + 0x…))(…)` are class-method vtable calls (often SwiftSoup `select`, `attr`, `text`).
- Generic SwiftUI/AppStorage initializers lose their arguments in pseudocode; use the disassembly
  (`grep -n '<symbol>' disasm.txt`, look at the `mov/movk` immediates before the `bl`).
- Huge "specialized" procedures (e.g. `Element.getDetailsChunked` 3.5 MB) are mostly inlined generic
  noise; grep them for string literals and SwiftSoup calls instead of reading linearly.

## Contract rules (the project must keep compiling for everyone)
1. `app/` already builds. Every type exists as a stub with the binary's exact stored properties.
   Stubs call `unimplemented()` or show `Text(verbatim: "<Type>")  // RECONSTRUCT`.
2. Edit only the files of your area. Do not change stored properties, their order, names, types,
   or any signature of types owned by another area. You may add private helpers, computed
   properties, extensions and nested types inside your own files.
3. If you need a missing method on another area's type, do not add it there. Record it in your final
   report under "Contract requests" (exact signature + call site). Use a local workaround only if it
   mirrors what the original did inline.
4. New source files are allowed inside your area's folders only. After adding/removing files run
   `app/regen.sh` (serialized xcodegen). Never edit `HDrezka.xcodeproj` by hand.
5. Views: keep stored properties non-private so memberwise initializers keep working across files.
   Keep `@State`/`@AppStorage`/`@Environment*` defaults as in the stub.
6. No Firebase, no analytics, no new third-party dependencies. Available packages: Alamofire,
   SwiftSoup, Nuke + NukeUI, YouTubePlayerKit (1.x), AlertKit (5.x), Flow (SwiftUI-Flow).
7. When the binary leaves something unknown, choose the most plausible behavior, mark it in code with
   `// shortcut: <what is guessed>, <how to verify>` and list it in your report.
8. Done = no `unimplemented()` and no `// RECONSTRUCT` left in your files, your tests pass, and
   `./build.sh <tag>` succeeds (errors in other areas' files mean a concurrent edit; rebuild later
   rather than touching their files).

## Building and testing
- Always run `./build.sh` with the Bash tool's `timeout: 900000` (a build takes 20 s–3 min, a test run
  boots a simulator). A Bash timeout is not a failed build: rerun, do not "fix" code because of it.
- REA/Hopper is one shared session: `procedure_assembly`, `read_bytes`, `search_strings`, `xrefs` are
  fine; never call `open_binary` or `close_binary`. The decompiled files are canonical.
- Build: `cd app && ./build.sh <tag>` (own DerivedData `../.build/dd-<tag>`, shared SPM checkout).
- Tests: `cd app && SIM_ID=<your simulator UDID> ONLY=<YourTestClass> ./build.sh <tag> test`.
- TDD for logic: write a failing XCTest first (parsers, decoders, playlist builders, URL/param
  builders, file naming), then the code. Pure SwiftUI layout is verified by building.
- Parser fixtures: put HTML in `app/HDrezkaTests/Fixtures/` and load it via
  `URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/x.html")`
  (the simulator reads the host file system; no project regeneration needed for fixtures).
- Live site (read-only GETs are fine; never log in, never POST to account endpoints):
  `curl -s --compressed -A 'HDrezka/1.6.0 (me.keet.HDRezka; build:570; iOS 26.4.0) Alamofire/5.10.2' -H 'X-Hdrezka-Ios-App: 1' -H 'X-Hdrezka-Ios-App-Version: 2.2.5' https://ijobs.app/<path>`
  Without that User-Agent the mirror answers 403.
  Account pages (bookmarks, watch later, series updates) need a session: write tests against minimal
  HTML that you derive from the selectors in the decompiled parser, and say so in the report.

## Toolchain pitfalls
- SwiftSoup is pinned to 2.6.x (the family embedded in the binary: String-based `hasClass` matching whole
  multi-word class attributes, void tags serialized as `<br>`). Do not upgrade it during reconstruction.
- The iOS 26 SDK's SwiftUI also declares `Document`: in files importing both SwiftUI and SwiftSoup write
  `SwiftSoup.Document` / `SwiftSoup.Element` explicitly.

## Known facts (verified)
- Mirror/base URL: `"https://" + settingStore + path`; `settingStore` is `@AppStorage("mirror")`,
  default `DefaultSettings.mirror = "ijobs.app"`.
- Every site request sends headers `X-Hdrezka-Ios-App: 1` and `X-Hdrezka-Ios-App-Version: <remoteVersion>`;
  POSTs also send `Content-Type: application/x-www-form-urlencoded; charset=UTF-8` with
  `URLEncodedFormParameterEncoder.default`, responses read via `responseString`.
- `HeaderUpdater.updateHeader()` GETs `https://api.hdrezka.tech/get.hdrezka_android_app_updates`
  (JSON `{"version":"2.2.5",...}`) and returns `version` (stored into `remoteVersion`).
- Login: POST `https://<mirror>/ajax/login/`.
- `?t=` in `/ajax/get_cdn_series/?t=` is `String(format: "%.0f", Date().timeIntervalSince1970)` (seconds). GETs send the
  same `Content-Type` header as POSTs. Stream links come back unobfuscated (`[360p]https://…mp4,[480p]…`); quality
  labels may be HTML (`<span class="pjs-prem-quality">1080p Ultra…</span>`) and guest 1080p links are the literal `null`.
- Playback progress key (CoverData.progressKey / PlayerViewComponent.progressKey) for series is
  `movieId|translatorId|seasonId|episodeId`; autoplay builds the next key the same way (agent b, re/reports/b.md).
  Downloads start via `DownloadManager.shared.download(title:subtitle:poster:quality:url:destination:)`
  with the `downloadDestination` setting; metadata lives in `Application Support/Downloads/downloads.json`.
- `AccountParser` is `@MainActor` (class-level) and `CollectionsParser.getWatchingNowMoviesInCollection` is
  `@MainActor`, as in the binary; call them from the main actor (views) or `await` them.
- View areas (second run): d1a App/{HDRezkaApp,SharedFilmId} + Views/{Common,Shell,Home}; d1b Views/{Search,Collections};
  d2a details core (DetailsView*, InfoSheet/InfoTab, BookmarksSelection, Stars, FranchiseRow, SeasonRow, YouTube, TextFirstLabel,
  WipeTransition); d2b VideoParams/QualitySelection/DownloadParams sheets, PremiumUnavailable, Views/Person; d3a Views/{Profile,Settings};
  d3b Views/{Account,Downloads}. Views/Common/{ForEachWithIndex,Extensions}.swift are owned by d1a.
- Shared view helpers owned by the details area (d2a): `TextFirstLabel` (Views/Details/TextFirstLabel.swift),
  `AnyTransition.wipe(angle:blurRadius:)` + private `Wipe` + `CGSize.boundingSize(at:)`
  (Views/Details/WipeTransition.swift; `wipe` itself is one symmetric `.modifier`; every LazyImage call site in the binary
  uses `.transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))`),
  and a fileprivate `UIColor.blended(with:weight:)` in FranchiseRowView. Nobody else declares them.
- Reserved module-level names (defined in Networking/Network.swift): `siteHeaders(version:contentType:)`,
  `siteRequest(_:_:_:headers:)`, `siteString(_:)`. Do not declare other free functions with these names.
- The mirror requires the `X-Hdrezka-Ios-App` header (403 without it) and blocks the `curl/…` User-Agent;
  Alamofire's default User-Agent passes.
- A guest `curl` gets 403 on movie/person detail pages of ijobs.app (listings are 200). Use web.archive.org copies as
  fixtures and keep the request code exactly as the binary has it; the cause is checked at integration time.
  Checked 2026-11-10: film and series pages are closed to guests from this network; once logged in, the same request
  gets 200 (person pages are 200 for guests too).
- Firebase: `AppDelegate` used to call `FIRApp.configure()`; removed.
