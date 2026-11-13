import SwiftUI
import NukeUI

/// One "continue watching" entry (1.6.0's card, body 0x10005d5e8, content 0x10005daf0): poster, title, the year, what
/// the site marks as watched, its news about new episodes and the date. improvement: the content of a system list row
/// in WatchLaterView, which opens the page on «Смотреть» and owns delete (1.6.0: a grey card with its own
/// «Продолжить», a tap and a long press on its background).
struct WatchLaterCardComponent: View {
    var movie: MovieWatchLater
    /// Its removal is on its way to the site.
    var isRemoving = false
    /// Redraws the caption when the player saves a position.
    @ObservedObject private var progress = PlaybackProgressStore.shared
    @State private var poster: String? = nil
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.space16) {
            WatchLaterPoster(url: poster)
            VStack(alignment: .leading, spacing: DesignTokens.space4) {
                Text(movie.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(movie.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // The Home card's words: what the site marks, and «с 23:14» when this device can resume it.
                let caption = movie.caption(progress: progress)
                Text(verbatim: caption)
                    .font(.subheadline)
                    .lineLimit(2)
                    .accessibilityLabel(Text(verbatim: PlaybackChoice.spoken(caption)))
                // The site's "смотреть ещё 5 серий в 1 сезоне": news, not what the row plays.
                if let buttonText = movie.buttonText {
                    Text(verbatim: buttonText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(Self.displayDate(movie.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isRemoving {
                ProgressView()
            }
        }
        .padding(.vertical, DesignTokens.space4)
        .task(id: movie.id) {
            poster = await PosterCache.shared.poster(loading: movie.id, mirror: settingStore, version: remoteVersion)
        }
    }

    /// improvement: the site's "04-11-2026" as "4 ноября 2026"; "сегодня" / "вчера" and anything else stay as they are.
    static func displayDate(_ date: String,
                            locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "ru")) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "dd-MM-yyyy"
        guard let parsed = parser.date(from: date) else { return date }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM y")
        return formatter.string(from: parsed)
    }
}

/// A 2:3 poster thumbnail; the quinary placeholder until (or unless) the poster is known.
struct WatchLaterPoster: View {
    var url: String?
    var width: CGFloat = 60
    /// improvement: no poster to load; a film symbol says so instead of a fill that looks like loading.
    var isMissing = false

    var body: some View {
        LazyImage(url: url.flatMap(URL.init(string:))) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else if isMissing || (url != nil && state.error != nil) {
                MissingPoster()
            } else {
                Rectangle().foregroundStyle(.quinary)
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster, style: .continuous))
        .accessibilityHidden(true)
    }
}
