import SwiftUI
import Alamofire
import NukeUI

struct DetailsViewComponent: View {
    var id: String
    @EnvironmentObject var detailsNetwork: MovieDetailsParser
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @AppStorage("preferOriginalTitle") var preferOriginalTitle: Bool = false
    @State var bookmarks: [Bookmark: Bool] = [:]
    @State var isPresentedScheduleSheet: Bool = false
    @State var isPresentedPlaySheet: Bool = false
    @State var isPresentedDownloadSheet: Bool = false
    @State var isPresentedMoreSheet: Bool = false
    @State var isPresentedBookmarksSheet: Bool = false
    @State var isPresentedPersonInfoView: Bool = false
    @State var isPresentedList: Bool = false
    @State var video: String = ""
    @State var coverData: CoverData? = nil
    @State var trailer: String? = nil
    @State var personId: String = ""
    @State var listData: MovieList = MovieList(id: "", name: "", moviePosition: 0)
    // 1, not 0, in the binary (0x10007d398): the header gradient divides by outerHeight before the first layout pass.
    @State var innerHeight: CGFloat = 1
    @State var outerHeight: CGFloat = 1
    @State var isAnimated: Bool = false

    // 0x1000431c0: a spinner that loads the page, then the first parsed movie in a FancyScrollView.
    var body: some View {
        if !detailsNetwork.movieDetailed.isEmpty {
            ForEach(detailsNetwork.movieDetailed.prefix(1)) { detail in
                FancyScrollView(title: Self.title(detail, preferOriginal: preferOriginalTitle), titleColor: .white,
                                headerHeight: 650, scrollUpHeaderBehavior: .parallax, scrollDownHeaderBehavior: .offset) {
                    header(detail)
                } content: {
                    content(detail)
                }
                .navigationDestination(isPresented: $isPresentedPersonInfoView) {
                    PersonView(id: personId, isPresentedMoreSheet: $isPresentedMoreSheet)
                }
                .navigationDestination(isPresented: $isPresentedList) {
                    MovieListView(id: listData.id, name: listData.name, movieId: id, isPresentedMoreSheet: $isPresentedMoreSheet)
                }
                .onAppear {
                    bookmarks = detail.bookmarks
                }
                .task(priority: .userInitiated) {
                    loadTrailer()
                }
            }
        } else {
            ProgressView(value: 0.5)
                .progressViewStyle(.circular)
                .onAppear {
                    loadPage()
                }
                .onAppear {
                    SharedFilmId.id = id
                }
        }
    }

    /// The original title when that setting is on and the page has one.
    static func title(_ detail: MovieDetailed, preferOriginal: Bool) -> String {
        preferOriginal ? detail.nameOriginal ?? detail.nameRussian : detail.nameRussian
    }

    /// "DRAMA • 2012 • USA": the genre line under the title (0x10004767c).
    static func genreLine(_ genre: MovieGenre, _ detail: MovieDetailed) -> String {
        "\(genre.name) • \(detail.releaseDate ?? "unknown") • \(detail.country)".uppercased()
    }

    /// Where the header blur starts fading in: the part of the overlay above the title block (0x10004af10).
    static func headerFadeLocation(inner: CGFloat, outer: CGFloat) -> CGFloat {
        (outer - inner) / outer
    }

    // MARK: Network

