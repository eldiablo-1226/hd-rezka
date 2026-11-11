import SwiftUI
import NukeUI

/// One "continue watching" card: tap opens the details, a long press switches to delete / cancel
/// (body 0x10005d5e8, content 0x10005daf0). improvement: a poster, the title before the details, a readable date and
/// «Продолжить», which opens the page and starts the marked episode at once.
struct WatchLaterCardComponent: View {
    var movie: MovieWatchLater
    var moviePosition: Int
    @State var isRemoveMode: Bool = false
    @State var isPresented: Bool = false
    @State var opensOnWatch: Bool = false
    @State var poster: String? = nil
    @Binding var movieList: [MovieWatchLater]
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    // improvement: VoiceOver lands on the confirm button when remove mode opens (the card element it was on is gone).
    @AccessibilityFocusState var isDeleteFocused: Bool

    var body: some View {
        ViewThatFits {
            VStack {
                if !isRemoveMode {
                    // improvement: the tap and long-press gestures live on the background shape, which VoiceOver can't
                    // reach; the card's text becomes one button-like element with "delete" as a named action.
                    VStack(alignment: .leading, spacing: DesignTokens.space8) {
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
                                Text(movie.watchingInfo)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                // The site's "смотреть ещё 5 серий в 1 сезоне": news, not what «Продолжить» plays.
                                if let buttonText = movie.buttonText {
                                    // improvement: secondary; the accent is for what can be tapped.
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
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { open(onWatch: false) }
                        .accessibilityAction(named: Text("key_delete")) {
                            withAnimation(.default.speed(1.2)) { isRemoveMode = true }
                        }
                        // Opens the page on «Смотреть», at the episode it marks (where the user stopped).
                        Button {
                            open(onWatch: true)
                        } label: {
                            Label("key_continue", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        // Tinted, not filled: a filled accent button on every card made the list shout.
                        .secondaryButtonStyle()
                        .tint(.accentColor)
                        .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
                    }
                } else {
                    HStack {
                        // improvement: destructive role (VoiceOver announces it; system red). Bold, so white on system
                        // red (3.4–3.5:1) meets the HIG's 3:1 minimum for bold text (4.5:1 applies to regular ≤17pt).
                        Button(role: .destructive) {
                            _ = withAnimation(.default) { movieList.remove(at: moviePosition) }
                            Task { try await AccountService().removeWatchingItem(item: movie) }
                        } label: {
                            Text("key_delete").bold().frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        .accessibilityFocused($isDeleteFocused)
                        .onAppear { isDeleteFocused = true }
                        Spacer()
                        Button {
                            withAnimation(.default) { isRemoveMode = false }
                        } label: {
                            Text("key_cancel")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.primary)
                        }
                        .foregroundStyle(.secondary)
                        .secondaryButtonStyle()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(15)
            .background(alignment: .center) {
                // The gestures sit on the background shape, as in the binary (closure #2 in closure #1).
                RoundedRectangle(cornerRadius: DesignTokens.radiusButton, style: .continuous)
                    .foregroundStyle(.quinary)
                    .onTapGesture {
                        open(onWatch: false)
                    }
                    .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10) {
                        withAnimation(.default.speed(1.2)) { isRemoveMode = true }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
        }
        .padding(.horizontal)
        .navigationDestination(isPresented: $isPresented) {
            DetailsView(id: movie.id, opensOnWatch: opensOnWatch)
        }
        .task(id: movie.id) {
            poster = await PosterCache.shared.poster(loading: movie.id, mirror: settingStore, version: remoteVersion)
        }
    }

    private func open(onWatch: Bool) {
        opensOnWatch = onWatch
        isPresented = true
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
