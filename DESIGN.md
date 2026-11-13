---
name: HDRezka
description: Native iOS client for the HDRezka catalogue, a dense «Каталог» built on system components with one ember accent.
colors:
  accent: "#D92D00"
  accent-dark: "#FF5A26"
  accent-fill: "#D92D00"
  on-accent-fill: "#FFFFFF"
  badge-scrim: "rgba(0, 0, 0, 0.6)"
typography:
  title:
    fontFamily: "SF Pro (system), Dynamic Type title2"
    fontSize: "22pt"
    fontWeight: 700
  title-regular:
    fontFamily: "SF Pro (system), Dynamic Type largeTitle"
    fontSize: "34pt"
    fontWeight: 700
  section-title:
    fontFamily: "SF Pro (system), Dynamic Type title3"
    fontSize: "20pt"
    fontWeight: 700
  data-value:
    fontFamily: "SF Pro Rounded (system), Dynamic Type title3"
    fontSize: "20pt"
    fontWeight: 600
    fontFeature: "tnum"
  headline:
    fontFamily: "SF Pro (system), Dynamic Type headline"
    fontSize: "17pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro (system), Dynamic Type body"
    fontSize: "17pt"
    fontWeight: 400
  subheadline:
    fontFamily: "SF Pro (system), Dynamic Type subheadline"
    fontSize: "15pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro (system), Dynamic Type subheadline"
    fontSize: "15pt"
    fontWeight: 500
  caption:
    fontFamily: "SF Pro (system), Dynamic Type caption"
    fontSize: "12pt"
    fontWeight: 400
  caption2:
    fontFamily: "SF Pro (system), Dynamic Type caption2"
    fontSize: "11pt"
    fontWeight: 400
rounded:
  radiusBadge: "4pt"
  radiusPoster: "8pt"
  radiusButton: "12pt"
spacing:
  space4: "4pt"
  space8: "8pt"
  space16: "16pt"
  space24: "24pt"
components:
  button-primary:
    backgroundColor: "{colors.accent-fill}"
    textColor: "{colors.on-accent-fill}"
    typography: "{typography.headline}"
    rounded: "capsule (Liquid Glass, iOS 26+); {rounded.radiusButton} before"
    height: "44pt min"
    width: "100%"
  button-secondary:
    typography: "{typography.label}"
    rounded: "capsule (Liquid Glass, iOS 26+); {rounded.radiusButton} before"
    height: "44pt min"
  chip-list:
    typography: "{typography.subheadline}"
    rounded: "capsule (system border shape)"
  picker-menu:
    textColor: "{colors.accent}"
    typography: "{typography.body}"
    height: "44pt min"
  row-selection:
    typography: "{typography.body}"
    padding: "10pt 0"
    height: "44pt min"
  badge-poster:
    backgroundColor: "{colors.badge-scrim}"
    textColor: "{colors.on-accent-fill}"
    typography: "{typography.caption2}"
    rounded: "{rounded.radiusBadge}"
    padding: "4pt 8pt"
  poster:
    rounded: "{rounded.radiusPoster}"
    width: "96pt compact (64pt at accessibility sizes), 180pt regular"
---

# Design System: HDRezka

## Overview

**Creative North Star: "Каталог"**

A dense, informative catalogue that looks like iOS itself. The system's own grounds, bars, segmented controls, menus, forms and selection lists carry the structure; the brand speaks only through one ember accent taken from the app icon and through how much the screen tells you at a glance. Posters, ratings, voice actings, seasons and percentages are the decoration: data sits on posters and in rows, not in marketing cards.

