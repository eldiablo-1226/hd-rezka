import SwiftUI
import Alamofire

/// Search tab: an invisible search field host, live quick-search rows, and the results page on submit.
struct SearchView: View {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @EnvironmentObject var network: Network
    @Binding var isPresented: Bool
    @Binding var id: String
    @State var search: String = ""
    @State var isPresentedResult: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                Color.clear
                    .foregroundStyle(.clear)
                    .frame(width: 0, height: 0)
                    .searchable(text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .onChange(of: search) { _ in
                        // 0x100070cac: every edit fires its own request 0.2 s later with the text current then.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            AF.request(Request.quick(mirror: settingStore, query: search, version: remoteVersion))
                                .responseString { response in
                                    Task { @MainActor in
                                        network.quickSearch = []
                                        if let html = response.value {
                                            _ = try network.parseQuickSearch(html: html)
                                        }
                                    }
                                }
                        }
                    }
                    .submitLabel(.search)
                    .onSubmit(of: .search) {
                        network.search = []
                        isPresentedResult.toggle()
                    }
                    .navigationDestination(isPresented: $isPresentedResult) {
                        SearchResultsView(request: $search)
                    }
            }
            ScrollView {
                ForEach(network.quickSearch) { result in
                    HStack {
                        NavigationLink(destination: DetailsView(id: result.id)) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading) {
                                Text(result.name)
                                    .padding(.leading, 5)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(result.details)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .animation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0))
            }
            .navigationTitle("Search")
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
    }
}

extension SearchView {
    /// A search GET: `q=<query>` joins the URL's own query (URLEncodedFormParameterEncoder.default),
    /// headers are only the two app headers. Alamofire builds it when sending, as with the original's
    /// inline `AF.request(url, method: .get, parameters: ["q": …], headers: …)`.
    struct Request: URLRequestConvertible {
        let url: String
        let query: String
        let version: String

        func asURLRequest() throws -> URLRequest {
            try siteRequest(url, .get, ["q": query], headers: siteHeaders(version: version, contentType: false))
        }

        /// Typed into the search field (0x100070fac).
        static func quick(mirror: String, query: String, version: String) -> Request {
            Request(url: "https://\(mirror)/engine/ajax/search.php/", query: query, version: version)
        }

        /// The results page after submit (0x100078448).
        static func full(mirror: String, query: String, version: String) -> Request {
            Request(url: "https://\(mirror)/search/?do=search&subaction=search", query: query, version: version)
        }
    }

    /// The quick-search request as sent (checked by ShellCatalogViewTests).
    static func quickSearchRequest(mirror: String, version: String, text: String) throws -> URLRequest {
        try Request.quick(mirror: mirror, query: text, version: version).asURLRequest()
    }
}
