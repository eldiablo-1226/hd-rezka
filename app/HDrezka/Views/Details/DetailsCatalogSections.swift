import SwiftUI
import NukeUI
import Flow
import YouTubePlayerKit

/// improvement: the catalogue on the film page itself, in its «О фильме» half (the voice actings moved to «Смотреть»,
/// DetailsWatchPanel). 1.6.0 kept the cast, the trailer and the lists in the «больше» sheet, so the page ended after
/// three lines of description.
struct DetailsCatalogSections: View {
    var detail: MovieDetailed
    var trailer: String?
    var openPerson: (PersonSimple) -> Void
    var openList: (MovieList) -> Void
    @State private var listsWidth: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.space24) {
            if !cast.isEmpty {
                section("key_cast") { castRow }
            }
            if let trailer {
                section("key_trailer") { trailerTile(trailer) }
            }
            if let lists = detail.lists, !lists.isEmpty {
                section("key_lists") { listChips(lists) }
            }
        }
    }

    private struct CastMember: Identifiable {
        let person: PersonSimple
        let isDirector: Bool
        var id: String { (isDirector ? "d:" : "a:") + person.id }
    }

    /// The cast first, then the directors, each marked as such; a director who also acts is listed once, as a director.
    /// improvement: «В ролях» opened with up to four directors.
    private var cast: [CastMember] {
        let directors = detail.producer ?? []
        let directorIds = Set(directors.map(\.id))
        return (detail.actors ?? []).filter { !directorIds.contains($0.id) }.map { CastMember(person: $0, isDirector: false) }
            + directors.map { CastMember(person: $0, isDirector: true) }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.space8) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal)
            content()
        }
    }

    private var castRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: DesignTokens.space16) {
                ForEach(cast) { item in
                    Button {
                        openPerson(item.person)
                    } label: {
                        PersonAvatar(person: item.person, isDirector: item.isDirector)
                    }
                    .buttonStyle(.plain)
                }
            }
            // The margin castItemWidth counts on.
            .padding(.horizontal, DesignTokens.space16)
        }
    }

    /// critique r3 (the App Store's and the TV app's shelves always cut their last item): a cast item's width, so the row
    /// ends in half a face at any width and text size. As many whole items as fit, none narrower than the face plus
    /// 4 pt, and half of the next: margin + n × (width + spacing) + width / 2 = container. A fixed 80 pt item ended on
    /// four whole faces at 402 pt and on five at 440 pt, and the row looked finished.
    static func castItemWidth(container: CGFloat, circle: CGFloat) -> CGFloat {
        let margin = DesignTokens.space16, spacing = DesignTokens.space16, narrowest = circle + DesignTokens.space4
        let whole = max(1, ((container - margin - narrowest / 2) / (narrowest + spacing)).rounded(.down))
        return max(narrowest, (container - margin - whole * spacing) / (whole + 0.5))
    }

    private func trailerTile(_ trailer: String) -> some View {
        TrailerTile(id: trailer)
            .id(trailer)
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal)
    }

    /// improvement: HFlow lays chips out at their one-line width, so the longest list name ran past the screen at
    /// large text sizes and dragged the page with it. Chips now stop at the column's width; accessibility sizes stack them.
    private func listChips(_ lists: [MovieList]) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignTokens.space8) {
                    ForEach(lists) { list in listChip(list, lineLimit: nil) }
                }
            } else {
                HFlow(spacing: DesignTokens.space8) {
                    ForEach(lists) { list in
                        listChip(list, lineLimit: 1)
                            .frame(maxWidth: listsWidth > 0 ? listsWidth : nil, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            listsWidth = width
        }
        .padding(.horizontal)
    }

    private func listChip(_ list: MovieList, lineLimit: Int?) -> some View {
        Button {
            openList(list)
        } label: {
            Text(list.name)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
        .font(.subheadline)
        .secondaryButtonStyle()
        .buttonBorderShape(.capsule)
        .tint(.primary)
    }
}

/// improvement: a tap plays the trailer in the system's full-screen player; Done brings the tile back and the next tap
/// resumes. 1.6.0 opened a sheet with YouTube's web player in it, which needed a second tap. On iPhone, WebKit plays a
/// video without `playsinline` only full screen, so the web view stays behind the thumbnail and YouTube's web chrome
/// never shows. iPad's WebKit plays it in place, so there the player takes over the tile.
private struct TrailerTile: View {
    let id: String
    @StateObject private var player: YouTubePlayer
    @State private var isLoaded = false
    @State private var isStarting = false
    @Environment(\.openURL) private var openURL
    private let playsInPlace = UIDevice.current.userInterfaceIdiom != .phone

    init(id: String) {
        self.id = id
        // The web view is created only when YouTubePlayerView first renders, i.e. after the tap.
        _player = StateObject(wrappedValue: YouTubePlayer(source: .video(id: id), configuration: .init(
            allowsPictureInPictureMediaPlayback: false, fullscreenMode: .system, autoPlay: true,
            playInline: false, showRelatedVideos: false)))
    }

    var body: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .background {
                if isLoaded && !playsInPlace {
                    YouTubePlayerView(player)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if isLoaded && playsInPlace {
                    // The thumbnail comes back on an error, so a tap can load it again.
                    YouTubePlayerView(player) { state in
                        switch state {
                        case .idle: ProgressView()
                        case .ready: EmptyView()
                        case .error: thumbnailButton
                        }
                    }
                } else {
                    thumbnailButton
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton, style: .continuous))
            // One subscription each for the tile's life, and only a pending tap reacts. The player's publishers are
            // rebuilt on every access and replay their last value, so `onReceive` ran it again on each redraw: an embed
            // error opened YouTube twice, then again while scrolling.
            .task {
                for await state in player.playbackStatePublisher.values where isStarting {
                    // `.cued` is where it stops when autoplay didn't start (Low Power Mode): the disc comes back.
                    if state == .playing || state == .paused || state == .ended || state == .cued { isStarting = false }
                }
            }
            .task {
                for await state in player.statePublisher.values {
                    guard case .error(let error) = state, isStarting else { continue }
                    isStarting = false
                    // Embedding is off for some trailers, and YouTube itself still plays those. Other errors (YouTube
                    // unreachable, a removed video, a killed web process) stay here; the next tap loads it again.
                    if case .embeddedVideoPlayingNotAllowed = error,
                       let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
                        openURL(url)
                    }
                }
            }
            .task {
                for await _ in player.autoplayBlockedPublisher.values { isStarting = false }
            }
            // Leaving the page: iPad's in-place player would keep talking underneath, and a trailer still loading would
            // autoplay over the next page. Guarded: touching `player` before the first tap creates its web view.
            .onDisappear {
                isStarting = false
                if isLoaded { Task { try? await player.pause() } }
            }
    }

    private var thumbnailButton: some View {
        Button(action: play) { thumbnail }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("key_play_trailer"))
    }

    // A 16:9 box that crops the letterbox bars of YouTube's 4:3 hqdefault thumbnail.
    private var thumbnail: some View {
        Color.clear
            .overlay {
                LazyImage(url: URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        // Opaque: on iPhone the web view sits right behind it.
                        Rectangle().fill(Color(uiColor: .secondarySystemBackground))
                    }
                }
            }
            .clipped()
            .overlay { playBadge }
            .contentShape(Rectangle())
    }

    // The play symbol, or the spinner while it starts, on a glass disc that stays visible on dark and light frames
    // alike; the 45% black disc vanished on dark ones.
    @ViewBuilder
    private var playBadge: some View {
        if #available(iOS 26.0, *) {
            Image(systemName: "play.fill")
                .font(.title)
                .opacity(isStarting ? 0 : 1)
                .overlay { if isStarting { ProgressView() } }
                .padding(DesignTokens.space16)
                .glassEffect(.regular, in: .circle)
                // White on dark glass over any frame, like the system player's own controls.
                .environment(\.colorScheme, .dark)
        } else {
            Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.palette)
                .foregroundStyle(isStarting ? .clear : .white, .black.opacity(0.45))
                .overlay { if isStarting { ProgressView().tint(.white) } }
        }
    }

    private func play() {
        isStarting = true
        if !isLoaded {
            isLoaded = true  // the web view loads and autoplays
        } else if player.state?.isError == true {
            player.reload()  // failed or killed: load it again, and autoplay starts it
        } else {
            Task { try? await player.play() }  // closed earlier: resume
        }
    }
}

/// A round photo with the name under it; a person without a photo gets the system silhouette.
private struct PersonAvatar: View {
    var person: PersonSimple
    var isDirector: Bool
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 64

    var body: some View {
        VStack(spacing: DesignTokens.space4) {
            LazyImage(url: person.photo.flatMap(URL.init(string:))) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            Text(person.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if isDirector {
                Text("key_director")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        // The scroll view's width, so half of the next face shows at the row's end.
        .containerRelativeFrame(.horizontal) { length, _ in
            DetailsCatalogSections.castItemWidth(container: length, circle: size)
        }
        .accessibilityElement(children: .combine)
    }
}
