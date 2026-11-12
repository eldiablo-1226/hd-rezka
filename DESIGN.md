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
    width: "96pt compact, 180pt regular"
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
**The Text Style Rule.** Every size is a Dynamic Type text style; no fixed point sizes. At accessibility sizes, side-by-side layouts stack (poster above title, facts grid to two columns, fact rows to caption-over-value, chips to a column).

**The Tabular Data Rule.** Numbers that sit in columns or update in place (ratings, percentages, episode progress) use monospaced digits.

## Layout

An 8 pt grid (4, 8, 16, 24). System horizontal margins (`.padding(.horizontal)`) on iPhone. Compact width shows the header of facts, then a segmented control «Смотреть | О фильме / О сериале» pinned below the navigation bar with one half at a time; the page opens on the relevant half. Regular width (iPad) puts the header across and the two halves side by side, the watch column 320–420 pt (40% of width), with no segment. Panels stack at 16 pt between controls and 24 pt between sections. Sheets open at medium detent with the drag indicator and grow to large. Every tappable control is at least 44 pt high. Content that can overflow (chips, cast) is clamped to the column width or scrolls horizontally.

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
- **Primary:** `PrimaryActionButton`, `primaryButtonStyle()` (`.glassProminent`, `.borderedProminent` before iOS 26), `.controlSize(.large)`, full width, tinted Ember Fill with white text: SF Symbol, the title in headline, and a second line in subheadline naming exactly what plays or saves («Сезон 2, Серия 8 · HDrezka Studio · с 23:14»). The second line rewrites itself with a numeric-text transition when the choice changes; a spinner replaces the symbol while loading. The VoiceOver label reads the title plus the second line. One per screen: the page's «Смотреть / Продолжить», the download sheet's «Скачать».
- **Secondary:** `secondaryButtonStyle()` (`.glass`, `.bordered` before iOS 26), tinted `.primary` (not ember), label in subheadline medium with a leading SF Symbol, equal widths side by side and stacking when they don't fit («Скачать · В закладки»).
- **Text actions:** plain buttons in the accent, subheadline medium, 44 pt hit area («Читать полностью», «Все озвучки · N»).

### Chips
- **Style:** list chips are `secondaryButtonStyle()` buttons with the system capsule border shape, tinted `.primary`, subheadline, one line clamped to column width.
- **State:** action only; no selected state.

### Inputs / Fields
- **Style:** `Form` with system `Picker` rows (voice acting, season, episode, quality), `Toggle`, `LabeledContent` with a spinner while loading. Section header names the subject; footer carries failure text and a retry.
- **Error / Disabled:** pickers disable while seasons load; failures show as footer text, never as a modal.

### Menu pickers
Season and episode on the page are system `Menu { Picker }` with the current value as the label, followed by an SF Symbol `chevron.up.chevron.down`, in the accent; side by side, stacking when they don't fit.

### Selection lists
`VoiceActingRow`: a full-width plain button with the name (lock symbol when premium can't play), flags under it in caption secondary («Премиум · Экранка · С рекламой»), the popularity percent in subheadline monospaced secondary, and a trailing accent `checkmark` whose space is always reserved. Rows separate with the system divider. Up to four rows, the chosen one in its own place, then «Все озвучки · N». Quality selection in its sheet follows the same trailing-checkmark pattern, and so does the bookmark sheet: a system `List` headed by the film's title, one row per category and a «Новая категория» row, «Готово» in the bar. A mark changes once the site confirms; until then a spinner holds its place, and a failure says why in the footer (a refused save offers «Войти»).

### Navigation
System `NavigationStack` with the inline title appearing in the bar once the header scrolls away; the system back button and edge swipe; bare SF Symbols in toolbar items (share). Tab bar for the top-level sections, which iPadOS draws as the top tab bar. The logged-in Profile is an inset-grouped system `List` (Premium row, then «Досмотреть», «Закладки», «Обновления сериалов»), not cards. Home is «Главная»: «Продолжить просмотр» first (kept on the device and shown from the first frame, placeholder cards before the first answer), then the listing's name in title3 bold with an ember chevron, the menu that switches it, over the grid. «Каталог» (1.6.0's «Подборки» tab) carries the site's header menu in the site's order: rows like Music's library (an ember SF Symbol, the name in title3, a tertiary chevron, dividers under the names) for Фильмы, Сериалы, Мультфильмы, Аниме, Новинки and Анонсы, then «Подборки» in title3 bold over the collection grid. A section is an inset-grouped `List`: «Все …» and «Лучшие новинки» with the year as its value, «Найти лучшие» with the site's genre and year menu pickers and «Показать», the studios, every genre. Each listing it opens is Home's grid with its own title.

### Loading and failure
- **Grids** (Home, a catalogue listing, a collection, a bookmark category) show skeleton cards: the real card, redacted, so posters drop into the same cells. A poster that can't load ends as a film symbol on the loading fill.
- **The movie page** keeps the tapped card in view while it loads, its poster and title where the header will be, with the loading orb in the middle of the space below; a deep link or the continue row gets the orb alone, in the middle of the screen. **Lists**, a person, the watch sheet and search show the orb by itself.
- **The loading orb** (`LoadingOrb`) is ThinkingOrbsKit's `ThinkingOrb` at 64 pt. It is monochrome ink that follows the colour scheme, freezes on one frame under Reduce Motion, and VoiceOver reads it as «Загрузка…». Its state names the wait: `searching` for search, `connecting` for the watch sheet's links, `working` for a page. Rows, buttons and the next page of a list keep the system spinner, and grids keep their skeletons: those waits are short, and a flashing orb reads as a glitch.
- **Slow sites:** after 8 s a footnote names the mirror («ijobs.app отвечает медленно…»). Every site request gives up after 15 s without data (`siteTimeout` through `siteSession`), and `PageLoadFailedView` takes over with the cause and the fix.
- **Empty** is its own state with the next step (`ContentUnavailableView`, e.g. «Категорий пока нет» with «Новая категория»), never a blank screen, and a failure never looks empty. A catalogue listing that the site answers with its own 404 page (an empty «Лучшие» year) is «Похоже, тут ничего нет» without Retry; any other 404 is a host that isn't a mirror and stays a failure that offers another one.
- **Writes to the site** (bookmark marks, category changes) change the screen only after `success: true`; meanwhile the row shows a spinner and can't be tapped. A failure says so where it happened or in a toast, and VoiceOver announces it.

### Trailer
`TrailerTile`: the YouTube thumbnail at 16:9 (radiusButton) with a system glass play disc. A tap plays the trailer in the system full-screen player (AVKit: close, AirPlay, ±10 s, speed); closing it brings the tile back and the next tap resumes. While it starts, a spinner takes the play symbol's place on the same disc. The YouTube web view only feeds that player: on iPhone it sits behind the thumbnail, so YouTube's web chrome never shows; iPad's WebKit plays in place, so there the player takes over the tile. A trailer that YouTube won't embed opens in YouTube after the tap; any other failure stays on the page and the next tap loads the player again. Leaving the page pauses it.

### Facts strip
`InfoTabView`: equal cells, caption over Data Value, for IMDb, КиноПоиск (tap opens the rating page), duration and age; four columns, two at accessibility sizes.

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
- **Don't** keep a global "open film": a page passes its own id to its sheets and its share link.
- **Don't** delete on a full swipe or without asking: a category takes its bookmarks with it.
