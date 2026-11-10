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
    @State var page: Int = 1
    @State var navId: String = ""
    @Binding var isPresentedMoreSheet: Bool
    @EnvironmentObject var network: Network

    var body: some View {
        NavigationStack {
            if !list.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)]) {
                            ForEach(list) { movie in
                                NavigationLink {
                                    DetailsView(id: movie.id).onAppear { navId = movie.id }
                                } label: {
                                    TitleCardComponentIpad(model: movie).onAppear { if list.last == movie { page += 1 } }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)]) {
                            ForEach(list) { movie in
                                NavigationLink {
                                    DetailsView(id: movie.id).onAppear { navId = movie.id }
                                } label: {
                                    TitleCardComponent(model: movie).onAppear { if list.last == movie { page += 1 } }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .onChange(of: page) { _ in
                    Task { load(page: page) }
                }
                .padding(.horizontal)
                .navigationTitle(name)
            } else {
                ProgressView()
                    .onAppear { Task { load(page: 1) } }
            }
        }
        .onAppear { navId = movieId }
        .onDisappear {
            if navId == movieId { isPresentedMoreSheet.toggle() }
        }
    }

    /// 0x10008faa4 / 0x10009061c, response 0x10008fecc.
    private func load(page: Int) {
        guard let request = try? Self.pageRequest(listURL: id, page: page, version: remoteVersion) else { return }
        AF.request(request)
            .responseString { response in
                Task { @MainActor in
                    if let html = response.value {
                        // shortcut: the binary inlined a Network listing parser that returns a fresh array (same
                        // checkPremium + card selectors as Network.parse); a throwaway Network gives the same result.
                        // Switch to that method if Network gains it (contract request d1-1).
                        list.append(contentsOf: try Network().parse(html: html))
                    }
                }
            }
    }

    /// GET "<listURL>/page/<page>" with the two app headers, no Content-Type.
    static func pageRequest(listURL: String, page: Int, version: String) throws -> URLRequest {
        try siteRequest(listURL + "/page/" + String(page), headers: siteHeaders(version: version, contentType: false))
    }
}