    /// closure #2 in body.getter (0x10004f004): the movie page itself (`id` is its full URL), only the app headers.
    private func loadPage() {
        AF.request(id, method: .get, headers: ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": remoteVersion])
            .responseString { response in
                Task { @MainActor in
                    if let html = response.value {
                        do {
                            _ = try detailsNetwork.parseMovieDetails(html: html, movieId: id)
                        } catch {
                            _ = try detailsNetwork.parseMovieDetails(html: html, movieId: id)
                        }
                    }
                }
            }
    }

    /// closure #6 in closure #1 (0x10004e7e0): the YouTube id of the trailer, if the site has one.
    private func loadTrailer() {
        AF.request("https://\(settingStore)/engine/ajax/gettrailervideo.php", method: .post,
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

    // MARK: Header (closure #1 in closure #1, inlined)

    private func header(_ detail: MovieDetailed) -> some View {
        GeometryReader { geometry in
            LazyImage(url: URL(string: detail.hPoster), transaction: Transaction(animation: .easeInOut)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .transition(wipe)
                } else {
                    LazyImage(url: URL(string: detail.poster), transaction: Transaction(animation: .easeInOut)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .transition(wipe)
                        } else {
                            Rectangle()
                                .foregroundStyle(.quinary)
                                .overlay(alignment: .center) {
                                    shimmer
                                }
                                .transition(wipe)
                        }
                    }
                    .transition(wipe)
                }
            }
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear {
                withAnimation(.default) {
                    isAnimated = true
                }
            }
        }
        .overlay(alignment: .center) {
            titleOverlay(detail)
        }
    }

    private var wipe: AnyTransition {
        .asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))
    }

    // 0x10004553c: a light band sweeping over the placeholder.
    private var shimmer: some View {
        Rectangle()
            .frame(height: 800)
            .frame(width: 16)
            .foregroundStyle(.quaternary)
            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.primary, .gray]), startPoint: .top, endPoint: .bottom))
            .rotationEffect(.degrees(30))
            .offset(x: isAnimated ? 800 : -800)
            .blur(radius: 6)
            .animation(.easeInOut.repeatForever(autoreverses: false).speed(0.3), value: isAnimated)
    }

    // closure #2 in closure #1 in closure #1 (0x100045c20): title, genre line and the action buttons over a blurred fade.
    private func titleOverlay(_ detail: MovieDetailed) -> some View {
        VStack {
            Spacer()
            VStack {
                Text(Self.title(detail, preferOriginal: preferOriginalTitle))
                    .font(.system(.largeTitle).leading(.tight))
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .lineLimit(4)
                ForEach(detail.genres[..<1]) { genre in
                    Text(Self.genreLine(genre, detail))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.bottom)
                }
                if !detail.comingSoon {
                    if detail.availability == .AVAILABLE_ON_REZKA {
                        HStack {
                            watchButton(detail)
                            bookmarkButton
                        }
                        downloadButton(detail)
                    } else {
                        unavailable(systemImage: "globe", text: "Video is unavailable in this region")
                    }
                } else {
                    unavailable(systemImage: "clock", text: "key_comingsoon")
                }
            }
            .padding(.horizontal, 20)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                innerHeight = height
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            outerHeight = height
        }
        .background(alignment: .center) {
            VStack {}
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .background(VisualEffectView(effect: UIBlurEffect(style: .dark)))
                .mask(alignment: .center) {
                    let fade = Self.headerFadeLocation(inner: innerHeight, outer: outerHeight)
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: .clear, location: fade * 0.75),
                        .init(color: .black.opacity(0.96), location: fade),
                        .init(color: .black.opacity(0.96), location: 1),
                    ]), startPoint: .top, endPoint: .bottom)
                }
        }
    }

    private func watchButton(_ detail: MovieDetailed) -> some View {
        Button {
            isPresentedPlaySheet.toggle()
        } label: {
            Label("Watch", systemImage: "play.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, maxHeight: 20)
        }
        .padding(.bottom)
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .controlSize(.large)
        .sheet(isPresented: $isPresentedPlaySheet) {
            VideoParamsSheet(id: id, coverData: $coverData, video: $video)
                .environmentObject(MovieDetailsService())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $coverData) { data in
            PlayerViewComponent(url: data.body, subtitles: data.subtitles,
                                name: Self.title(detail, preferOriginal: preferOriginalTitle),
                                voiceActing: data.actingName, poster: detail.hPoster,
                                progressKey: data.progressKey, autoplay: data.autoplay, localFileURL: nil)
                .ignoresSafeArea(.all, edges: .all)
                .persistentSystemOverlays(.hidden)
        }
    }

    private var bookmarkButton: some View {
        Button {
            isPresentedBookmarksSheet.toggle()
        } label: {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.black)
                .frame(maxHeight: 20)
        }
        .padding(.bottom)
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .controlSize(.large)
        .sheet(isPresented: $isPresentedBookmarksSheet) {
            bookmarksSheet
        }
    }

    private func downloadButton(_ detail: MovieDetailed) -> some View {
        Button {
            isPresentedDownloadSheet.toggle()
        } label: {
            Label("Download", systemImage: "icloud.and.arrow.down")
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: 20)
        }
        .padding(.bottom)
        .buttonStyle(.borderedProminent)
        .tint(Color(uiColor: .opaqueSeparator).opacity(0.4))
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .controlSize(.large)
        .sheet(isPresented: $isPresentedDownloadSheet) {
            DownloadParamsSheet(id: id, name: Self.title(detail, preferOriginal: preferOriginalTitle), poster: detail.hPoster,
                                voiceActing: detail.voiceActing, seasons: detail.seasons)
                .environmentObject(MovieDetailsService())
        }
    }

    // closures #6 / #7 (0x100049afc, 0x10004a2fc): no player, but bookmarks still work.
    private func unavailable(systemImage: String, text: LocalizedStringKey) -> some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.white)
            Text(text)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(5)
            Button("add_to_bookmarks") {
                isPresentedBookmarksSheet.toggle()
            }
            .buttonStyle(.bordered)
            .padding(.vertical)
            .sheet(isPresented: $isPresentedBookmarksSheet) {
                bookmarksSheet
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
    }

    private var bookmarksSheet: some View {
        BookmarksSelectionListViewComponent(bookmarks: $bookmarks)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }

    // MARK: Content (closure #2 in closure #1, 0x10004b120)

    private func content(_ detail: MovieDetailed) -> some View {
        VStack(alignment: .leading) {
            InfoTabView(detail: detail)
                .padding(.top)
            ZStack {
                Text(detail.description)
                    .font(.body)
                    .lineLimit(3)
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        ZStack(alignment: .trailing) {
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(height: 20)
                                .background(LinearGradient(gradient: Gradient(stops: [
                                    .init(color: Color(uiColor: .systemBackground), location: 0.2),
                                    .init(color: .clear, location: 0.3),
                                ]), startPoint: .trailing, endPoint: .leading))
                            Spacer()
                            Button("key_more") {
                                isPresentedMoreSheet.toggle()
                            }
                            .padding(.trailing)
                        }
                        .fullScreenCover(isPresented: $isPresentedMoreSheet) {
                            InfoSheetViewComponent(id: id, detail: detail, trailer: trailer, personId: $personId,
                                                   listData: $listData, isPresentedPersonInfo: $isPresentedPersonInfoView,
                                                   isPresentedList: $isPresentedList, isPresentedMoreSheet: $isPresentedMoreSheet)
                        }
                    }
                }
            }
            .padding(.horizontal)
            if let schedule = detail.schedule {
                ForEach(schedule[..<1]) { group in
                    Label("key_episodes+schedule", systemImage: "chevron.right")
                        .labelStyle(TextFirstLabel())
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.vertical, 10)
                        .onTapGesture {
                            isPresentedScheduleSheet.toggle()
                        }
                    ForEach(group.items.prefix(5)) { item in
                        SeasonRowView(title: item.title, russianEpisodeName: item.russianEpisodeName, releaseDate: item.releaseDate)
                    }
                }
                .padding(.horizontal)
            }
            if let franchise = detail.franchise {
                Text("key_all+franchise+parts")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                ForEach(franchise, id: \.self) { part in
                    FranchiseRowView(item: part)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $isPresentedScheduleSheet) {
            scheduleSheet(detail)
        }
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
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.vertical, 10)
                            ForEach(group.items) { item in
                                SeasonRowView(title: item.title, russianEpisodeName: item.russianEpisodeName, releaseDate: item.releaseDate)
                            }
                        }
                    }
                    .padding()
                }
                .toolbar {
                    // shortcut: both taps assumed to toggle the sheet flag (they reach a merged thunk via 0x100055b94), check its body
                    ToolbarItem(placement: trailingPlacement) {
                        if #available(iOS 26.0, *) {
                            AnyView(
                                Image(systemName: "xmark")
                                    .onTapGesture {
                                        isPresentedScheduleSheet.toggle()
                                    }
                            )
                        } else {
                            Image(systemName: "xmark")
                                .onTapGesture {
                                    isPresentedScheduleSheet.toggle()
                                }
                                .padding()
                                .background(Circle().frame(height: 30).foregroundStyle(.ultraThinMaterial))
                        }
                    }
                }
            }
        }
    }

    private var trailingPlacement: ToolbarItemPlacement {
        if #available(iOS 17.0, *) {
            return .topBarTrailing
        } else {
            return .navigationBarTrailing
        }
    }
}