Since the user's decision of 2026-11-11 («боле нативные по гайдлайну iOS, без наворотов»), the world is native per the HIG with no hand-drawn chrome. Toolbar actions are bare SF Symbols that the system bar draws as buttons; back is the system back button with its edge swipe. Actions are the system's Liquid Glass buttons on iOS 26 and later (`.glassProminent` for the one primary action, `.glass` for the rest; the user's choice of 2026-11-11, «кнопки в liquid»), and `.borderedProminent` / `.bordered` before it; choices are menu pickers, `Form` rows and lists with a trailing system checkmark. The cinematic Apple TV header (blurred art over the whole top, a white Play) is still the rejected default for the title page.

Density is high but legible: an 8 pt grid, Dynamic Type text styles everywhere, monospaced digits wherever numbers line up, and layouts that restack at accessibility sizes instead of truncating.

**Key Characteristics:**
- System backgrounds, system navigation, system controls; brand only in tint, type weight and content.
- One accent, on interactive elements only; one accent-filled primary action per screen.
- Data first: facts strip, poster badges, voice-acting rows with popularity and flags.
- Dynamic Type through AX5 with layout restacking; monospaced digits for data.
- Motion is short (0.2 s) and falls back to none or a crossfade under Reduce Motion.

## Colors

Neutral system grounds with a single warm ember accent; every other colour is a semantic system colour.

### Primary
- **Ember** (accent, light appearance; accent-dark in dark appearance): the app tint (AccentColor). Text links («Читать полностью», «Все озвучки · N»), menu-picker labels, the selection checkmark, the selected tab. Interactive only, never decoration.
- **Ember Fill** (accent-fill, both appearances): the fill of the one primary button (AccentFill). Kept at the light value in dark mode because white on the dark tint is about 3:1 and on the fill about 4.9:1.

### Neutral
- **System grounds and labels**: `systemBackground` for the page and the pinned segment, `.primary` / `.secondary` for text, `.quinary` / `.quaternary` for loading fills and empty avatars, the system separator (`Divider`) between rows. No hex values: they adapt to Dark Mode and Increased Contrast.
- **Badge Scrim** (badge-scrim): the solid black at 60% behind poster badges in grids, solid rather than a material so lazy grids scroll smoothly.

### Named Rules
**The One Ember Rule.** The accent appears only on things you can tap or on the mark of a current choice. Nothing static is ember.

**The Fill Is Not The Tint Rule.** Accent-filled surfaces with white text use Ember Fill, never the tint; the dark tint is a text colour.

## Typography

**Display Font:** SF Pro (system), via Dynamic Type text styles
**Body Font:** SF Pro (system)
**Label/Mono Font:** SF Pro Rounded with monospaced digits for data values; `.monospacedDigit()` on percentages and progress

**Character:** The platform face throughout, given hierarchy by weight rather than by size jumps; one rounded semibold numeral style marks data.

### Hierarchy
- **Title** (700, title2; largeTitle on iPad regular width): the title on the details page.
- **Section Title** (700, title3): catalogue sections («В ролях», «Трейлер», «Подборки», schedule).
- **Data Value** (600, title3 rounded, tabular digits): the facts strip values (IMDb, КиноПоиск, duration, age), one line, shrinking to 0.8.
- **Headline** (600, headline): the primary button's title, in-panel headers («Озвучка»), sheet headers, notices.
- **Body** (400, body): descriptions, voice-acting names, picker labels; descriptions fold at about six lines.
- **Subheadline** (400 / 500 medium for button labels): the original title, «Жанр · год · страна», the primary button's second line, secondary button and chip labels, fact rows.
- **Caption / Caption2** (400; caption2 semibold uppercase only for the site's entity type on poster badges): facts-strip captions, voice-acting flags, lock, card details.

### Named Rules
**The Text Style Rule.** Every size is a Dynamic Type text style; no fixed point sizes. At accessibility sizes, side-by-side layouts stack (facts grid to two columns, fact rows to caption-over-value, chips to a column); the page header instead keeps a 64 pt poster beside the names up to AX3 and stacks it above them from AX4, and a phone moves its facts to «О фильме».

**The Tabular Data Rule.** Numbers that sit in columns or update in place (ratings, percentages, episode progress) use monospaced digits.

## Layout

An 8 pt grid (4, 8, 16, 24). System horizontal margins (`.padding(.horizontal)`) on iPhone. The header follows the App Store and TV app headers: the poster at the leading edge, and beside it the title, the other title, «Жанр · год · страна» and the facts strip, so the column beside the poster is never empty. A phone puts the strip under both from xxxLarge, where its two columns no longer fit beside the poster; at accessibility sizes it keeps only the names, and the strip opens «О фильме» (whose rows give the date, country and every genre), so «Смотреть», «Скачать» and «В закладки» are on the first screen. Compact width shows that header, then a segmented control «Смотреть | О фильме / О сериале» pinned below the navigation bar with one half at a time. The page opens on «Смотреть» when this device has a position for the title, the account's «Досмотреть» lists it (the device's copy of the whole list, matched by the site's post number, so any mirror and the site's "-latest" addresses agree) or the page was opened to continue or from a «Обновления сериалов» row, and on «О фильме» otherwise; the site's `active` voice acting can't tell, since guest pages carry one too. Regular width (iPad) puts the header across and the two halves side by side, the watch column 320–420 pt (40% of width), with no segment. Panels stack at 16 pt between controls and 24 pt between sections. Sheets open at medium detent with the drag indicator and grow to large; a half-height sheet over a page gets an opaque grouped ground (`opaqueSheetBackground()`), because the iOS 26 glass let the ember button show through as an orange band. Every tappable control is at least 44 pt high. Content that can overflow (chips, cast) is clamped to the column width or scrolls horizontally. The cast row always ends in half a face, as the App Store's and the TV app's shelves cut their last item: its items take the width that fits whole faces plus half of the next (`DetailsCatalogSections.castItemWidth`), at any width and text size, so the row never looks finished. Poster grids on a phone show about three columns, and two at accessibility sizes (`TitleCardComponent.columnMinimum`), where a card fills its column at 2:3; a card in a horizontal row keeps its 113 pt. A card's title takes two lines at the grid's one size and ends in «…»; it never shrinks.

## Elevation & Depth

Flat. No shadows anywhere in the system. Depth comes only from the platform: the toolbar and tab bar glass, the system glass button styles, the trailer's glass play disc, sheet presentation, the pinned segment sitting on `systemBackground` under the bar's scroll edge. Loading states are quiet `.quinary` fills.

### Named Rules
**The System Depth Rule.** Only system bars, sheets and materials create depth; views add no shadows or hand-rolled blur.

## Shapes

Continuous rounded rectangles on a concentric scale: posters at radiusPoster, the trailer tile at radiusButton (and buttons before iOS 26), poster badges at radiusBadge (concentric with the poster at a 4 pt inset). Posters are 2:3, trailers 16:9. Person photos are clipped to circles as content. Capsules appear as the system border shape of glass buttons and list chips; the trailer's play symbol sits on a system glass disc. Controls get no hand-drawn circles, capsules, gauges or badges.

## Components

### Buttons
Native and quiet, with one loud exception.
- **Shape:** capsules on iOS 26 and later, like the bars and the segment around them (`primaryButtonStyle()` / `secondaryButtonStyle()` in Extensions.swift set it), and radiusButton rectangles at accessibility sizes, where wrapped labels would run into a capsule's ends; gently rounded (radiusButton) rectangles with the bordered styles before iOS 26.
- **Primary:** `PrimaryActionButton`, `primaryButtonStyle()` (`.glassProminent`, `.borderedProminent` before iOS 26), `.controlSize(.large)`, full width, tinted Ember Fill with white text: SF Symbol, the title in headline, and a second line in subheadline naming exactly what plays or saves. On the page the resume point joins the title and the remembered quality ends the title line like a row's value: «Продолжить с 23:14 … до 1080p» over «Сезон 2, Серия 8 · HDrezka Studio». That keeps a series' button at two lines at the default size; until 2026-11-13 both closed the second line and pushed a series onto a third. Where the title line can't hold both (accessibility sizes) the quality stacks under the title, and a long voice acting can still wrap the second line, as it did before. The quality is there when one is remembered and the button plays without asking (not with Infuse), as «до 1080p»: the episode's list comes only with its links, and the player takes that quality or the best below it, never one above. The sheets keep the resume point at the end of the second line («… · с 23:14»). A «·» is held to the part before it by a no-break space and «с 23:14» and «до 1080p Ultra» are one piece each, so a wrap never starts a line with «·». The title and the second line rewrite themselves with a numeric-text transition when the choice changes, and as soon as the player saves a position (`PlaybackProgressStore` is observable, so «Продолжить с …» is there when the player closes); a spinner replaces the symbol while loading. The VoiceOver label reads the title, the second line and the quality. One per screen: the page's «Смотреть / Продолжить», the download sheet's «Скачать».
- **Secondary:** `secondaryButtonStyle()` (`.glass`, `.bordered` before iOS 26), tinted `.primary` (not ember), label in subheadline medium with a leading SF Symbol, equal widths side by side and stacking when they don't fit («Скачать · В закладки»).
- **Text actions:** plain buttons in the accent, subheadline medium, 44 pt hit area («Читать полностью», «Все озвучки · N»). A row's header (title3 bold, a header for VoiceOver) ends in «Все» (`SeeAllLink`) when a whole list is behind it, as the App Store and Music head their rows: the same word on Home and on a person, its target growing away from the margin.

### Chips
- **Style:** list chips are `secondaryButtonStyle()` buttons with the system capsule border shape, tinted `.primary`, subheadline, one line clamped to column width.
- **State:** action only; no selected state.

### Inputs / Fields
- **Style:** `Form` with system `Picker` rows (voice acting, season, episode, quality), `Toggle`, `LabeledContent` with a spinner while loading. Section header names the subject; footer carries failure text and a retry.
- **Error / Disabled:** pickers disable while seasons load; failures show as footer text, never as a modal.

### Menu pickers
Season and episode on the page are system `Menu { Picker }` with the current value as the label, followed by an SF Symbol `chevron.up.chevron.down`, in the accent; side by side, stacking when they don't fit.

### Selection lists
`VoiceActingRow`: a full-width plain button with the name (lock symbol when premium can't play), flags under it in caption secondary («Премиум · Экранка · С рекламой»), the popularity percent in subheadline monospaced secondary, and a trailing accent `checkmark` whose space is always reserved. A row is at least 44 pt high and all of it is the target, as Settings' selection rows are. Rows separate with the system divider. Up to four rows, the chosen one in its own place, then «Все озвучки · N». Quality selection in its sheet follows the same trailing-checkmark pattern, and so does the bookmark sheet: a system `List` headed by the film's title, one row per category and a «Новая категория» row, «Готово» in the bar. A mark changes once the site confirms; until then a spinner holds its place, and a failure says why in the footer (a refused save offers «Войти»).

### Navigation
System `NavigationStack` with the inline title appearing in the bar once the header scrolls away; the system back button and edge swipe; bare SF Symbols in toolbar items (share). Tab bar for the top-level sections, which iPadOS draws as the top tab bar. An hdr:// link pushes its title onto the tab on screen only, as Music and Podcasts open links; the other tabs keep their place, and Back closes it where it opened. The logged-in Profile is an inset-grouped system `List` (Premium row, then «Досмотреть», «Закладки», «Обновления сериалов»), not cards, and «Загрузки» is a row of its own section under them, as the library in Music and Podcasts has one, with how many files are ready as its value and the system spinner while one is on its way; signed out, the same list holds the sign-in prompt over that row, since files on the device need no account, and the bar keeps only the settings gear; a subscription with three days or fewer gets the system red warning symbol next to its days, which stay `.primary`. «Досмотреть» and «Обновления сериалов» are inset-grouped lists too. A «Досмотреть» row (poster, title, what the site marks, its news about new episodes, the date) opens the page on «Смотреть»; what the site marks gets «· с 23:14» when this device has the position the page will resume from (the site keeps none), so the row says what the button will do; delete is a trailing swipe without full swipe, or the context menu, and the row goes once the site confirms. «Обновления» has a section per day and a row per episode («15 серия (1 сезон)» over the voice acting). A row opens its page on «Смотреть» with that episode in that voice acting as the choice, as the TV app opens a new episode on it: the voice acting is found by its whole name or the name in brackets (the row's «Coldfilm» is the page's «колдфильм (Coldfilm)»), another voice acting's seasons load first, and whatever the page lacks stays the page's own choice. Home is «Главная»: «Досмотреть» first, under the name of the list behind its «Все», as the TV app's Up Next row and screen share one, with the same words on its cards (kept on the device and shown from the first frame, placeholder cards before the first answer), then the listing's name in title3 bold with an ember chevron, the menu that switches it, over the grid; its 44 pt hit area grows above the text, so the grid sits 16 pt under the name. «Каталог» (1.6.0's «Подборки» tab) carries the site's header menu in the site's order: rows like Music's library (an ember SF Symbol, the name in title3, a tertiary chevron, dividers under the names) for Фильмы, Сериалы, Мультфильмы, Аниме, Новинки and Анонсы, then «Подборки» in title3 bold over the collection grid. «Все части франшизы» in «О фильме» is the same kind of row, as an artist's albums in Music: the part's number, its name in `.primary`, the year and rating (under the name at accessibility sizes, where the name keeps every line), a tertiary chevron, all of the row a 44 pt target that opens the part's page; the part on screen opens nothing and is `.secondary`, with a checkmark where the chevron would be. A section is an inset-grouped `List`: «Все …» and «Лучшие новинки» with the year as its value, «Найти лучшие» with the site's genre and year menu pickers and «Показать», the studios, every genre. Each listing it opens is Home's grid with its own title. «Поиск» follows the TV app's and the App Store's search: a large title with the field always under it; as you type, a plain list of titles (a 2:3 poster read once from the title's page, the title, the original title, «Сериал · 2024» in the site's words) that opens the page, with the spinner row while an answer is on its way, the system «Нет результатов» when the site found nothing and the failure with its fix when the request failed; «Найти» puts the full results grid under the same field, and editing the text brings the suggestions back.

### Loading and failure
- **Grids** (Home, a catalogue listing, a collection, a bookmark category) show skeleton cards: the real card, redacted, so posters drop into the same cells. A poster that can't load ends as a film symbol on the loading fill. The movie page's large poster has the listing's smaller one under it while it loads, keeps that one if it fails, and ends as the film symbol when both fail; posters give up after the same 15 s silence as pages.
- **The movie page** keeps the tapped card in view while it loads, its poster and title where the header will be, with the loading orb in the middle of the space below; a deep link or the continue row gets the orb alone, in the middle of the screen. **Lists**, a person, the watch sheet and the full search results show the orb by itself; search suggestions keep the system spinner in a row, since they come back as you type.
- **The loading orb** (`LoadingOrb`) is ThinkingOrbsKit's `ThinkingOrb` at 64 pt. It is monochrome ink that follows the colour scheme, freezes on one frame under Reduce Motion, and VoiceOver reads it as «Загрузка…». Its state names the wait: `searching` for search, `connecting` for the watch sheet's links, `working` for a page. Rows, buttons and the next page of a list keep the system spinner, and grids keep their skeletons: those waits are short, and a flashing orb reads as a glitch.
- **Slow sites:** after 8 s a footnote names the mirror («ijobs.app отвечает медленно…»); on the movie page a glass «Повторить» comes with it and starts the wait over. Every site request gives up after 15 s without data and after 30 s in all, however slowly a mirror trickles (`siteTimeout` and `siteDeadline` through `siteSession`), and `PageLoadFailedView` takes over with the cause and the fix.
- **Failure actions:** the fix the message names comes first as the one prominent action in Ember Fill, «Войти» for a 403 and «Сменить зеркало» for a dead or blocked mirror, with «Повторить» (glass) beside it. The two stack when they don't fit, and side by side they stay above the tab bar under Home's listing name.
- **Empty** is its own state with the next step (`ContentUnavailableView`, e.g. «Категорий пока нет» with «Новая категория»), never a blank screen, and a failure never looks empty. A catalogue listing that the site answers with its own 404 page (an empty «Лучшие» year) is «Похоже, тут ничего нет» without Retry; any other 404 is a host that isn't a mirror and stays a failure that offers another one.
- **Writes to the site** (bookmark marks, category changes) change the screen only after `success: true`; meanwhile the row shows a spinner and can't be tapped. A failure says so where it happened or in a toast, and VoiceOver announces it.

### Trailer
`TrailerTile`: the YouTube thumbnail at 16:9 (radiusButton) with a system glass play disc. A tap plays the trailer in the system full-screen player (AVKit: close, AirPlay, ±10 s, speed); closing it brings the tile back and the next tap resumes. While it starts, a spinner takes the play symbol's place on the same disc. The YouTube web view only feeds that player: on iPhone it sits behind the thumbnail, so YouTube's web chrome never shows; iPad's WebKit plays in place, so there the player takes over the tile. A trailer that YouTube won't embed opens in YouTube after the tap; any other failure stays on the page and the next tap loads the player again. Leaving the page pauses it.

### Facts strip
`InfoTabView`: equal cells, caption over Data Value, for IMDb, КиноПоиск (tap opens the rating page), duration and age. One row while every cell fits at full size, else two columns, else one (`EqualColumns` under `ViewThatFits`); no cell shrinks, so the values keep one size. A cell is as wide as the widest one needs, from the leading edge, never stretched across a wide column: on a phone the four sit 2×2 beside the poster, on an iPad in one row.

### Poster badge
`TitleBadge`: a data overlay on grid posters, not a control. The site's entity type in caption2 semibold uppercase over the series progress in caption2 monospaced, white on Badge Scrim, capped at xxxLarge so it never covers the poster.

## Do's and Don'ts

### Do:
- **Do** use system controls first: `primaryButtonStyle()` (Liquid Glass prominent) for the one primary action, `secondaryButtonStyle()` (glass) for the rest, menu pickers for choices, `Form` for input, selection lists with a trailing system checkmark.
- **Do** fill the primary button with Ember Fill (AccentFill), never the tint, and give it a second line naming what it will play or save.
- **Do** use spacing and radii from DesignTokens (4 / 8 / 16 / 24; 4 / 8 / 12) and add a token only when a second view needs the same number.
- **Do** use Dynamic Type text styles and restack layouts at accessibility sizes; keep every control at least 44 pt.
- **Do** use monospaced digits for ratings, percentages and progress.
- **Do** honour Reduce Motion: 0.2 s ease animations become none, the poster wipe becomes a crossfade, shimmers stop looping.
- **Do** give every screen that loads its loading, empty and failure states, and change the screen only after the site confirms a write.

### Don't:
- **Don't** draw circles, capsules, gauges or badges as control chrome; system border shapes and content clipping (avatars) are fine.
- **Don't** put toolbar symbols in their own background circle or replace the system back button.
- **Don't** use the accent on non-interactive elements or introduce a second accent hue.
- **Don't** add shadows or hand-rolled blur; depth belongs to system bars and sheets.
- **Don't** hard-code point sizes for text.
- **Don't** build the details page as a cinematic Apple TV header with blurred art and a white Play.
- **Don't** play trailers in a sheet or show YouTube's web player: the tile plays in the system full-screen player.
- **Don't** keep a global "open film": a page passes its own id to its sheets and its share link, and each tab keeps its own link state.
- **Don't** delete on a full swipe or without asking: a category takes its bookmarks with it.
