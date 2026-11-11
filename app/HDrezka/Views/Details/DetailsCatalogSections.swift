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
    @State private var isPresentingTrailer = false
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
            .padding(.horizontal)
        }
    }

    private func trailerTile(_ trailer: String) -> some View {
        Button {
            isPresentingTrailer = true
        } label: {
            // A 16:9 box that crops the letterbox bars of YouTube's 4:3 hqdefault thumbnail.
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    LazyImage(url: URL(string: "https://i.ytimg.com/vi/\(trailer)/hqdefault.jpg")) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().foregroundStyle(.quinary)
                        }
                    }
                }
                .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton, style: .continuous))
            .overlay {
                Image(systemName: "play.circle.fill")
                    .font(.system(.largeTitle))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel(Text("key_play_trailer"))
        .sheet(isPresented: $isPresentingTrailer) {
            YouTubePlayerViewComponent(youTubePlayer: YouTubePlayer(source: .video(id: trailer)))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(.primary)
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
        .frame(width: size + DesignTokens.space16)
        .accessibilityElement(children: .combine)
    }
}
