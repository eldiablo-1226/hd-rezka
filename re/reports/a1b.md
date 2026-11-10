# a1b: stream decoding and MovieDetailsService

Files: `app/HDrezka/Parsing/String+Video.swift`, `app/HDrezka/Networking/MovieDetailsService.swift`,
`app/HDrezkaTests/VideoServiceTests.swift` (11 tests, all pass), fixture `app/HDrezkaTests/Fixtures/video-film-205.json`.
`./build.sh a1b` succeeds. No `unimplemented()` or `// RECONSTRUCT` left, and no `// shortcut:` needed: everything below comes from the binary.

## Is the stream obfuscated? No
- `String.getMovieVideo()` (0x1000ba7c0 and its closures) does no base64 or `#h`/`//_//` decoding. It parses JSON, splits on `,` and `]`, and reads labels with SwiftSoup.
- Live check: one POST to `https://ijobs.app/ajax/get_cdn_series/?t=1794299956` with `action=get_movie&id=205&is_ads=0&is_camrip=0&is_director=0&translator_id=56`, the app User-Agent and the 3 app headers. It returned 200 `{"success":true,…,"url":"[360p]https://stream.voidboost.one/…/i3exf.mp4,[480p]….mp4,[720p]….mp4,[<span class=\"pjs-registered-quality\">1080p<img …></span>]null,[<span class=\"pjs-prem-quality\">1080p Ultra<img …></span>]https://….mp4","quality":"480p","subtitle":false,"subtitle_lns":false,"subtitle_def":false,…}`. The links come back as plain text.
- This one captured response has only mp4 links (no ` or `, no `:hls:manifest.m3u8`). I did not observe a `streams` value embedded in a page or a series `get_stream` answer. What the binary does show: `PlayerViewComponent.makeUIViewController` (0x10007e624) appends `":hls:manifest.m3u8"` to the chosen URL itself.
- Every detail page on ijobs.app answers 403 to a guest (listings answer 200), so no live page was saved. The id and translator (205/56) came from a1a's Wayback fixture `details-film-hunger-games.html`. I only read that file.

