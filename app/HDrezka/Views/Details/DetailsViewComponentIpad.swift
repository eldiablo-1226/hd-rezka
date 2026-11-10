import SwiftUI
import Alamofire
import NukeUI

struct DetailsViewComponentIpad: View {
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
    @State var isAnimated: Bool = false
    @Environment(\.dismiss) var dismiss

    // 0x1000c8efc: same data flow as the phone page, laid out as poster + info column with icon buttons.
    var body: some View {
        if !detailsNetwork.movieDetailed.isEmpty {
            ForEach(detailsNetwork.movieDetailed.prefix(1)) { detail in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        HStack {
                            poster(detail)
                            VStack {
                                Spacer()
                                Group {
                                    info(detail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.leading, 28)
                            Spacer()
                        }
                        .padding(.leading, 28)
                        InfoTabView(detail: detail)
                            .padding(.vertical, 26)
                        if let schedule = detail.schedule {
                            ForEach(schedule[..<1]) { group in
                                Label("key_episodes+schedule", systemImage: "chevron.right")
                                    .hoverEffect(.highlight)
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
                            .sheet(isPresented: $isPresentedScheduleSheet) {
                                scheduleSheet(detail)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                        if let franchise = detail.franchise {
                            Text("key_all+franchise+parts")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(franchise, id: \.self) { part in
                                FranchiseRowView(item: part)
                            }
                            .padding(.horizontal)
                        }
                    }
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: leadingPlacement) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 18, alignment: .leading)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 18)
                                .font(.system(size: 16, weight: .semibold))
                                .background(Circle().frame(height: 30).foregroundStyle(.ultraThinMaterial))
                        }
                    }
                    ToolbarItem(placement: trailingPlacement) {
                        ShareButton(color: .primary)
                    }
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

    private func title(_ detail: MovieDetailed) -> String {
        DetailsViewComponent.title(detail, preferOriginal: preferOriginalTitle)
    }

    // MARK: Network (closure #2 in body.getter / closure #6 in closure #1, as on the phone)

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

    // MARK: Poster (closure #1 in closure #1 in closure #1 in closure #1, 0x1000cae58)

    private func poster(_ detail: MovieDetailed) -> some View {
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
                            .onAppear {
                                withAnimation(.easeOut.repeatForever(autoreverses: false).speed(0.3)) {
                                    isAnimated = true
                                }
                            }
                            .transition(wipe)
                    }
                }
                .transition(wipe)
            }
        }
        .scaledToFill()
        .frame(width: 311, height: 470)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private var wipe: AnyTransition {
        .asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))
    }

    // 0x1000cc3c0
    private var shimmer: some View {
        Rectangle()
            .frame(height: 600)
            .frame(width: 30)
            .foregroundStyle(.quaternary)
            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.primary, .gray]), startPoint: .top, endPoint: .bottom))
            .rotationEffect(.degrees(30))
            .offset(x: isAnimated ? 120 : -120)
            .blur(radius: 15)
    }

    // MARK: Info column (closure #1 in closure #2 …, 0x1000cca84)

    @ViewBuilder
    private func info(_ detail: MovieDetailed) -> some View {
        Text(title(detail))
            .font(.largeTitle)
            .bold()
            .lineLimit(2)
        ForEach(detail.genres[..<1]) { genre in
            Text(verbatim: "\(genre.name) • \(detail.releaseDate ?? "unknown") • \(detail.country)")
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        if !detail.comingSoon {
            if detail.availability == .AVAILABLE_ON_REZKA {
                HStack {
                    watchButton(detail)
                    downloadButton(detail)
                    bookmarksButton
                    moreButton(detail)
                }
            } else {
                unavailable(systemImage: "globe", text: "Video is unavailable in this region")
            }
        } else {
            unavailable(systemImage: "gauge.with.needle", text: "key_comingsoon")
        }
        Text(detail.description)
            .padding(.top, 8)
            .lineLimit(4)
    }

    // closure #2 in closure #1 in closure #2 … (0x1000ce088)
    private func watchButton(_ detail: MovieDetailed) -> some View {
        Button {
            isPresentedPlaySheet.toggle()
        } label: {
            Label("key_watch", systemImage: "play.fill")
                .font(.system(size: 18))
                .foregroundStyle(.red)
        }
        .hoverEffect(.highlight)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $isPresentedPlaySheet) {
            VideoParamsSheet(id: id, coverData: $coverData, video: $video)
                .environmentObject(MovieDetailsService())
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
        .fullScreenCover(item: $coverData) { data in
            PlayerViewComponent(url: data.body, subtitles: data.subtitles, name: title(detail),
                                voiceActing: data.actingName, poster: detail.hPoster,
                                progressKey: data.progressKey, autoplay: data.autoplay, localFileURL: nil)
                .persistentSystemOverlays(.hidden)
                .ignoresSafeArea(.all, edges: .all)
        }
    }

    private func downloadButton(_ detail: MovieDetailed) -> some View {
        Button {
            isPresentedDownloadSheet.toggle()
        } label: {
            iconLabel("Download", systemImage: "arrow.down.circle")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $isPresentedDownloadSheet) {
            DownloadParamsSheet(id: id, name: title(detail), poster: detail.hPoster,
                                voiceActing: detail.voiceActing, seasons: detail.seasons)
                .environmentObject(MovieDetailsService())
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
    }

    private var bookmarksButton: some View {
        Button {
            isPresentedBookmarksSheet.toggle()
        } label: {
            iconLabel("key_bookmarks", systemImage: "bookmark")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $isPresentedBookmarksSheet) {
            BookmarksSelectionListViewComponent(bookmarks: $bookmarks)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func moreButton(_ detail: MovieDetailed) -> some View {
        Button {
            isPresentedMoreSheet.toggle()
        } label: {
            iconLabel("key_more", systemImage: "ellipsis.circle")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .fullScreenCover(isPresented: $isPresentedMoreSheet) {
            InfoSheetViewComponent(id: id, detail: detail, trailer: trailer, personId: $personId,
                                   listData: $listData, isPresentedPersonInfo: $isPresentedPersonInfoView,
                                   isPresentedList: $isPresentedList, isPresentedMoreSheet: $isPresentedMoreSheet)
        }
    }

    // closure #9 in closure #2 … (0x1000d081c), shared by the icon-only buttons
    private func iconLabel(_ key: LocalizedStringKey, systemImage: String) -> some View {
        Label(key, systemImage: systemImage)
            .font(.system(size: 18))
            .foregroundStyle(.red)
            .labelStyle(.iconOnly)
    }

    // closures #3 / #4 (0x1000d0d24, 0x1000d0fac)
    private func unavailable(systemImage: String, text: LocalizedStringKey) -> some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title)
            Text(text)
                .font(.headline.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .padding(15)
    }

    // closure #3 in closure #1 in closure #1 in closure #1 (0x1000d18ac)
    @ViewBuilder
    private func scheduleSheet(_ detail: MovieDetailed) -> some View {
        if let schedule = detail.schedule {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: true) {
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
                    .padding(.top, 30)
                }
                .toolbar {
                    ToolbarItem(placement: trailingPlacement) {
                        Text("done")
                            .bold()
                            .hoverEffect(.highlight)
                            .foregroundStyle(Color(.accent))
                            // shortcut: tap assumed to toggle the sheet flag like the phone page, check the closure behind 0x1000d23b4
                            .onTapGesture {
                                isPresentedScheduleSheet.toggle()
                            }
                    }
                }
                .ignoresSafeArea(.all, edges: .all)
                .navigationTitle("schedule")
                // shortcut: display mode argument not decoded (call after 0x1000d1d30), read the value passed there
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var leadingPlacement: ToolbarItemPlacement {
        if #available(iOS 17.0, *) {
            return .topBarLeading
        } else {
            return .navigationBarLeading
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
