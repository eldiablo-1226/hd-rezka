import SwiftUI
import Alamofire

/// A paged listing opened from a details page, e.g. a "Входит в списки" list (0x10008e06c…0x100090c54).
/// `id` is the listing URL; pages are GET "<id>/page/<n>" with the app headers.
struct MovieListView: View {
    var id: String
    var name: String
    var movieId: String
    @AppStorage("remoteVersion") var remoteVersion: String = "0.0.0"  // both construction sites (0x10004e5ec, 0x1000d32d8)
    @State var list: [MovieSimple] = []
    /// improvement: the next page, one at a time, a failed one again (`PageCursor`); 1.6.0 counted on each last card.
    @State private var cursor = PageCursor()
    @State var navId: String = ""
    /// improvement: a first page that didn't load says why and offers Retry (1.6.0 spun forever).
    @State var loadFailure: PageLoadFailure? = nil
    @Binding var isPresentedMoreSheet: Bool
    @EnvironmentObject var network: Network
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            if !list.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)]) {
                            ForEach(list) { movie in
                                NavigationLink {
                                    DetailsView(id: movie.id, preview: movie).onAppear { navId = movie.id }
                                } label: {
                                    TitleCardComponentIpad(model: movie).onAppear { if list.last == movie { loadNext() } }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: TitleCardComponent.columnMinimum(typeSize)), spacing: 10)]) {
                            ForEach(list) { movie in
                                NavigationLink {
                                    DetailsView(id: movie.id, preview: movie).onAppear { navId = movie.id }
                                } label: {
                                    TitleCardComponent(model: movie).onAppear { if list.last == movie { loadNext() } }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    // improvement: a later page that failed says so; Retry asks for it again.
                    if cursor.failed {
                        Button("key_retry") { loadNext(retrying: true) }
                            .secondaryButtonStyle()
                            .tint(.primary)
                            .padding(.vertical)
                    }
                }
                .padding(.horizontal)
                .navigationTitle(name)
            } else if let loadFailure {
                // Back to the orb, whose onAppear loads the first page again.
                PageLoadFailedView(failure: loadFailure) { self.loadFailure = nil }
            } else {
                VStack(spacing: DesignTokens.space8) {
                    LoadingOrb()
                    SlowLoadNotice()
                }
                .padding()
                // Also after the first page's Retry; a second appearance while it loads asks for nothing.
                .onAppear { loadNext(retrying: true) }
            }
        }
        .onAppear { navId = movieId }
        .onDisappear {
            if navId == movieId { isPresentedMoreSheet.toggle() }
        }
    }

    private func loadNext(retrying: Bool = false) {
        if let page = retrying ? cursor.retry() : cursor.next() { load(page: page) }
    }

    /// 0x10008faa4 / 0x10009061c, response 0x10008fecc.
    private func load(page: Int) {
        guard let request = try? Self.pageRequest(listURL: id, page: page, version: remoteVersion) else {
            cursor.finish(page: page, items: 0, isEnd: false)
            return
        }
        siteSession.request(request)
            .responseString { response in
                Task { @MainActor in
                    // shortcut: the binary inlined a Network listing parser that returns a fresh array (same
                    // checkPremium + card selectors as Network.parse); a throwaway Network gives the same result.
                    // Switch to that method if Network gains it (contract request d1-1).
                    if let html = response.value, let movies = try? Network().parse(html: html), !movies.isEmpty {
                        list = Self.merged(list, movies)
                        cursor.finish(page: page, items: movies.count, isEnd: false)
                    } else {
                        // The site's 404 past the last page ends the list; page 1 failing is a failure (Retry).
                        let isEnd = page > 1 && response.response?.statusCode == 404
                            && response.value?.contains("id=\"topnav-menu\"") == true
                        cursor.finish(page: page, items: 0, isEnd: isEnd)
                        if list.isEmpty {
                            loadFailure = PageLoadFailure(error: response.error, statusCode: response.response?.statusCode)
                        }
                    }
                }
            }
    }

    /// improvement: a page that arrives twice (page 1 is asked for again when the loading view reappears) adds no title
    /// twice; 1.6.0 appended it whole.
    static func merged(_ list: [MovieSimple], _ page: [MovieSimple]) -> [MovieSimple] {
        list + page.filter { movie in !list.contains { $0.id == movie.id } }
    }

    /// GET "<listURL>/page/<page>" with the two app headers, no Content-Type.
    static func pageRequest(listURL: String, page: Int, version: String) throws -> URLRequest {
        try siteRequest(listURL + "/page/" + String(page), headers: siteHeaders(version: version, contentType: false))
    }
}
