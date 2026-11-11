import SwiftUI
import NukeUI

// improvement (Details redesign, contract «Два режима одной страницы»): the header of facts and the page's two halves,
// «Смотреть» and «О фильме». A compact width shows one half at a time under a pinned segment; a regular width (iPad,
// large iPhones in landscape) shows both side by side.

// MARK: Header

/// Poster and what's needed to decide: title, the other title, «Жанр · год · страна», then the ratings strip.
struct DetailsHeaderBlock: View {
    var detail: MovieDetailed
    var title: String
    var posterWidth: CGFloat
    var titleFont: Font = .title2.bold()
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space16) {
            // Side by side at accessibility sizes the title would get a few letters per line: the poster goes above it.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.space16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.space16))
            layout {
                DetailsPoster(detail: detail, width: posterWidth)
                VStack(alignment: .leading, spacing: DesignTokens.space4) {
                    Text(title)
                        .font(titleFont)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let other = otherTitle {
                        Text(other)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(detail.factsLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            InfoTabView(detail: detail)
        }
    }

    /// The original title under the Russian one, or the Russian one when the original leads (a setting).
    private var otherTitle: String? {
        let other = title == detail.nameRussian ? detail.nameOriginal : detail.nameRussian
        guard let other, !other.isEmpty, other != title else { return nil }
        return other
    }
}

/// The page's poster: 2:3, a quiet fill while it loads (nothing loops).
struct DetailsPoster: View {
    var detail: MovieDetailed
    var width: CGFloat

    var body: some View {
        LazyImage(url: URL(string: detail.hPoster.isEmpty ? detail.poster : detail.hPoster)) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                Rectangle().foregroundStyle(.quinary)
            }
        }
        .frame(width: width, height: width * 3 / 2)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: «Смотреть»

/// What will play and the one button that plays it: voice actings as rows (chosen, premium, popularity, flags), the
/// season and episode for a series, then download and bookmarks.
struct DetailsWatchPanel: View {
    var detail: MovieDetailed
    @ObservedObject var selection: PlaybackSelection
    var resumeSeconds: (PlaybackChoice) -> Double?
    var isBookmarked: Bool
    var play: (PlaybackChoice) -> Void
    var download: () -> Void
    var bookmark: () -> Void
    @AppStorage("hasPremium") private var hasPremium: String = ""
    @State private var showsAllVoices = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Within working memory; the rest is one tap away.
    private static let voiceRows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space16) {
            if detail.comingSoon {
                notice(systemImage: "clock", text: "key_comingsoon")
            } else if detail.availability != .AVAILABLE_ON_REZKA {
                notice(systemImage: "globe", text: "Video is unavailable in this region")
            } else {
                // The action first, so it stays in the first viewport; below it, what changes it.
                primaryButton
                secondaryActions
                if selection.isSeries {
                    episodePickers
                }
                if selection.seasonsFailed {
                    Label("key_seasons_failed", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if selection.actings.count > 1 {
                    voices
                        .padding(.top, DesignTokens.space8)
                }
            }
            if !DetailsViewComponent.canPlay(detail) {
                secondaryActions
            }
        }
    }

    // MARK: voice actings

    private var voices: some View {
        let signals = VoiceActingSignals(ratings: detail.voiceActingRating)
        let ordered = signals.ordered(selection.actings)
        let visible = PlaybackSelection.visibleVoices(ordered, chosen: selection.acting, showsAll: showsAllVoices,
                                                      limit: Self.voiceRows)
        return VStack(alignment: .leading, spacing: 0) {
            Text("voice acting")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, DesignTokens.space4)
            ForEach(visible, id: \.rowID) { acting in
                VoiceActingRow(acting: acting, percent: signals.percent(for: acting),
                               isChosen: acting == selection.acting,
                               isLocked: acting.isPremium && hasPremium.isEmpty) {
                    Task { await selection.select(acting) }
                }
                if acting.rowID != visible.last?.rowID {
                    Divider()
                }
            }
            if ordered.count > Self.voiceRows {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsAllVoices.toggle() }
                } label: {
                    (showsAllVoices ? Text("key_fewer_voices") : Text("key_all_voices \(ordered.count)"))
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: season and episode

    // Season and episode as the system's menu pickers (the selection with chevrons, tinted like any control).
    private var episodePickers: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.space16) {
                seasonPicker
                episodePicker
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: DesignTokens.space8) {
                seasonPicker
                episodePicker
            }
        }
        .disabled(selection.isLoadingSeasons)
    }

    // A system menu around the picker, so the label starts at the column's edge (a menu-style Picker insets it).
    private var seasonPicker: some View {
        Menu {
            Picker("season", selection: Binding(get: { selection.season?.id ?? "" }, set: { id in
                if let season = selection.seasons?.first(where: { $0.id == id }) { selection.select(season: season) }
            })) {
                ForEach(selection.seasons ?? [], id: \.id) { season in
                    Text(EpisodeNames.season(season)).tag(season.id)
                }
            }
        } label: {
            menuLabel(selection.season.map(EpisodeNames.season))
        }
        .accessibilityLabel(Text("season"))
        .accessibilityValue(Text(verbatim: selection.season.map(EpisodeNames.season) ?? ""))
    }

    private var episodePicker: some View {
        Menu {
            Picker("episode", selection: Binding(get: { selection.episode?.id ?? "" }, set: { id in
                if let episode = selection.season?.episodes.first(where: { $0.id == id }) { selection.select(episode: episode) }
            })) {
                ForEach(selection.season?.episodes ?? [], id: \.id) { episode in
                    Text(EpisodeNames.episode(episode)).tag(episode.id)
                }
            }
        } label: {
            menuLabel(selection.episode.map(EpisodeNames.episode))
        }
        .accessibilityLabel(Text("episode"))
        .accessibilityValue(Text(verbatim: selection.episode.map(EpisodeNames.episode) ?? ""))
    }

    private func menuLabel(_ text: String?) -> some View {
        HStack(spacing: DesignTokens.space4) {
            Text(verbatim: text ?? "—")
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: actions

    private var primaryButton: some View {
        let choice = selection.choice
        let resume = choice.flatMap(resumeSeconds)
        return PrimaryActionButton(title: choice?.isResume(resume) == true ? "key_continue" : "key_watch",
                                   detail: choice?.detailLine(resume: resume, voiceName: detail.singleVoiceActingName),
                                   systemImage: "play.fill",
                                   isLoading: selection.isLoadingSeasons) {
            if let choice { play(choice) }
        }
        .disabled(choice == nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: choice?.id)
    }

    private var secondaryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.space8) { secondaryButtons }
            VStack(spacing: DesignTokens.space8) { secondaryButtons }
        }
        .secondaryButtonStyle()
        .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
        .tint(.primary)
    }

    @ViewBuilder
    private var secondaryButtons: some View {
        if !detail.comingSoon && detail.availability == .AVAILABLE_ON_REZKA {
            Button(action: download) {
                secondaryLabel("Download", systemImage: "arrow.down.circle")
            }
        }
        Button(action: bookmark) {
            secondaryLabel(isBookmarked ? "key_in_bookmarks" : "key_add_to_bookmarks",
                           systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
        }
    }

    private func secondaryLabel(_ key: LocalizedStringKey, systemImage: String) -> some View {
        Label(key, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func notice(systemImage: String, text: LocalizedStringKey) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.space8)
    }
}