## How `String.getMovieVideo()` decodes
1. `JSONSerialization.jsonObject(with: data(using: .utf8)!, options: .fragmentsAllowed) as? [String: Any]`.
2. If that is not JSON (a details page), it takes the text from `range(of: "{\"id\":")!` (0x1000ba9ac, small string `0x3a226469227b`) through the `}` of the next `"});"`. This is closure 0x1000c5968: `0x3b297d`, `index(after:)`. It parses that text the same way and force-unwraps the result.
3. `streams = json["url"] as? String ?? json["streams"] as! String` ("url" at 0x1000baa74, "streams" at 0x1000baae0).
4. `streams.split(",")` (0x1000bab50). For each item (closure #2, 0x1000c5ccc):
   - remove every `[` (0x5b → ""), then trim whitespace;
   - split on `]`;
   - `label = try SwiftSoup.parse(parts[0]).text()` (vtable +0x4c0, `true`). This turns the premium/registered `<span>` labels into `1080p` / `1080p Ultra`;
   - `links[label] = parts[1]` (`setValue` at 0x1000c6008). The URL is kept exactly as sent, so the non-registered 1080p link is the literal string `"null"`.
   - If any SwiftSoup call throws: `print("error in getMovieVideo")` and return `MovieVideo(name: "", every quality "", subtitles: nil, position: 0)` (0x1000bad44–0x1000bad7c).
5. Subtitles (closure #3, 0x1000c6048) are read only when `json["subtitle"] as? String` and `json["subtitle_lns"] as? [String: Any]` both succeed. Each item of `subtitle.split(",")` gives:
   - `name = String(item.split("]")[0])` with `[` removed;
   - `link = item.split("]")[1]`;
   - `lang = subtitle_lns[name] as? String`. If there is no lang, the item is dropped.
   Otherwise subtitles is `[]`, not nil. `subtitle_def` is never read.
6. Quality mapping: `360p→_360p`, `480p→_480p`, `720p→_720p`, `1080p→_1080p`, `"1080p Ultra"→_1080pUltra`, `2K` (`0x4b32`) `→_1440p`, `4K` (`0x4b34`) `→_2160p`. `name` is always `""` and `position` always `0` (store at 0x1000bb020).
7. Index access is unchecked in the original (`parts[1]`, `range(of:)!`, `as! String`), so it crashes on input it does not expect. I kept that.

## Small helpers
- `getAvailableQualities()` (0x100074998) returns `Quality(name:url:)` for each non-nil field, in the order 360p, 480p, 720p, 1080p, "1080p Ultra", 2K, 4K. Names are the labels above.
- `preferred(name:)` (0x100074da8) is `first { $0.name == name } ?? last`.
- `isSuccess()` (0x1000bb2b8) is JSON (options 0) `["success"] as? Bool ?? false`. It is also false when the text is not JSON.
- `getMovieId()` (0x1000bb560) is `components("/").last?.components("-").first ?? ""`.
- `removeMirror()` (0x1000df130): if the string starts with `"http"`, it returns `split("/").dropFirst(2).joined("/")`, which has no leading slash. Otherwise it returns the string unchanged.
- `toShortNumber()` (0x1000df2d4): removes non-digits with regex `[\D\s]` (options 0x400), then `Int(...) ?? 0`:

  | Range | Output |
  |---|---|
  | 10M…100M | `"<n/1M>M"` |
  | 1M…10M | `"<n/1M>,<first digit of String(n % 1M)>M"` |
  | 10K…1M | `"<n/1000>K"` |
  | 1000…10K | `"<n/1000>,<first digit of String(n % 1000)>K"` |
  | anything else | `"<n>"` |

  This is an original bug, kept: `(1 043 261)` gives `1,4M`.

## Requests (all with headers `Content-Type: application/x-www-form-urlencoded; charset=UTF-8`, `X-Hdrezka-Ios-App: 1`, `X-Hdrezka-Ios-App-Version: <remoteVersion>`; `responseString`, resume returning/throwing as in 0x100027180)
- `getMovieVideo(params:)` sends a POST to `"https://" + mirror + "/ajax/get_cdn_series/?t=" + String(format: "%.0f", Date().timeIntervalSince1970)`, using `URLEncodedFormParameterEncoder.default`.
  - `t` is in whole seconds, not milliseconds: there is no fmul at 0x10002824c.
- `getMovieVideo(url:)` sends a GET to the URL exactly as given, with the same 3 headers (Content-Type included) and `URLEncoding.default`.
- `getMovieVideo(voiceActing:season:episode:id:)` (0x1000277fc):
  - If `episode?.url ?? voiceActing.url` is set, it GETs that page and calls `.getMovieVideo()`.
  - Otherwise it POSTs these fields and calls `.getMovieVideo()` on the answer:
    - `id` = `(voiceActing.id.isEmpty ? id : voiceActing.id).components("/").last?.components("-").first`; the field is left out when this is nil;
    - `translator_id` = `voiceActing.translatorId`;
    - `is_camrip`, `is_ads`, `is_director`, each only when not empty;
    - when both season and episode are set: `season` = season.id, `episode` = episode.id, `action=get_stream`; otherwise `action=get_movie`.
  - There is no `favs` field and no `t` field in the form. The builder is `MovieDetailsService.videoParams(...)`.
- `getSeriesSeasons(movieId:voiceActing:)` (0x100028d0c):
  - If `voiceActing.url` is set, it GETs that page.
  - Otherwise it POSTs `id` (same extraction applied to `movieId`), `translator_id` and `action=get_episodes`. The builder is `MovieDetailsService.seasonsParams(...)`.
  - Either way it returns `MovieDetailsParser().parseSeriesSeasons(response)` (0x10002901c / 0x1000291dc).
- The URL builder is `MovieDetailsService.cdnSeriesURL(mirror:date:)`.

## Notes for other areas
- UI/player: for a viewer without an account, `getAvailableQualities()` contains `Quality(name: "1080p", url: "null")`. Nothing in the binary filters the literal "null" (searched for `0x6c6c756e`).
- a1a: `getMovieVideo()` on a page force-unwraps `{"id":`. The archived pages, whose player JSON starts `{"url":false`, would crash it, just as they would crash the original.

## Contract requests
None. `MovieDetailsParser().parseSeriesSeasons(_:)` already has the signature that is needed.

## Review fixes
Two reviewers sent 5 findings. I checked each one against the disassembly and confirmed all of them. Findings 1 and 2 describe the same problem, so they share one fix.
- **Subtitle item order (findings 1 and 2), fixed in `String+Video.swift`.** Closure #3 (0x1000c6048) does its second `split("]")` at 0x1000c6180, then `cmp x8,#2; b.lo brk`, then `_fromSubstring(parts[1])` at 0x1000c61bc. Only after that does it check `subtitle_lns`: `cbz count` at 0x1000c61d8, `find(name)` at 0x1000c61ec and `as? String` at 0x1000c622c. The rebuild now reads `link = String(parts[1])` before the lookup, as the binary does. An item without `]` now traps even when its name is not in `subtitle_lns`. Before the fix the rebuild silently dropped that item. There is no test for the trap because XCTest cannot survive a `brk`. `testDecodesPlayerJsonInsidePageWithSubtitles` still covers the dropped-item path.
- **`toShortNumber` boundaries (finding 3), test only.** In the disassembly every range is closed at both ends: `n-10M <= 90M`, `n-1M <= 9M`, `n-10K <= 990K`, `n-1K <= 9K`, all unsigned `b.hi`, checked in that order. I added asserts for `(1 000)`→`1,0K`, `(10 000)`→`10K`, `(1 000 000)`→`1,0M`, `(10 000 000)`→`10M`, `(100 000 000)`→`100M` and `(100 000 001)`→`100000001`. All of them pass and the code did not change.
- **Synthetic details page (finding 4), comment only.** Neither `details-film-hunger-games.html` nor `details-series-hawaii.html` contains `{"id":`. Both carry `initCDN*Events(..., {"url":false,...})`, so the force-unwrapped `range(of: "{\"id\":")` crashes both builds on them. The doc comment of the page test now says that the page is built from the parser's keys (`{"id":`, `streams` and `});` are small strings at 0x1000ba9ac, 0x1000baae0 and 0x1000c5a28) and is not a capture.
- **GET-vs-POST routing (finding 5), test seam.** At 0x10002781c-0x10002783c the binary takes `episode.url` when the episode is set and has a url (`ccmp x23,#0,#4,ne`). Otherwise it takes `voiceActing.url` (`[x8,#0x70]`). Only when both are nil does it build the POST. `getSeriesSeasons` (0x100028d2c-0x100028d34) checks only `voiceActing.url`. The new `MovieDetailsService.pageURL(voiceActing:episode:)` is exactly `episode?.url ?? voiceActing.url` and is used by `getMovieVideo(voiceActing:season:episode:id:)`. `getSeriesSeasons` is unchanged. `testPageUrlPrefersEpisodeLinkOverTranslatorLink` covers four cases: the episode link wins, a nil `episode.url` falls back to the translator link, a nil episode does the same, and with no link on either side the result is nil, which means POST.

Results: `ONLY=VideoServiceTests ./build.sh a1b test` ran 12 tests with 0 failures, and `./build.sh a1b` reported BUILD SUCCEEDED.
Still open: the page path of `getMovieVideo()` has not been checked against a real page. That needs a live details page fetched through a VPN or on a device.
