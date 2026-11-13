import SwiftUI

/// improvement: «Досмотреть» at the top of Home. In 1.6.0 continuing meant Profile → «Досмотреть» → page →
/// «Смотреть» → sheet → quality; a card here opens the page on its «Смотреть» half. Logged-in users only. It has the
/// name of the list behind «Все» (critique r1; the TV app's Up Next row and screen share one): «Продолжить просмотр»
/// promised a resume point the page has only for titles watched on this device.
/// The last list is kept on the device and shown from the first frame, then refreshed, and before the first answer
/// placeholder cards hold its place: the row used to arrive last and push the listing down under the thumb.
struct ContinueWatchingRow: View {
    /// Home's pull to refresh bumps it, so the row reloads with the listing.
    var refreshToken: Int = 0
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State private var items: [MovieWatchLater] = ContinueWatchingCache.load()
    /// The site answered: placeholders give way to the list, or to nothing when it's empty.
    @State private var hasAnswer = false

    var body: some View {
        // A VStack, not a Group: an empty Group has no view for `.task` to run on, so the row never loaded.
        VStack(alignment: .leading, spacing: 0) {
            if isLoggedIn && (!items.isEmpty || !hasAnswer) {
                VStack(alignment: .leading, spacing: DesignTokens.space8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("key_watch_later")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        SeeAllLink {
                            WatchLaterView()
                                .environmentObject(AccountParser())
                        }
                    }
                    .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: DesignTokens.space16) {
                            if items.isEmpty {
                                ForEach(0..<3, id: \.self) { _ in
                                    ContinueWatchingCard(item: .placeholder)
                                        .redacted(reason: .placeholder)
                                        .accessibilityHidden(true)
                                }
                            } else {
                                // By film, not by value: a refreshed episode line must not replace the link and close
                                // a page opened from the cached card.
                                ForEach(items.prefix(10), id: \.id) { item in
                                    NavigationLink {
                                        DetailsView(id: item.id, opensOnWatch: true)
                                    } label: {
                                        ContinueWatchingCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollDisabled(items.isEmpty)
                }
                .padding(.top, DesignTokens.space8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: "\(isLoggedIn)-\(refreshToken)") {
            guard isLoggedIn else {
                items = []
                ContinueWatchingCache.clear()
                return
            }
            // A failed refresh keeps what is on screen; the full list has its own error state.
            let fresh = try? await AccountParser().parseWatchingLaterMovies()
            // The request doesn't stop on cancellation: an answer after a sign-out or a new account isn't written.
            guard !Task.isCancelled else { return }
            if let fresh {
                items = fresh
                ContinueWatchingCache.save(fresh)
            }
            hasAnswer = true
        }
    }
}

/// The last «Досмотреть» answer, kept on the device so Home shows the row from its first frame.
enum ContinueWatchingCache {
    private static let key = "continueWatchingCache"

    static func load(from defaults: UserDefaults = .standard) -> [MovieWatchLater] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([MovieWatchLater].self, from: data)) ?? []
    }

    /// The whole list: the row shows ten, and `contains` answers for every title the account is watching.
    static func save(_ items: [MovieWatchLater], to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(items), forKey: key)
    }

    /// On sign-out: the list belongs to the account.
    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// improvement: the account is watching this title (it's in the site's «Досмотреть»), whichever mirror either id
    /// was listed on. The page then opens on «Смотреть» even without a position saved on this device.
    static func contains(_ id: String, in defaults: UserDefaults = .standard) -> Bool {
        let title = id.titleKey
        return load(from: defaults).contains { $0.id.titleKey == title }
    }
}

extension MovieWatchLater {
    /// What the card's page will play (critique r1): the site's episode and voice acting, and «с 23:14» when this device
    /// has the position the page's «Смотреть» resumes from. The site keeps no position (it is sent current_time 1), so a
    /// title watched on another device names no time, and its page starts from the beginning.
    /// shortcut: a position is matched by season and episode, not by voice acting, which the site's list names and the
    /// key numbers; a position in another voice acting of the same episode shows here too. Upgrade if that shows up.
    func caption(progress: PlaybackProgressStore = .shared) -> String {
        let info = watchingInfo.trimmingCharacters(in: .whitespaces)
        let (season, episode) = markedEpisode
        guard let seconds = progress.latestTime(forTitle: id, season: season, episode: episode),
              seconds >= PlaybackChoice.resumeThreshold else { return info }
        return info + PlaybackChoice.separator + PlaybackChoice.resumeText(seconds)
    }

    /// "2 сезон 3 серия (Субтитры)" -> ("2", "3"), the progress key's season and episode ids; a film, which the site
    /// names by its voice acting, -> ("0", "0").
    var markedEpisode: (season: String, episode: String) {
        guard let match = watchingInfo.firstMatch(of: /(\d+) сезон (\d+) серия/) else { return ("0", "0") }
        return (String(match.1), String(match.2))
    }

    /// A placeholder card while the row's first answer is on its way; the text is redacted.
    static let placeholder = MovieWatchLater(id: "", name: "Название фильма", details: "", watchingInfo: "1 сезон 1 серия",
                                             date: "", buttonText: nil, dataId: "")
}

private struct ContinueWatchingCard: View {
    var item: MovieWatchLater
    /// Redraws the caption when the player saves a position.
    @ObservedObject private var progress = PlaybackProgressStore.shared
    @State private var poster: String? = nil
    /// The page had no poster for us: the card shows a film symbol instead of a fill that looks like loading.
    @State private var isPosterMissing = false
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @ScaledMetric(relativeTo: .caption) private var width: CGFloat = 112
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// improvement: on the iPad the cards are a third larger, so the row doesn't look like phone cards over its grid.
    private var cardWidth: CGFloat { sizeClass == .regular ? width * 4 / 3 : width }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space4) {
            // critique r2: no play symbol; a tap opens the page, where «Смотреть» plays.
            WatchLaterPoster(url: poster, width: cardWidth, isMissing: isPosterMissing)
            Text(item.name)
                .font(.caption.bold())
                .lineLimit(2)
            // improvement: two lines, so the voice acting after the episode isn't cut to a letter.
            let caption = item.caption(progress: progress)
            Text(verbatim: caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityLabel(Text(verbatim: PlaybackChoice.spoken(caption)))
        }
        .frame(width: cardWidth, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("key_continue_hint"))
        .task(id: item.id) {
            guard !item.id.isEmpty else { return }
            poster = await PosterCache.shared.poster(loading: item.id, mirror: settingStore, version: remoteVersion)
            isPosterMissing = poster == nil
        }
    }
}
