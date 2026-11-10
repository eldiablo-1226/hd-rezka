# a1a: MovieDetailsParser (HTML → models for the movie/series page)

## Files
- `app/HDrezka/Parsing/MovieDetailsParser.swift`: everything that came from the original file (class, `Document`/`Element`/`[Element]` extensions). No `unimplemented()` or `// RECONSTRUCT` left.
- `app/HDrezkaTests/MovieDetailsParserTests.swift`: new, 21 tests after the review (18 originally) (all passing: `SIM_ID=… ONLY=MovieDetailsParserTests ./build.sh a1a test`; `./build.sh a1a` succeeds).
- `app/HDrezkaTests/Fixtures/details-film-hunger-games.html`: film 205, with a franchise block and a translators list.
- `app/HDrezkaTests/Fixtures/details-series-hawaii.html`: series 1605, with 10 seasons, episodes, 6 voice actings, the schedule and the voice-acting rating.

Both fixtures are real hdrezka.ag pages from 2025, taken from the Wayback Machine (`/web/<ts>id_/…`). ijobs.app answers 403 with an empty body for every detail page when there is no session, even with the app User-Agent and headers; listings and search still answer 200. The archive crawler is region-blocked, so both pages carry `div.b-player__restricted`. One test removes that class in memory so the "available" branch also gets coverage.

**Main risk:** everything in `parseMovieDetails` depends on the SwiftSoup 2.6.x pin. With 2.7+, `getMovieLists`' `Int(position)!` traps on every page that has a "Входит в списки" row. With 2.8+, every rating comes out nil (see Surprises 1).

## Functions
All of these were read from the disassembly. To name the SwiftSoup vtable calls (`(*(*rX + 0xNNN))`) I built an offset → method map for `Element`/`Elements`/`Document` from `nm.txt` and `fixups.txt`: `/private/tmp/claude-501/-Users-<user>--claude-spares-spare-OyfGU2/ade7e8e9-c95a-4cba-bd4f-b4f6c03f3ea7/scratchpad/a1a/vtables.tsv` (made by `vtable.py`; `cond.py <lo> <hi>` there prints an annotated disassembly range). Examples: `Element` +0x370 `select`, +0x410 `getElementsByTag`, +0x420 `getElementsByClass`, +0x4c0 `text`, +0x110 `attr`; `Elements` +0x188 `first()`, +0x190 `isEmpty()`, +0x160 `select`, +0xe0 `text`.
"Exact" means the same calls in the same order, with the same literals, defaults and force-unwraps.

| Function | Procedure(s) | Confidence |
|---|---|---|
| `parseMovieDetails(html:movieId:)` | 0x1000bb69c, closure inlined in 0x1000bfa6c | exact |
| `parseSeriesSeasons(_:)` | 0x1000c15d0 | exact |
| `parseTrailerId(response:)` | 0x1000c6ec0 | exact |
| `Document.checkPremium()` | 0x1000e1c6c | exact: writes `body()!.select(".b-tophead-premuser").select("b").text()` into `@AppStorage("hasPremium")` (default "", standard defaults), which is "" for guests, and returns `self` |
| `isAvailable` / `isComingSoon` | 0x1000bc82c / 0x1000bc918 | exact |
| `getSeasons` | 0x1000bca10, 0x1000c2854 | exact |
| `getVoiceActing(movieId:)` + `getByOffset` | 0x1000bd280, 0x1000c2edc, 0x1000c33f8 | exact, except one redundant second `item.text()` in the no-flag branch, which I dropped (same result) |
| `getSchedule` | 0x1000bd590, 0x1000c36c0, 0x1000c3a50 | exact |
| `getFranchise` | 0x1000bd7d4, 0x1000c3d90 | exact |
| `getVoiceActingRating` | 0x1000bd9fc, 0x1000c445c, 0x1000c4764 | exact |
| `getCommentsCount` | 0x1000bdc20 | exact (`?? 0`) |
| `getBookmarks` | 0x1000c1494, 0x1000c49cc | exact |
| `Element.getDetailsPoster/HPoster/Description` | 0x1000bc490 / 0x1000bc600 / 0x1000bc714 | exact |
| `Element.getMovieLists` | 0x1000bf5b0, 0x1000c4ebc | exact |
| `Element.getDetailsChunked(onGot:)` | 0x1000bfa6c | exact: `@escaping`, takes the tds of every `tr` two at a time |
| `[Element].getImdbRating/Votes/Link`, `getKpRating/Votes/Link` | 0x1000bdfcc, 0x1000be2c0, 0x1000be4d4, 0x1000be9ac, 0x1000bec3c, 0x1000bee50 | exact after the review fix (the first version of `getKpRating` was not; see "Review fixes"). Only `getImdbLink`, `getKpRating`, `getKpLink` throw; the others print and return nil. `getKpRating` parses `?? "0"` when the span or `.bold` is missing, while `getImdbRating` returns nil there. Links: `/help/<base64>/` → trailing "/" removed → base64 → UTF-8 → `removingPercentEncoding` |
| `[Element].getProducers` (throws) / `getActors` (no throw) | 0x1000bf328 / 0x1000bf7a8 | exact |

