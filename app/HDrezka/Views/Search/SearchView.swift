import SwiftUI
import Alamofire

/// Search tab. improvement (critique r2, after the TV app's and the App Store's search): a large «Поиск» with the field
/// under it, the suggestions as a list of titles while you type, and the full results under the same field after
/// «Найти», so refining is editing the field. 1.6.0 hung the field on an invisible zero-size view, listed suggestions as
/// magnifying-glass rows without posters, showed nothing while an answer was on its way or after it failed, and opened
/// the results as a page of their own without the field.
struct SearchView: View {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @EnvironmentObject var network: Network
    @Binding var isPresented: Bool
    @Binding var id: String
    @State var search: String = ""
    /// The text «Найти» was pressed for: its results stay under the field until the text changes.
    @State private var submitted: String? = nil
    /// The suggestions' answer for the text in the field.
    @State private var phase: SearchResultsView.Phase = .loading
    /// The text whose suggestions are on screen, so coming back from a title or a tab doesn't ask again.
    @State private var suggested: String? = nil
    /// Bumped by «Повторить».
    @State private var attempt = 0

    var body: some View {
        NavigationStack {
            // A ZStack, not a Group: the field and the task belong to the screen, not to whichever state is on it.
            ZStack {
                if search.isEmpty {
                    // improvement: an empty tab says what can be searched (1.6.0: a blank page under the field).
                    ContentUnavailableView("key_search_hint_title", systemImage: "magnifyingglass",
                                           description: Text("key_search_hint"))
                } else if let submitted {
                    SearchResultsView(query: submitted)
                } else {
                    suggestions
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            // improvement: always shown, as in a search tab; the automatic placement collapsed the field until the page
            // was pulled down.
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .onSubmit(of: .search) { submitted = search }
            .onChange(of: search) {
                submitted = nil
                network.search = []
            }
            .task(id: "\(attempt) \(search)") { await suggest() }
            .navigationDestination(isPresented: $isPresented) {
                DetailsView(id: id)
            }
        }
    }

    /// The system spinner in a row while an answer is on its way (the orb is for pages), «Нет результатов» when the site
    /// found nothing, the cause and the fix when the request failed.
    @ViewBuilder
    private var suggestions: some View {
        if case .failed(let failure) = phase {
            PageLoadFailedView(failure: failure) { attempt += 1 }
        } else if phase == .loaded && network.quickSearch.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            List {
                if phase == .loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
                ForEach(network.quickSearch) { result in
                    NavigationLink(destination: DetailsView(id: result.id)) {
                        SearchSuggestionRow(result: result)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    /// 0x100070cac sent a request for every edit 0.2 s later and dropped errors. improvement: the task restarts when the
    /// text changes, so a pause sends one request and an answer for older text is dropped; a failure is shown.
    private func suggest() async {
        let text = search
        guard !text.isEmpty else {
            network.quickSearch = []
            suggested = nil
            return
        }
        guard text != suggested else { return }
        suggested = nil
        phase = .loading
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard !Task.isCancelled else { return }
        do {
            let html = try await siteString(Request.quick(mirror: settingStore, query: text, version: remoteVersion)
                .asURLRequest())
            guard !Task.isCancelled else { return }
            phase = Self.receiveSuggestions(html, into: network)
        } catch {
            guard !Task.isCancelled else { return }
            network.quickSearch = []
            phase = .failed(PageLoadFailure(error: error, statusCode: nil))
        }
        suggested = phase == .loaded ? text : nil
    }

    /// The quick-search answer into `network.quickSearch`. The site answers «ничего не найдено» inside its live-search
    /// block, so an answer without that block (a block page served with 200) is a failure, not «nothing found».
    @MainActor
    static func receiveSuggestions(_ html: String, into network: Network) -> SearchResultsView.Phase {
        network.quickSearch = []
        guard html.contains("b-search__live_section"), (try? network.parseQuickSearch(html: html)) != nil else {
            return .failed(.other)
        }
        return .loaded
    }
}

/// A suggestion as the TV app lists one: a 2:3 poster, the title, the original title and «Сериал · 2024». The answer
/// carries no posters, so a row reads its title's page once and keeps the poster (PosterCache), as the «Досмотреть»
/// cards do.
private struct SearchSuggestionRow: View {
    var result: SearchResult
    @State private var poster: String? = nil
    @State private var isPosterMissing = false
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""

    var body: some View {
        HStack(spacing: DesignTokens.space16) {
            WatchLaterPoster(url: poster, width: 48, isMissing: isPosterMissing)
            VStack(alignment: .leading, spacing: DesignTokens.space4) {
                Text(verbatim: result.name)
                    .lineLimit(2)
                if let original = result.originalTitle {
                    Text(verbatim: original)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(verbatim: result.kindAndYear)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: result.id) {
            poster = await PosterCache.shared.poster(loading: result.id, mirror: settingStore, version: remoteVersion)
            isPosterMissing = poster == nil
        }
    }
}

extension SearchResult {
    /// The words the site's cards use for its sections; the quick search writes them, lowercase, for all but films.
    private static let kinds = ["films": "Фильм", "series": "Сериал", "cartoons": "Мультфильм", "animation": "Аниме"]

    /// The section of the title's address: "https://ijobs.app/series/fiction/…" is a series.
    private var kind: String? {
        URL(string: id)?.pathComponents.dropFirst().first.flatMap { Self.kinds[$0] }
    }

    /// The site's " (Dune: Prophecy, сериал, 2024 - ...)" split from the end, since an original title can hold a comma:
    /// the year, then the site's word for the type, then the original title, which a Russian title doesn't have.
    private var detailParts: (original: [String], year: String?) {
        var parts = details.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            .components(separatedBy: ", ")
        let year = parts.last?.first?.isNumber == true ? parts.removeLast() : nil
        if let kind, parts.last == kind.lowercased() { parts.removeLast() }
        return (parts, year)
    }

    /// "Dune: Prophecy"; nil for a Russian title.
    var originalTitle: String? {
        let original = detailParts.original.joined(separator: ", ")
        return original.isEmpty ? nil : original
    }

    /// «Сериал · 2024 - ...», in the cards' words.
    var kindAndYear: String {
        [kind, detailParts.year].compactMap { $0 }.joined(separator: " · ")
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
