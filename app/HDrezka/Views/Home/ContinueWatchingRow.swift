import SwiftUI

/// improvement: «Продолжить просмотр» at the top of Home. In 1.6.0 continuing meant Profile → «Досмотреть» → page →
/// «Смотреть» → sheet → quality; a card here opens the page on its «Смотреть» half. Logged-in users only.
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
                        Text("key_continue_watching")
                            .font(.title3.bold())
                        Spacer()
                        NavigationLink("key_all") {
                            WatchLaterView()
                                .environmentObject(AccountParser())
                        }
                        .font(.subheadline)
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

/// The last «Продолжить просмотр» answer, kept on the device so Home shows the row from its first frame.
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
        let title = titleKey(id)
        return load(from: defaults).contains { titleKey($0.id) == title }
    }

    /// The site's post number («93813» in ".../93813-zakon-alisii-2026.html»): the same on every mirror and with or
    /// without the "-latest" the site adds to some addresses. The address without its mirror when there is no number.
    private static func titleKey(_ id: String) -> String {
        let post = id.getMovieId()
        return !post.isEmpty && post.allSatisfy(\.isNumber) ? post : id.removeMirror()
    }
}

extension MovieWatchLater {
    /// A placeholder card while the row's first answer is on its way; the text is redacted.
    static let placeholder = MovieWatchLater(id: "", name: "Название фильма", details: "", watchingInfo: "1 сезон 1 серия",
                                             date: "", buttonText: nil, dataId: "")
}

private struct ContinueWatchingCard: View {
    var item: MovieWatchLater
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
            WatchLaterPoster(url: poster, width: cardWidth, isMissing: isPosterMissing)
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .padding(DesignTokens.space4)
                }
            Text(item.name)
                .font(.caption.bold())
                .lineLimit(2)
            // improvement: two lines, so the voice acting after the episode isn't cut to a letter.
            Text(item.watchingInfo)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
