# d3a: profile and settings views

## Files
- `app/HDrezka/Views/Profile/ProfileView.swift`, `AccountCardViewComponent.swift`, `PremiumCard.swift` (PremiumCard, PremiumStarIcon, private Sparkle, PremiumStatus)
- `app/HDrezka/Views/Settings/SettingsView.swift`, `AppearanceSettingsView.swift` (+ private InfoTabDemoView), `BehaviorSettingsView.swift`, `PlayerSettingsView.swift`, `DebugSettingsView.swift`, `AboutUsView.swift`
- new `app/HDrezkaTests/ViewsD3ATests.swift`: 9 tests (PremiumStatus parsing, plural keys, Christmas window, version line, `init(allowDebug:)`)

No `unimplemented()` or `// RECONSTRUCT` is left. `ONLY=ViewsD3ATests ./build.sh d3a test` passes in the private copy and in a copy of the current shared tree. That copy also compiles every test file, `ProfileAccountViewTests` included, and that class passes. `./build.sh d3a` succeeds in the shared tree after `regen.sh`.

How the structure was recovered: closure symbols were demangled into their view types. The opaque `<<…>>` parameters were rendered with a small tree printer, `scratchpad/d3a/vt.py`. Call sites were read with an immediate tracker (`d3a/imm.py`, `d3a/allfacts.py` → `d3a/facts/<Type>.txt`), and the details came from the disassembly. Every body witness was checked for `NavigationStack(root:)`.

