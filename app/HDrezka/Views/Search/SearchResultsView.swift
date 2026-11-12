import SwiftUI
import Alamofire

/// Full search results for `request`. improvement: the loading orb until the answer arrives, then the results,
/// "nothing found" or the error (1.6.0 said "nothing found" after 4 s even while the request was still running).
struct SearchResultsView: View {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @EnvironmentObject var network: Network
    @State var phase: Phase = .loading
    @Binding var request: String

    var body: some View {
        NavigationStack {
            if !network.search.isEmpty {
                ScrollView {
                    VStack {
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            SearchGridComponent()
                        } else {
                            SearchGridComponentIpad()
                        }
                    }
                }
                .navigationTitle(request)
            } else if case .failed(let failure) = phase {
                PageLoadFailedView(failure: failure, retry: search)
            } else if phase == .loading {
                LoadingOrb(state: .searching)
            } else {
                ContentUnavailableView.search(text: request)
            }
        }
        .onAppear(perform: search)
        .onDisappear {
            network.search = []
            phase = .loading
        }
    }

    enum Phase: Equatable {
        case loading, loaded
        case failed(PageLoadFailure)
    }

    private func search() {
        phase = .loading
        siteSession.request(SearchView.Request.full(mirror: settingStore, query: request, version: remoteVersion))
            .responseString { response in
                print(response)
                Task { @MainActor in
                    guard let html = response.value, (200..<300).contains(response.response?.statusCode ?? 0),
                          (try? network.parseSearch(html: html)) != nil else {
                        phase = .failed(PageLoadFailure(error: response.error, statusCode: response.response?.statusCode))
                        return
                    }
                    phase = .loaded
                }
            }
    }

    /// The results request as sent (checked by ShellCatalogViewTests).
    static func searchRequest(mirror: String, version: String, query: String) throws -> URLRequest {
        try SearchView.Request.full(mirror: mirror, query: query, version: version).asURLRequest()
    }
}
