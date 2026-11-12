import SwiftUI
import Alamofire
import NukeUI

/// The movie or series page, on the iPhone and the iPad. improvement (Details redesign, contract «Два режима одной
/// страницы»): a header of facts over two halves, «Смотреть» and «О фильме» (DetailsPanels.swift), one at a time under
/// a pinned segment in a compact width and side by side in a regular one, with the system navigation bar. 1.6.0 had a
/// blurred hero with a white Play and glass buttons on the phone, and a separate poster-and-icons page on the iPad.
struct DetailsViewComponent: View {
    var id: String
    /// improvement: «Продолжить» (Home's row, «Досмотреть») opens the page on its «Смотреть» half. Playback starts
    /// only from that half's button: a quality sheet popping up over a page just opened was a surprise.
    var opensOnWatch = false
    /// The card that opened the page, shown while it loads (nil for deep links and the continue row).
    var preview: MovieSimple? = nil
    @EnvironmentObject var detailsNetwork: MovieDetailsParser
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @AppStorage("hasPremium") var hasPremium: String = ""
    @AppStorage("preferOriginalTitle") var preferOriginalTitle: Bool = false
    @State var bookmarks: [Bookmark: Bool] = [:]
    /// improvement: the page's marks are taken once; 1.6.0 reset them to the loaded page on every appearance, so after
    /// a visit to a cast member the button said «В закладки» again and the next tap removed the film on the site.
    @State var bookmarksLoaded = false
    @State var isPresentedScheduleSheet = false
    @State var isPresentedDownloadSheet = false
    @State var isPresentedBookmarksSheet = false
    @State var isPresentedPersonInfoView = false
    @State var isPresentedList = false
    @State var video: String = ""
    @State var coverData: CoverData? = nil
    @State var trailer: String? = nil
    @State var personId: String = ""
    @State var listData = MovieList(id: "", name: "", moviePosition: 0)
    @State var loadFailure: PageLoadFailure? = nil
    /// improvement: one-tap playback (QuickPlaySheet).
    @State var quickPlay: PlaybackChoice? = nil
    /// The half a compact width shows, picked once per page by DetailsMode.initial.
    @State var mode: DetailsMode? = nil
    /// The title moves into the navigation bar once the header has scrolled away.
    @State var isTitleInBar = false
    @StateObject var selection = PlaybackSelection()
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private static let scrollSpace = "detailsPage"

    // 0x1000431c0: a spinner that loads the page, then the first parsed movie.
    var body: some View {
        if let detail = detailsNetwork.movieDetailed.first {
            page(detail)
                .navigationDestination(isPresented: $isPresentedPersonInfoView) {
                    PersonView(id: personId, isPresentedMoreSheet: .constant(false))
                }
                .navigationDestination(isPresented: $isPresentedList) {
                    MovieListView(id: listData.id, name: listData.name, movieId: id, isPresentedMoreSheet: .constant(false))
                }
                .onAppear { pageDidLoad(detail) }
                .task(priority: .userInitiated) { loadTrailer() }
        } else if let loadFailure {
            // Back to the orb, whose onAppear loads the page again; the system bar has the way back.
            PageLoadFailedView(failure: loadFailure) { self.loadFailure = nil }
        } else {
            DetailsLoadingView(preview: preview)
                .onAppear {
                    loadPage()
                }
        }
    }

    /// The original title when that setting is on and the page has one.
    static func title(_ detail: MovieDetailed, preferOriginal: Bool) -> String {
        preferOriginal ? detail.nameOriginal ?? detail.nameRussian : detail.nameRussian
    }

    static func canPlay(_ detail: MovieDetailed) -> Bool {
        !detail.comingSoon && detail.availability == .AVAILABLE_ON_REZKA
    }

    /// improvement: a 2xx answer without the movie block or its title is not a movie page; `parseMovieDetails` would
    /// throw on it too, this only skips the two attempts.
    static func isMoviePage(_ html: String) -> Bool {
        html.contains("b-content__main") && html.contains("b-post__title")
    }

    /// improvement: `id` is the absolute page URL with the host of the mirror it was listed on (ijobs.app for hdr://
    /// links); the page is requested from the current mirror, so a retry after a mirror change reaches the new one.
    static func pageURL(_ id: String, mirror: String) -> String {
        guard var components = URLComponents(string: id), components.host != nil else { return id }
        components.host = mirror
        return components.string ?? id
    }

    static func isBookmarked(_ bookmarks: [Bookmark: Bool]) -> Bool {
        bookmarks.values.contains(true)
    }

    // MARK: Network