Defaults in `parseMovieDetails`: `id: ""`, `duration ?? "nil"`, `country ?? "nil"`, `ageRestriction ?? "0+"`, `genres!`, `video: nil`, `ytTrailerLink`/`ytTrailerPreview: nil`. Seasons and voice actings are read only when the page is available and not "coming soon". The voice-acting rating is skipped for "coming soon" pages. The result is appended to `movieDetailed` (never cleared) and the whole array is returned. `parseSeriesSeasons` returns `try? parse(html).getSeasons()` when that is non-nil. Otherwise it reads the get_episodes JSON (`seasons`/`episodes` HTML), appends each season to `movieSeason` and returns it. On a JSON error it prints "error in parseSeriesSeasons" and returns nil.

## `// shortcut:` guesses
None. Nothing here was guessed.

## Contract requests
None. I call a1b's `String.toShortNumber()` for vote counts, as the binary does. `parseMovieDetails` never calls `getMovieVideo()` (`video` is always nil), so the archived pages cannot crash it.

## Surprises (site HTML and library versus the selectors)
1. **SwiftSoup version.** The original embeds SwiftSoup ≤ 2.6.x (now pinned to 2.6.1 by the coordinator). With 2.7.x, `outerHtml()` prints `<br />`, so `getMovieLists`' split on `"<br>"` finds nothing and the original `Int(position)!` traps. With 2.8+ (2.14), `getElementsByClass("b-post__info_rates imdb")` no longer matches a whole multi-word class attribute, so every rating comes out nil.
2. **The regex is a no-op in `getSeasons`.** The binary passes `"[^\\d!-/:-@\\[-`{-~]+"` to `replacingOccurrences` with no options, so names stay "Сезон 1"/"Серия 1". Only `parseSeriesSeasons` passes `.regularExpression`, which turns "Сезон 1" into "1".
3. **`getVoiceActingRating` returns one entry, not one per translator.** It maps the whole `div.inner` list in one call (`Optional.map` on `Elements`). The name is all the titles joined, plus 🇺🇦/🇰🇿 for the first flag. The percent is `Float("98.49 0.57 …") ?? 0`, which is 0 whenever there is more than one row. This is reproduced and pinned by a test.
4. **The schedule keeps its "загрузить еще серии" row** as an item with empty fields (10th-season block: 23 items).
5. **Film pages also have `ul#translators-list`.** The `getByOffset` fallback (second argument of `initCDN…Events(…)`, `isSelected: true`, other fields "") only runs when that list is missing.
6. **Collections are keyed by the link with `collections/` and the last character removed**, e.g. `https://hdrezka.ag/317-ekranizacii-literaturnyh-proizvedeniy` → "Экранизации литературных произведений". Bookmark names keep the space before "(": "Избранное ".
7. **Some markup is never served to guests.** The bookmarks (`div#user-favorites-list` only holds `{favorites_list}`) and the premium badge are account-only, so their tests use minimal HTML derived from the selectors. The trailer response is a synthesized gettrailervideo.php JSON (I sent no POST).
8. **SwiftUI also declares a type named `Document`** (iOS 26 SDK), so a file that imports both SwiftUI and SwiftSoup must write `SwiftSoup.Document`.

