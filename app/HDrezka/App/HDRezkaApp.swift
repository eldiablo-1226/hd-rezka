import SwiftUI

@main
struct HDRezkaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State var isPresented = false
    @State var id = ""
    @StateObject private var downloadManager = DownloadManager.shared
    var network = Network()

    /// 0x1000fe7ac, onOpenURL 0x1000feaa0: an hdr:// link opens DetailsView through the shared isPresented/id.
    var body: some Scene {
        WindowGroup {
            ContentView(isPresented: $isPresented, id: $id)
                .environmentObject(network)
                .environmentObject(downloadManager)
                .onOpenURL { url in
                    if let filmURL = Self.filmURL(fromDeepLink: url) {
                        id = filmURL
                        isPresented = true
                    }
                }
        }
    }

    /// "hdr://films/x/1-y" (ShareButton.universalLink) -> "https://ijobs.app/films/x/1-y.html"; nil for a bare "hdr://".
    /// The host is hard-coded in the binary, not the mirror setting.
    static func filmURL(fromDeepLink url: URL) -> String? {
        guard !url.description.replacingOccurrences(of: "hdr://", with: "").isEmpty else { return nil }
        return url.description.replacingOccurrences(of: "hdr://", with: "https://ijobs.app/") + ".html"
    }
}