    /// closure #2 in body.getter (0x10004f004): the movie page itself (`id` is its full URL), only the app headers.
    private func loadPage() {
        siteSession.request(Self.pageURL(id, mirror: settingStore), method: .get, headers: ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": remoteVersion])
            .responseString { response in
                Task { @MainActor in
                    // improvement: no body, a non-2xx answer or a page without the movie block end in the retry state
                    // instead of the endless spinner (a blocked mirror often answers 200 with its own page).
                    guard let html = response.value, (200..<300).contains(response.response?.statusCode ?? 0),
                          Self.isMoviePage(html) else {
                        loadFailure = PageLoadFailure(error: response.error, statusCode: response.response?.statusCode)
                        return
                    }
                    // improvement: a movie page the parser can't read says so, without blaming the mirror.
                    if (try? detailsNetwork.parseMovieDetails(html: html, movieId: id)) == nil,
                       (try? detailsNetwork.parseMovieDetails(html: html, movieId: id)) == nil {
                        loadFailure = .unparsable
                    }
                }
            }
    }

    /// closure #6 in closure #1 (0x10004e7e0): the YouTube id of the trailer, if the site has one.
    private func loadTrailer() {
        siteSession.request("https://\(settingStore)/engine/ajax/gettrailervideo.php", method: .post,
                   parameters: ["id": id.getMovieId()], encoder: URLEncodedFormParameterEncoder.default,
                   headers: ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": remoteVersion])
            .responseString { response in
                if case .success(let value) = response.result {
                    DispatchQueue.main.async {
                        trailer = try? detailsNetwork.parseTrailerId(response: value)
                    }
                }
            }
    }

    // MARK: Page

    private func page(_ detail: MovieDetailed) -> some View {
        let title = Self.title(detail, preferOriginal: preferOriginalTitle)
        return GeometryReader { proxy in
            ScrollView(.vertical) {
                Group {
                    if sizeClass == .regular {
                        sideBySide(detail, title: title, width: proxy.size.width)
                    } else {
                        segmented(detail, title: title)
                    }
                }
                // Nothing inside may widen the page past the screen (a one-line chip at a large text size did).
                .frame(width: proxy.size.width)
            }
            .coordinateSpace(name: Self.scrollSpace)
        }
        // A regular width (iPad) keeps the bar's centre for its tab bar: a title there would get a row of its own.
        .navigationTitle(sizeClass == .regular ? "" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if sizeClass != .regular {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(isTitleInBar ? 1 : 0)
                        .accessibilityHidden(!isTitleInBar)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareButton(filmId: id)
            }
        }
        .sheet(item: $quickPlay) { choice in
            QuickPlaySheet(id: id, choice: choice, video: $video, coverData: $coverData)
                .environmentObject(MovieDetailsService())
        }
        .sheet(isPresented: $isPresentedDownloadSheet) {
            DownloadParamsSheet(id: id, name: title, poster: detail.hPoster, voiceActing: detail.voiceActing, seasons: detail.seasons,
                                initial: selection.choice)
                .environmentObject(MovieDetailsService())
                // improvement: half height first; the sheet's four pickers and its button fit there.
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPresentedBookmarksSheet) {
            BookmarksSelectionListViewComponent(bookmarks: $bookmarks, filmId: id, title: title, onSignedIn: reloadAfterSignIn)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .opaqueSheetBackground()
        }
        .sheet(isPresented: $isPresentedScheduleSheet) {
            scheduleSheet(detail)
        }
        .fullScreenCover(item: $coverData) { data in
            PlayerViewComponent(url: data.body, subtitles: data.subtitles, name: title,
                                voiceActing: data.actingName, poster: detail.hPoster,
                                progressKey: data.progressKey, autoplay: data.autoplay, localFileURL: nil)
                .ignoresSafeArea(.all, edges: .all)
                .persistentSystemOverlays(.hidden)
        }
    }

    /// Compact width: the header, then one half under a segment that stays pinned below the navigation bar.
    private func segmented(_ detail: MovieDetailed, title: String) -> some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            header(detail, title: title, posterWidth: 96, titleFont: .title2.bold())
                .padding(.horizontal)
                .padding(.top, DesignTokens.space8)
                .padding(.bottom, DesignTokens.space16)
            Section {
                Group {
                    switch mode ?? .about {
                    case .watch:
                        watchPanel(detail)
                            .padding(.horizontal)
                    case .about:
                        aboutPanel(detail)
                    }
                }
                .transition(.opacity)
                .padding(.top, DesignTokens.space16)
                .padding(.bottom, DesignTokens.space24 * 2)
            } header: {
                modePicker(isSeries: PlaybackChoice.isSeries(detail))
            }
        }
    }

    /// Regular width: the header across, then «Смотреть» beside «О фильме».
    private func sideBySide(_ detail: MovieDetailed, title: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.space24 + DesignTokens.space8) {
            header(detail, title: title, posterWidth: 180, titleFont: .largeTitle.bold())
                .padding(.horizontal, 28)
            HStack(alignment: .top, spacing: DesignTokens.space24 + DesignTokens.space8) {
                watchPanel(detail)
                    .frame(width: min(420, max(320, width * 0.4)))
                // Its sections pad themselves, so their rows can scroll to the edge.
                aboutPanel(detail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 28)
            .padding(.trailing, 12)
        }
        .padding(.vertical, DesignTokens.space24)
    }