## Review fixes
Two reviewers sent four findings. I checked each one against the disassembly before changing anything. All four hold and none was rejected. The test file now has 21 tests and all of them pass (`SIM_ID=3FFAA255-… ONLY=MovieDetailsParserTests ./build.sh a1a test`). `./build.sh a1a` succeeds.

1. **`[Element].getKpRating()` fell back to nil. The binary falls back to the string "0" (fixed).** At 0x1000be9ac the two `first()` nil checks (`cbz x20` at 0x1000bea54 and `cbz x22` at 0x1000beaa4) jump to 0x1000beae0. That block builds the small string "0" (`x0 = 0xe100000000000000`, `w20 = 0x30`), then joins the normal `strtof` parse, and the `csel` at 0x1000bebb8 returns `.some(0.0)`. `getImdbRating` really does return nil on the same paths (0x1000be120 builds `0x100000000` = `Float?.none`), so it stays unchanged. The function is now `Float(try self[1].getElementsByClass("b-post__info_rates kp").first()?.getElementsByClass("bold").first()?.text() ?? "0")`, and it still throws. In `parseMovieDetails` the MovieRating is still built only when value, votes and link are all non-nil (0x1000bbe58–0x1000bbed0). So a KP span that has `<a>` and `<i>` but no `.bold` now gives `kpRating` value 0 with its votes and link, as in the original. My first version of this report called the function "exact", and that was wrong. Test: `testKpRatingFallsBackToZero` (chunk-level, imdb/kp asymmetry, and the film fixture with the KP `.bold` removed). It failed before the fix and passes after it.
2. **The single-season branch of `getSeasons()` had no coverage (test added, code unchanged).** The code matches the binary. The id comes from `ul[id*="simple-episodes-list"]` (0x1000bcc54), and the three `first()!` checks trap at 0x1000bd274, 0x1000bd278 and 0x1000bd27c. The name is "Сезон " (0x1000bd184) + id, passed through `replacingOccurrences` with options 0 (0x1000bd204). The season gets `isSelected` 1 and url nil (0x1000bd258/25c). Test: `testSingleSeasonPageWithoutTabs`. It also checks an episode `href` (0x1000bd014/0x1000bd030). The `[id*=…]` selector works under the 2.6.1 pin.
3. **Nothing tested `isPremium` true or a non-nil `url` (test added, code unchanged).** The code matches the binary: `hasClass("b-prem_translator")` is vtable +0x508 at 0x1000c331c. `hasAttr("href") ? attr("href") : nil` is +0x128 then +0x110, at 0x1000c3338/0x1000c3354 (translators), 0x1000c2e54/0x1000c2e74 (season tabs) and 0x1000bd014/0x1000bd030 (single-season episodes). Note that `cond.py` labels 0x1000c2e74 as hasAttr, but the raw code is `ldr x8,[sp,#0x58]; blr x8` (attr) with a `mov x0,#0; mov x1,#0` nil arm. Test: `testPremiumVoiceActingAndItemLinks`, which covers a premium translator with an href and a season tab and episode that both have an href. This markup is minimal HTML derived from the selectors, because neither fixture carries it.
4. **The vote-count assertions were tautological (fixed in the tests).** They compared the parser's output with `"(…)".toShortNumber()`. They now compare with literals: "1,4M" (imdb, film), "503K" (kp, film), "9,7K" (kp, series). "1,4M" is the binary's quirk: `toShortNumber` at 0x1000df2d4 computes `msub` with 1 000 000 and then takes `Collection.first` of the remainder. a1b's `testToShortNumber` pins the same values.