/// One voice acting as a selection row: the name (a lock while premium can't play), its flags, the site's share of
/// viewers, and the system checkmark on the chosen one.
struct VoiceActingRow: View {
    var acting: MovieVoiceActing
    var percent: Float?
    var isChosen: Bool
    var isLocked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.space8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.space4) {
                        Text(acting.name)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let flags = flagsText {
                        flags
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: DesignTokens.space8)
                if let percent {
                    Text(verbatim: Self.percentText(percent))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isChosen ? 1 : 0)
            }
            .font(.body)
            .foregroundStyle(Color.primary)
            .padding(.vertical, DesignTokens.space8 + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
        .accessibilityHint(isLocked ? Text("key_premium_only") : Text(verbatim: ""))
    }

    /// «Премиум · Экранка · С рекламой»; nil when the voice acting has none of them.
    private var flagsText: Text? {
        var parts: [Text] = acting.isPremium ? [Text("key_premium")] : []
        parts += VoiceFlag.flags(of: acting).map { Text($0.title) }
        guard var text = parts.first else { return nil }
        for part in parts.dropFirst() { text = text + Text(verbatim: " · ") + part }
        return text
    }

    /// "98 %", "4,2 %" and "<0,1 %" in the reader's locale.
    static func percentText(_ percent: Float) -> String {
        let share = Double(percent) / 100
        if percent > 0 && percent < 0.1 {
            return "<" + 0.001.formatted(.percent.precision(.fractionLength(1)))
        }
        return share.formatted(.percent.precision(.fractionLength(percent < 10 ? 1 : 0)))
    }
}

