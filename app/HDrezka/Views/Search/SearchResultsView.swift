import SwiftUI
import Alamofire

/// Full search results for `request`; "nothing found" appears only if nothing arrived within 4 s.
struct SearchResultsView: View {
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @EnvironmentObject var network: Network
    @State var isShowingUnavailableView: Bool = false
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
            } else if isShowingUnavailableView {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView.search(text: request)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                        .padding(4)
                    Text("key_nothing+found")
                        .font(.title3)
                        .bold()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                isShowingUnavailableView = true
            }
            AF.request(SearchView.Request.full(mirror: settingStore, query: request, version: remoteVersion))
                .responseString { response in
                    print(response)
                    Task { @MainActor in
                        if let html = response.value {
                            _ = try network.parseSearch(html: html)
                        }
                    }
                }
        }
        .onDisappear {
            network.search = []
            isShowingUnavailableView = false
        }
    }

    /// The results request as sent (checked by ShellCatalogViewTests).
    static func searchRequest(mirror: String, version: String, query: String) throws -> URLRequest {
        try SearchView.Request.full(mirror: mirror, query: query, version: version).asURLRequest()
    }
}
