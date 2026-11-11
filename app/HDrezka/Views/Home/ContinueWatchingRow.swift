import SwiftUI

/// improvement: «Продолжить просмотр» at the top of Home. In 1.6.0 continuing meant Profile → «Досмотреть» → page →
/// «Смотреть» → sheet → quality; a card here opens the page and starts the marked episode. Logged-in users only; when
/// the list can't load the row just stays hidden (the full list has its own error state).
struct ContinueWatchingRow: View {
    /// Home's pull to refresh bumps it, so the row reloads with the listing.
    var refreshToken: Int = 0
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State private var items: [MovieWatchLater] = []

    var body: some View {
        // A VStack, not a Group: an empty Group has no view for `.task` to run on, so the row never loaded.
        VStack(alignment: .leading, spacing: 0) {
            if isLoggedIn && !items.isEmpty {
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
                            ForEach(items.prefix(10), id: \.self) { item in
                                NavigationLink {
                                    DetailsView(id: item.id, opensOnWatch: true)
                                } label: {
                                    ContinueWatchingCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, DesignTokens.space8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: "\(isLoggedIn)-\(refreshToken)") {
            guard isLoggedIn else {
                items = []
                return
            }
            items = (try? await AccountParser().parseWatchingLaterMovies()) ?? items
        }
    }
}

private struct ContinueWatchingCard: View {
    var item: MovieWatchLater
    @State private var poster: String? = nil
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @ScaledMetric(relativeTo: .caption) private var width: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space4) {
            WatchLaterPoster(url: poster, width: width)
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
            Text(item.watchingInfo)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("key_continue"))
        .task(id: item.id) {
            poster = await PosterCache.shared.poster(loading: item.id, mirror: settingStore, version: remoteVersion)
        }
    }
}