    private func header(_ detail: MovieDetailed, title: String, posterWidth: CGFloat, titleFont: Font) -> some View {
        DetailsHeaderBlock(detail: detail, title: title, posterWidth: posterWidth, titleFont: titleFont)
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .named(Self.scrollSpace)).maxY < 48
            } action: { scrolledAway in
                isTitleInBar = scrolledAway
            }
    }

    private func modePicker(isSeries: Bool) -> some View {
        Picker("key_mode_picker", selection: Binding(get: { mode ?? .about }, set: { newMode in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { mode = newMode }
        })) {
            Text(DetailsMode.watch.title(isSeries: isSeries)).tag(DetailsMode.watch)
            Text(DetailsMode.about.title(isSeries: isSeries)).tag(DetailsMode.about)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, DesignTokens.space8)
        // The page's own ground: no band at rest; pinned, it sits under the system bar's scroll edge.
        .background(Color(uiColor: .systemBackground))
    }

    private func watchPanel(_ detail: MovieDetailed) -> some View {
        DetailsWatchPanel(detail: detail, selection: selection, resumeSeconds: resumeSeconds,
                          isBookmarked: Self.isBookmarked(bookmarks), play: { quickPlay = $0 },
                          download: { isPresentedDownloadSheet = true }, bookmark: { isPresentedBookmarksSheet = true })
    }

    private func aboutPanel(_ detail: MovieDetailed) -> some View {
        DetailsAboutPanel(detail: detail, trailer: trailer, openPerson: openPerson, openList: openList,
                          openSchedule: { isPresentedScheduleSheet = true })
    }

    // MARK: Actions

    private func pageDidLoad(_ detail: MovieDetailed) {
        if !bookmarksLoaded {
            bookmarks = detail.bookmarks
            bookmarksLoaded = true
        }
        PosterCache.shared.store(detail.poster, for: id)
        let initial = PlaybackChoice.default(for: detail, hasPremium: !hasPremium.isEmpty)
        selection.configure(actings: detail.voiceActing, seasons: detail.seasons, initial: initial) { [id] acting in
            try await MovieDetailsService().getSeriesSeasons(movieId: id, voiceActing: acting)
        }
        if mode == nil {
            mode = DetailsMode.initial(canPlay: Self.canPlay(detail), opensOnWatch: opensOnWatch,
                                       hasProgress: PlaybackProgressStore.shared.hasProgress(forTitle: id))
        }
    }

    /// After a sign-in from the bookmark sheet: the page again, now with the account's categories.
    private func reloadAfterSignIn() {
        isPresentedBookmarksSheet = false
        bookmarksLoaded = false
        detailsNetwork.movieDetailed.removeAll()
    }

    private func resumeSeconds(_ choice: PlaybackChoice) -> Double? {
        PlaybackProgressStore.shared.time(forKey: QualitySelectionSheet.progressKey(
            id: id, acting: choice.acting, season: choice.season, episode: choice.episode))
    }

    private func openPerson(_ person: PersonSimple) {
        personId = person.id
        isPresentedPersonInfoView = true
    }

    private func openList(_ list: MovieList) {
        listData = list
        isPresentedList = true
    }

    // closure #2 in closure #2 in closure #1 (0x10004d2d8): the whole schedule.
    @ViewBuilder
    private func scheduleSheet(_ detail: MovieDetailed) -> some View {
        if let schedule = detail.schedule {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading) {
                        ForEach(schedule) { group in
                            Text(group.name)
                                .font(.title3.bold())
                                .padding(.vertical, 10)
                            ForEach(group.items) { item in
                                SeasonRowView(title: item.title, russianEpisodeName: item.russianEpisodeName, releaseDate: item.releaseDate)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("schedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // improvement: buttons instead of onTapGesture on a bare image (VoiceOver, ≥44pt hit area).
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("done") {
                            isPresentedScheduleSheet = false
                        }
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
    }
}

/// improvement: while the page loads, the card that was tapped stays in view: its poster and title sit where the page's
/// header will be, over the loading orb in the middle of the space left. 1.6.0 showed a spinner at a fixed 0.5 on a blank
/// page. Without a card (a deep link, the continue row) only the orb shows, in the middle of the screen.
private struct DetailsLoadingView: View {
    var preview: MovieSimple?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let isRegular = sizeClass == .regular
        VStack(alignment: .leading, spacing: DesignTokens.space24) {
            if let preview {
                header(preview, isRegular: isRegular)
                    .padding(.horizontal, isRegular ? 28 : DesignTokens.space16)
            }
            VStack(spacing: DesignTokens.space8) {
                LoadingOrb()
                SlowLoadNotice()
            }
            .padding(.horizontal, DesignTokens.space16)
            // All the height under the header (the whole screen without a card), with the orb in its middle.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, isRegular ? DesignTokens.space24 : DesignTokens.space8)
    }

    /// The loaded page's header (DetailsHeaderBlock) with what the card knows: poster, title and «год, страна, жанр».
    private func header(_ preview: MovieSimple, isRegular: Bool) -> some View {
        let posterWidth: CGFloat = isRegular ? 180 : 96
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.space16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.space16))
        return layout {
            LazyImage(url: URL(string: preview.poster)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle().foregroundStyle(.quinary)
                }
            }
            .frame(width: posterWidth, height: posterWidth * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.space4) {
                Text(preview.name)
                    .font(isRegular ? .largeTitle.bold() : .title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(preview.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