## Per type
- **ProfileView** (closure #1 0x1000f7c78, content 0x1000f7f10, logged out 0x1000f8cd8, toolbar 0x1000f9d58/0x1000f9f04, logout 0x1000fabe0 + task 0x1000facf4…0x1000faf44)
  - Layout: `NavigationStack { VStack { if !isLoggedIn {…} else {…} }.padding() }`.
  - Logged out:
    - `key_not_logged_in` (title, bold, padding 5);
    - `key_login_description` (centered);
    - link to `LogInView(accountService: AccountService())` with the label `Label("login", "door.left.hand.open")`. The label uses TextFirstLabel and the accent color, padding 10, and a quaternary rounded rectangle (radius 8) behind it;
    - `Text("Or")`;
    - link to `RegisterView()` with `Label("key_register", "chevron.right")`, label style TextFirstLabel.
  - Logged in:
    - `if let PremiumStatus(raw: hasPremium)` shows `PremiumCard`;
    - three `AccountCardViewComponent` links, each `.buttonStyle(.plain)` with bottom padding 10:
      - `WatchLaterView().environmentObject(AccountParser())`, image `clock`;
      - `BookmarksView().environmentObject(AccountParser())`, image `bookmark`;
      - `SeriesUpdateView()`, image `stopwatch`;
    - then a Spacer.
  - Toolbar: one `ToolbarItemGroup(.topBarTrailing)`. The binary's iOS 17 check is the `@backDeployed` thunk of `topBarTrailing`. It holds:
    - when logged in, a logout button (`rectangle.portrait.and.arrow.right`, toggles `isPresented`) with `.alert("key_logout_description")`. The alert has `key_no` (cancel) and `key_yes` (destructive), which runs `Task { try await AccountNetwork().logout() }` (MainActor, result ignored) and then `isLoggedIn = false`;
    - links to `DownloadsView()` (`arrow.down.circle`) and `SettingsView(…14 AppStorage bindings…)` (`gear`).
  - `.navigationDestination(isPresented: $isPresentedDetail) { DetailsView(id: id) }`.
  - Cookies: the binary does nothing. Its only `HTTPCookieStorage`/`cookiesForURL:` use is inside Alamofire's `cURLDescription`, so the session ends with the site's answer to `GET /logout`.
  - All NavigationLinks use `init(destination:label:)`, with the destination passed by value as in the binary.
- **AccountCardViewComponent** (0x1000b985c…, witness 0x1000b9f50)
  - `NavigationStack { ViewThatFits { VStack { HStack { VStack(.leading) { Label { Text(name).bold() } icon: { Image(systemName: image).accent }.padding(.bottom, 2); Text(desc) }; Spacer() } }.padding(15).background { RoundedRectangle(15, .continuous).quinary } } }`.
  - The binary really does wrap the card in its own NavigationStack.
- **PremiumCard** (0x1000fb7e4, 0x1000fbc48, 0x1000fc2b4)
  - `HStack(spacing: 14)` holding:
    - `PremiumStarIcon()` at 44×44;
    - `VStack(.leading, 2)` with `key_premium` (bold) and `key_premium_active` when `daysLeft == nil`, otherwise `key_premium_days_left` (subheadline, secondary);
    - Spacer;
    - the days text, `system(15, .semibold)`, orange when `daysLeft <= 3`, otherwise `Color(red: 0.95, green: 0.62, blue: 0.11)`.
  - Then padding 15 and a quinary rounded rectangle (radius 15).
- **PremiumStarIcon / Sparkle** (0x1000fc4c8, init 0x1000fdaa0, 0x1000fcb68/0x1000fceec)
  - Gradient: `[0.38,0.52,0.96]`, `[0.6,0.38,0.93]`, `[0.91,0.47,0.78]`, topLeading → bottomTrailing.
  - ZStack layers:
    - `Circle().fill(gradient.opacity(0.16))` (Float 0x3e23d70a);
    - `star.fill`, `system(20, .semibold)`;
    - three Sparkles (size, x, y, duration, delay): (6, 13, −11, 1.3, 0), (4, −14, −6, 1.7, 0.5), (3.5, 11, 12, 1.1, 0.9).
  - Each Sparkle is `sparkle` with `system(size, .semibold)`, the gradient, `opacity(on ? 0.95 : 0.25)` and `offset(x, y)`. In `.onAppear` it runs `withAnimation(.easeInOut(duration).repeatForever(autoreverses: true).delay(delay)) { on = true }`.
- **PremiumStatus** (init 0x1000fcfcc, dayWord 0x1000fd940)
  - init: trims whitespace and newlines and returns nil when the result is empty. `daysLeft = Int(all digits joined)`, `rawText = trimmed`.
  - dayWord: mod100 in 11…14 → `key_days_many`; mod10 == 1 → `_one`; mod10 in 2…4 → `_few`; anything else → `_many`. It uses `String(localized:)` with the current locale.
- **SettingsView** (0x100057b94…0x100058db0)
  - `NavigationStack { VStack { Form { Section { … } }; Spacer() }.ignoresSafeArea(.all, edges: .bottom) }`. There is no title.
  - The section holds, in order:
    - links: Appearance (`paintbrush.pointed`), Player (`rectangle.inset.filled.and.person.filled`), Behavior (`slider.horizontal.3`), `AboutUsView(allowDebug:)` (`about_app_settings`, `heart`);
    - `if allowDebug`: link to `DebugSettingsView(mirror: $settingStore, allowDebug:)`, labelled with the plain String "Debug" and `gear.badge.xmark`;
    - a Button that runs `openURL(URL(string: "https://t.me/apphdrios")!)` (force unwrap as in the binary), labelled `key_telegram+channel` with `paperplane`.
- **AppearanceSettingsView** (0x100105ee4…)
  - Section 1: `Toggle key_show+votes+count` and `InfoTabDemoView`.
  - Section 2: `Section(footer: key_prefer_original_title_footer) { Toggle key_prefer_original_title }`.
  - Title `key_appearance`, inside a NavigationStack.
  - **InfoTabDemoView** (0x1001067cc…):
    - layout: `HStack { Group { Spacer; IMDb column }; Spacer; Group { КиноПоиск column }; Spacer }.animation(.default)`, the deprecated form, as in the binary;
    - each column is `VStack(spacing: 2)`: label (caption2, primary), then `String(format: "%.1f"/"%.2f", 9.1/2.8)` in `system(.title2, design: .rounded)` medium, then `Text(verbatim: "(214K)"/"(840K)")` only when `showVotesCount`, then `StarsView(rating: 9.1/2.8)`.
- **PlayerSettingsView** (0x1000e5adc…)
  - Section with the header `Label(key_safe_area_header, iphone)` and footer `key_safe_area_footer`: `Toggle key_toggle+safe+areas`, then `HStack { Spacer; HideNotchAnimatedViewComponent(isAnimated: $hideNotch).padding(); Spacer }`.
  - Footer sections:
    - autoplay, `key_autoplay_next+description`;
    - `Picker key_preferred_quality` over `PlayerQualityPreference.allCases` (`displayName`), footer `key_preferred_quality+description`;
    - Infuse, `key_use_unfuse` / `key_unfise_description` (keys exactly as spelled in the binary).
  - Title `key_player`.
- **BehaviorSettingsView** (0x1000e3658…). Four sections, each with a header Label and a footer:
  1. Header `key_downloads_settings_footer` (this key reads "Downloads"), `square.and.arrow.down`. It holds `Picker key_download_destination` over `DownloadDestination.allCases` and `Toggle key_background_url_session`, both `.disabled(downloadManager.hasActiveDownloads)`. Footer `key_background_url_session+description`.
  2. Header `key_share_menu_header`, `square.and.arrow.up`. `Picker key_shareMenuVariation`:
     - `if #available(iOS 16.1, *)`: `key_shareMenuVariation+selectOption` → `.selectOption` (the check is `__isPlatformVersionAtLeast(2,16,1,0)`);
     - `key_share+with+url` → `.url`;
     - `key_share+with+universal+link` → `.universalLink`.
  3. Header `key_startup_page`, `square.grid.2x2`. Picker: "Now watching", `key_last_releases`, `key_popular`, `key_comingsoon`. Footer `key_startup_page_footer`.
  4. Header `key_section.history`, `clock`. `Toggle key_save_history`. Footer `key_section.history.footer`.
  - Title `key_behavior`.
- **DebugSettingsView** (0x10000e800…0x10000f824). All texts are plain Strings (StringProtocol initializers).
  - Section: header `Label("mirror", network)`, footer "don't forget to restart the app afterwards!".
  - It contains `HStack { TextField(title, text: $text) …; Button(arrow.clockwise) }`:
    - the TextField has `.onSubmit { mirror = text; title = text; text = "" }`, `.disableAutocorrection(true)` and `.textInputAutocapitalization(.never)`;
    - the button sets `mirror = "ijobs.app"` (literal), `title = "default"`, `text = ""`.
  - `.onAppear` on the Section: `title = mirror == "ijobs.app" ? "default" : mirror`.
  - `Button("Revoke access")`: `allowDebug = false` and `AlertKitAPI.present(title: "Access revoked", icon: .done, style: .iOS17AppleMusic, haptic: .success)`. The registers decode as icon 0 = `.done`, style 1, haptic 0.
  - Title "Debug".
- **AboutUsView** (witness 0x1000ea66c, content 0x1000e703c, init 0x1000ea778, isXmas 0x1000ead04)
  - Layout: `VStack { VStack { ScrollView(.vertical, showsIndicators: false) { … } } }`. The ScrollView holds, in order:
    - Thanks block, `.padding()`: `Label { "Thank you!" } icon: { isXmas() ? snowflake : heart, red }` in `system(34, .bold)` with `.padding(.bottom)`, then `thanks_special_info` in `system(16)`, centered.
    - `Divider().padding(.horizontal)`.
    - Developer cards. `key_information` uses frame(maxWidth: .infinity, .leading) and `system(22, .bold)` with `.padding()`. Each `PersonCardComponent` has url / job "Code" / name / role:
      - `https://i.imgur.com/kJChmNQ.jpeg`, `Keet`, "Ведущий разработчик". Tapping it 5 times sets `allowDebug = true` and shows `AlertKitAPI.present(title: ":з", style: .iOS17AppleMusic)`;
      - `https://i.imgur.com/YyKUZSZ.jpeg`, `voidboost`, "Помощь в разработке";
      - `https://i.imgur.com/XrNIAEe.jpeg`, `4nk1r`, "Android dev".
    - Notes block, shown when major is 16…17 and minor ≤ 4. It is `VStack(.leading).padding()` with `key_problems` (title, bold, `.padding(.bottom)`) and:
      - on iOS 16: a row (`gear`, `SystemVersion().osString` as headline, `key_ios16+problem+options` as caption) with `.padding(.bottom)`;
      - `if idiom == .phone { if iOS 17 with minor ≤ 4 }`: the same row with `arrow.backward` and `key_ios17+problem+swipe`.
    - Disclaimer: `VStack(.leading, spacing: 6) { Label(key_disclaimer, exclamationmark.triangle).footnote.bold(); key_disclaimer_description secondary footnote }.padding()`.
    - `Text(verbatim: "v<CFBundleShortVersionString ?? UNKNOWN VERSION>, build <CFBundleVersion ?? UNKNOWN BUILD>, OS <osString>")` with padding, caption and secondary.
  - `init(allowDebug:)` reads both Info.plist keys with `as? String`.
  - `isXmas()` returns true from 25 December 00:00 through `DateComponents(year, 12, 32)` (1 January 00:00) of the current year, both ends inclusive, using `Calendar.current`.

## `// shortcut:` guesses
1. `PremiumStatus.displayText` (PremiumCard.swift): the name is guessed. The binary inlined "`<days> <dayWord>` or rawText" into PremiumCard's body (0x1000fbef8).

Approximate, without a shortcut comment (layout only): the z-order of the three Sparkles follows the delays (0, 0.5, 0.9), and the HStack spacing inside InfoTabDemoView is left at its default.

## Deviations (all inside my files)
- `PremiumStatus.dayWord(for:)` is internal instead of private, and an internal `dayWordKey(for:)` was added. Reason: the shared `HDrezkaTests/ProfileAccountViewTests.swift` calls both. That file came from the earlier d3 agent, which also wrote drafts of my files straight into the shared tree at 15:22–15:27. I replaced those drafts after comparing them line by line with the binary. They supplied two fixes I had missed: `key_premium_active` and the name `voidboost`. In turn, they missed the card's NavigationStack, the closure-based backgrounds, the leading/6 VStacks in AboutUsView, `Text(verbatim:)` and the paddings.
- Added for tests: `AboutUsView.isXmas(on:calendar:)` (`isXmas()` calls it with `Date()` and `.current`) and `AboutUsView.versionText`.
- `PremiumStarIcon.init()` and `AboutUsView.init(allowDebug:)` live in extensions, so the memberwise inits from the stubs remain available.
- The rating row of InfoTabDemoView and the issue row of AboutUsView are private helper functions. The binary had merged each pair into one function (0x1001077e8, 0x1000e9f8c).

## Contract requests
None. Two notes for other owners. Neither one blocks this area:
- `SystemVersion.osString` (App/SharedFilmId.swift, d1a). The binary inlines it as `ProcessInfo().operatingSystemVersionString`, e.g. "Version 17.5 (Build 21F79)". The allocation shows up at every AboutUsView use (0x1000e72c8…). Ours builds "major.minor.patch". AboutUsView displays this string.
- `PlayerQualityPreference` / `DownloadDestination` (Models, Downloads). In the binary `Identifiable.ID` is `String` (`ForEach<[…], String, …>`); ours is `Self`. The settings pickers work with either.

## Review fixes
Both findings were checked against the evidence: the assigned simulator 17F7B3BA has `AppleLanguages = [en-UZ, ru-GE]` and `CFBundleDevelopmentRegion = en`; `en.lproj` maps `key_days_few` and `key_days_many` to "days"; the digest of 0x1000fd940 gives mod100 11…14 → `_many`, mod10 == 1 → `_one`, mod10 2…4 → `_few`, else `_many`; api-signatures.txt:248 shows `dayWord` with the file-private discriminator `_B418C51F…` (the same as `Sparkle`, line 9).
- **Applied: the plural test could not tell few from many** (`ViewsD3ATests.testDisplayTextUsesRussianPluralRules`). The table now holds the expected form, and each case asserts `PremiumStatus.dayWordKey(for:) == "key_days_<form>"` (works in any language), as well as `displayText == "<days> " + String(localized: key)`. A swapped `2...4` branch now fails in this file too. The second suggestion, expected strings from `ru.lproj`, was not taken: `displayText` resolves through `Bundle.main` in the current language, so it returns "5 days" on this simulator and that test would fail instead of getting stronger.
- **Kept: `dayWord(for:)` internal and the extra `dayWordKey(for:)`.** The finding is correct: both are file-private in the binary, or do not exist there. They stay internal, as the reviewer also suggested. The shared `HDrezkaTests/ProfileAccountViewTests.swift`, which is outside this area's paths, calls both, so making them private would break the test target. The fix above adds one more caller in this file. Open for the owner of ProfileAccountViewTests: to restore file-private access, drop those two calls there, make both functions private, and in `ViewsD3ATests` assert through `displayText` only. Few and many can then be told apart only on a ru/uk simulator.
- Results: `./build.sh d3a` gives BUILD SUCCEEDED. `ONLY=ViewsD3ATests ./build.sh d3a test` on 17F7B3BA gives TEST SUCCEEDED, 9 tests, 0 failures.