/// improvement: the one primary-action style, accent-filled and full width, for the page's «Смотреть» and the sheets'
/// main actions; the second line names what the action plays or saves, and rewrites itself when the choice changes.
struct PrimaryActionButton: View {
    var title: LocalizedStringKey
    var detail: String? = nil
    var systemImage: String
    var isLoading = false
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.space8 + 4) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: systemImage)
                    }
                }
                .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let detail, !detail.isEmpty {
                        Text(verbatim: detail)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignTokens.space4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .primaryButtonStyle()
        .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
        .controlSize(.large)
        // The light accent in both appearances: white on the dark accent (#FF5A26) is about 3:1, on #D92D00 about 4.9:1.
        .tint(Color("AccentFill"))
        .accessibilityLabel(accessibilityText)
    }

    /// "Продолжить, Сезон 2, Серия 8, HDrezka Studio, с 23:14": the dots read as pauses.
    private var accessibilityText: Text {
        guard let detail, !detail.isEmpty else { return Text(title) }
        return Text(title) + Text(verbatim: ", " + detail.replacingOccurrences(of: " · ", with: ", "))
    }
}

// MARK: «О фильме»

/// What's needed to decide: the full description, the facts, cast, trailer, lists, the episode schedule and the
/// franchise. 1.6.0 kept most of it behind a full-screen «больше» sheet.
struct DetailsAboutPanel: View {
    var detail: MovieDetailed
    var trailer: String?
    var openPerson: (PersonSimple) -> Void
    var openList: (MovieList) -> Void
    var openSchedule: () -> Void
    @State private var isDescriptionExpanded = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// About six lines of body text; longer descriptions fold.
    private static let foldLength = 320

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space24) {
            if !detail.description.isEmpty {
                description
                    .padding(.horizontal)
            }
            facts
                .padding(.horizontal)
            DetailsCatalogSections(detail: detail, trailer: trailer, openPerson: openPerson, openList: openList)
            if let group = detail.schedule?.first {
                schedule(group)
                    .padding(.horizontal)
            }
            if let franchise = detail.franchise, !franchise.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.space8) {
                    Text("key_all+franchise+parts")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    ForEach(franchise, id: \.self) { part in
                        FranchiseRowView(item: part)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var description: some View {
        let folds = detail.description.count > Self.foldLength
        return VStack(alignment: .leading, spacing: DesignTokens.space8) {
            Text(detail.description)
                .font(.body)
                .lineLimit(folds && !isDescriptionExpanded ? 6 : nil)
                .fixedSize(horizontal: false, vertical: true)
            if folds {
                Button(isDescriptionExpanded ? "key_read_less" : "key_read_more") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isDescriptionExpanded.toggle() }
                }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
            }
        }
    }

    /// Release date, country and every genre: the header shows only the year and the first genre.
    private var factRows: [(key: LocalizedStringKey, value: String)] {
        var rows: [(key: LocalizedStringKey, value: String)] = []
        if let date = detail.releaseDate, !date.isEmpty { rows.append(("key_releasedate", date)) }
        if !detail.country.isEmpty { rows.append(("key_country", detail.country)) }
        if !detail.genres.isEmpty { rows.append(("key_genre", detail.genres.map(\.name).joined(separator: ", "))) }
        return rows
    }

    @ViewBuilder
    private var facts: some View {
        let rows = factRows
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignTokens.space8) {
                ForEach(rows.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rows[index].0).foregroundStyle(.secondary)
                        Text(verbatim: rows[index].1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.subheadline)
        } else {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: DesignTokens.space16,
                 verticalSpacing: DesignTokens.space8) {
                ForEach(rows.indices, id: \.self) { index in
                    GridRow {
                        Text(rows[index].0).foregroundStyle(.secondary)
                        Text(verbatim: rows[index].1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.subheadline)
        }
    }

    private func schedule(_ group: SeriesScheduleGroup) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.space8) {
            Button(action: openSchedule) {
                Label("key_episodes+schedule", systemImage: "chevron.right")
                    .labelStyle(TextFirstLabel())
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            ForEach(group.items.prefix(5)) { item in
                SeasonRowView(title: item.title, russianEpisodeName: item.russianEpisodeName, releaseDate: item.releaseDate)
            }
        }
    }
}

extension MovieVoiceActing {
    /// A row's identity: `id` is the page's for every voice acting, and a translator can be listed twice
    /// ("HDrezka Studio" and "HDrezka Studio (18+)").
    var rowID: String { translatorId + "|" + name }
}
