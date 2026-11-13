import SwiftUI
import Alamofire

/// Full search results for `query`, under the search field. improvement: the loading orb until the answer arrives, then
/// the results, "nothing found" or the error (1.6.0 said "nothing found" after 4 s even while the request was still
/// running). critique r2: no longer a page of its own without the field, and coming back from a title keeps the results
/// instead of searching again.
struct SearchResultsView: View {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @EnvironmentObject var network: Network
    @State var phase: Phase = .loading
    /// Bumped by «Повторить».
    @State private var attempt = 0
    let query: String

    var body: some View {
        // A ZStack, not a Group: the task belongs to the results, not to whichever state is on screen.
        ZStack {
            if !network.search.isEmpty {
                ScrollView {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        SearchGridComponent()
                    } else {
                        SearchGridComponentIpad()
                    }
                }
            } else if case .failed(let failure) = phase {
                PageLoadFailedView(failure: failure) {
                    phase = .loading
                    attempt += 1
                }
            } else if phase == .loading {
                LoadingOrb(state: .searching)
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .task(id: attempt) {
            guard phase == .loading else { return }
            do {
                let html = try await siteString(SearchView.Request.full(mirror: settingStore, query: query,
                                                                        version: remoteVersion).asURLRequest())
                // The text changed meanwhile: the field shows its suggestions, and this answer is not theirs.
                guard !Task.isCancelled else { return }
                phase = Self.receive(html, into: network)
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(PageLoadFailure(error: error, statusCode: nil))
            }
        }
    }

    enum Phase: Equatable {
        case loading, loaded
        case failed(PageLoadFailure)
    }

    /// The results page into `network.search`. A page without cards is «nothing found» only when it is the site's own
    /// (its header menu is on every page); anything else, such as a block page served with 200, is a failure.
    @MainActor
    static func receive(_ html: String, into network: Network) -> Phase {
        network.search = []
        guard (try? network.parseSearch(html: html)) != nil,
              !network.search.isEmpty || html.contains("id=\"topnav-menu\"") else { return .failed(.other) }
        return .loaded
    }

    /// The results request as sent (checked by ShellCatalogViewTests).
    static func searchRequest(mirror: String, version: String, query: String) throws -> URLRequest {
        try SearchView.Request.full(mirror: mirror, query: query, version: version).asURLRequest()
    }
}
